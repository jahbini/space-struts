# teapotMesh.coffee
#
# Loads the embedded Utah teapot mesh and exposes two helpers:
#
#   teapotSeenModel(seen, material) -> seen.Model
#     Builds a seen.Model whose children are one path-triangle per mesh face.
#     `seen` must be the seen runtime (window.seen) so this module stays
#     framework-agnostic.
#
#   teapotRadialDistance([dx, dy, dz]) -> Number | null
#     Casts a ray (CG / optics half-line in Cartesian floats, not a SixPhi
#     edge) from the origin along the given direction.  Direction need not
#     be unit-length; result is in the same units as the direction's
#     magnitude because t is parameter distance along d.  Returns the
#     smallest positive t such that the ray hits the mesh, or null if no
#     hit.  See the terminology note before the BVH section for the
#     ray-vs-edge distinction.
#
#   teapotBoundingRadius -> 1.0
#
# The mesh is pre-normalized: centered on its bounding-box centroid and scaled
# so its bounding sphere has radius 1. So `teapotRadialDistance(unitDir)` is
# directly comparable to phi^k for the shell-quantization logic.
#
# Acceleration (BVH).  `teapotRadialDistance` was originally a brute-force
# loop over every triangle (Möller-Trumbore per tri).  For T ~ 3k teapot
# triangles that's O(T) per call, which dominates buildVoxelHull at small
# scales: at n = -5, ~9.7e5 cubes * 9 corner tests * T = ~2.6e10 ray tests,
# 10-20 minutes wall.  The module now builds an axis-aligned bounding-volume
# hierarchy over the teapot triangles on first use and traverses it per ray.
# Per-call cost drops from O(T) to O(log T) plus a constant number of leaf
# Möller-Trumbore tests, expected ~60-100x at this mesh size.

import teapotData from '../data/teapot.json'

export teapotBoundingRadius = teapotData.boundingRadius
export teapotVerts = teapotData.verts
export teapotTris = teapotData.tris
export teapotMeta = teapotData.meta

export teapotSeenModel = (seen, material = null) ->
  model = new seen.Model()
  mat = material ? new seen.Material(seen.Colors.hex('#888888'))
  mat.a = 0x80 unless material?
  for [i, j, k] in teapotTris
    [a, b, c] = [teapotVerts[i], teapotVerts[j], teapotVerts[k]]
    pa = seen.P(a[0], a[1], a[2])
    pb = seen.P(b[0], b[1], b[2])
    pc = seen.P(c[0], c[1], c[2])
    path = seen.Shapes.path([pa, pb, pc])
    path.cullBackfaces = false
    path.fill(mat)
    path.surfaces[0].fillMaterial = mat
    model.add(path)
  model

# Vector primitives used by both Möller-Trumbore and BVH construction.
EPS = 1e-9

cross = (a, b) -> [
  a[1] * b[2] - a[2] * b[1]
  a[2] * b[0] - a[0] * b[2]
  a[0] * b[1] - a[1] * b[0]
]
dot = (a, b) -> a[0] * b[0] + a[1] * b[1] + a[2] * b[2]
sub = (a, b) -> [a[0] - b[0], a[1] - b[1], a[2] - b[2]]
neg = (a) -> [-a[0], -a[1], -a[2]]

# ----- Bounding-volume hierarchy over the teapot triangles --------------
#
# Terminology note.  Throughout this section, "ray" means the CG / optics
# primitive — a half-line `r(t) = origin + t·d` in Cartesian float space,
# parameterized by a continuous scalar `t`.  Möller-Trumbore (the leaf
# test) and the slab method (internal nodes) both operate on Cartesian
# floats.  This is distinct from the **edge** primitive of SixPhi
# geometry: a line in SixBase between two lattice points, formed as the
# intersection of two SixBase planes, with no continuous parameter.  The
# teapot mesh lives outside the PhiBase lattice, so ray-vs-Cartesian is
# the right operation here.  If the mesh were ever lifted into SixPhi
# (a PhiBase teapot), the same BVH hierarchy would still apply — the
# leaves would test lattice edges at the intersection step instead of
# casting rays, and the slab tests at internal nodes would become
# edge-vs-AABB containment.
#
# Each node is one of:
#   leaf:     { lo, hi, triIdx }       — single triangle, index into teapotTris
#   internal: { lo, hi, left, right }  — AABB of the union of children's AABBs
#
# Built lazily on first call to teapotRadialDistance.  Construction is
# top-down: at each step, pick the longest axis of the parent AABB, sort
# the enclosed triangles by their centroid along that axis, split at the
# median.  Stops at one triangle per leaf.  Cost is O(T log T) one-time,
# ~5 ms for the teapot's ~3k triangles.

triAABB = (triIdx) ->
  [iA, iB, iC] = teapotTris[triIdx]
  v0 = teapotVerts[iA]
  v1 = teapotVerts[iB]
  v2 = teapotVerts[iC]
  lo0 = if v0[0] < v1[0] then v0[0] else v1[0]; lo0 = v2[0] if v2[0] < lo0
  lo1 = if v0[1] < v1[1] then v0[1] else v1[1]; lo1 = v2[1] if v2[1] < lo1
  lo2 = if v0[2] < v1[2] then v0[2] else v1[2]; lo2 = v2[2] if v2[2] < lo2
  hi0 = if v0[0] > v1[0] then v0[0] else v1[0]; hi0 = v2[0] if v2[0] > hi0
  hi1 = if v0[1] > v1[1] then v0[1] else v1[1]; hi1 = v2[1] if v2[1] > hi1
  hi2 = if v0[2] > v1[2] then v0[2] else v1[2]; hi2 = v2[2] if v2[2] > hi2
  { lo: [lo0, lo1, lo2], hi: [hi0, hi1, hi2] }

triCentroid = (triIdx) ->
  [iA, iB, iC] = teapotTris[triIdx]
  v0 = teapotVerts[iA]
  v1 = teapotVerts[iB]
  v2 = teapotVerts[iC]
  [
    (v0[0] + v1[0] + v2[0]) / 3
    (v0[1] + v1[1] + v2[1]) / 3
    (v0[2] + v1[2] + v2[2]) / 3
  ]

unionAABB = (indices, bounds) ->
  b0 = bounds[indices[0]]
  lo = [b0.lo[0], b0.lo[1], b0.lo[2]]
  hi = [b0.hi[0], b0.hi[1], b0.hi[2]]
  for n in [1...indices.length]
    b = bounds[indices[n]]
    lo[0] = b.lo[0] if b.lo[0] < lo[0]
    lo[1] = b.lo[1] if b.lo[1] < lo[1]
    lo[2] = b.lo[2] if b.lo[2] < lo[2]
    hi[0] = b.hi[0] if b.hi[0] > hi[0]
    hi[1] = b.hi[1] if b.hi[1] > hi[1]
    hi[2] = b.hi[2] if b.hi[2] > hi[2]
  { lo, hi }

buildBVH = ->
  bounds = (triAABB(i) for i in [0...teapotTris.length])
  centroids = (triCentroid(i) for i in [0...teapotTris.length])
  build = (indices) ->
    if indices.length is 1
      idx = indices[0]
      return { lo: bounds[idx].lo, hi: bounds[idx].hi, triIdx: idx }
    aabb = unionAABB(indices, bounds)
    # Split along the longest axis of the parent AABB at the centroid median.
    ex0 = aabb.hi[0] - aabb.lo[0]
    ex1 = aabb.hi[1] - aabb.lo[1]
    ex2 = aabb.hi[2] - aabb.lo[2]
    axis = 0
    axis = 1 if ex1 > ex0 and ex1 >= ex2
    axis = 2 if ex2 > ex0 and ex2 > ex1
    indices.sort (a, b) -> centroids[a][axis] - centroids[b][axis]
    mid = indices.length >> 1
    left = build(indices[0...mid])
    right = build(indices[mid...])
    { lo: aabb.lo, hi: aabb.hi, left, right }
  build (i for i in [0...teapotTris.length])

bvhRoot = null      # built on first teapotRadialDistance call

# Ray-AABB intersection (slab method), ray origin fixed at (0, 0, 0).
# Returns the entry parameter t >= 0 if the ray hits the box for some
# t > EPS, null otherwise.  The traversal uses the entry t to early-out
# from subtrees whose nearest possible hit is already farther than the
# closest hit found so far.
rayAABBEntry = (d, lo, hi) ->
  tMin = -Infinity
  tMax = Infinity
  for axis in [0..2]
    di = d[axis]
    if di > -EPS and di < EPS
      # Ray parallel to this slab — origin must straddle the slab to hit.
      return null if 0 < lo[axis] or 0 > hi[axis]
    else
      t1 = lo[axis] / di
      t2 = hi[axis] / di
      if t1 > t2 then [t1, t2] = [t2, t1]
      tMin = t1 if t1 > tMin
      tMax = t2 if t2 < tMax
      return null if tMin > tMax
  return null if tMax < EPS
  if tMin < 0 then 0 else tMin

# Single-triangle Möller-Trumbore from the origin.  Hoisted out of the
# original brute-force loop so the BVH leaf can call it directly.  Returns
# the (possibly updated) running minimum t.
rayHitsTri = (d, triIdx, best) ->
  [iA, iB, iC] = teapotTris[triIdx]
  v0 = teapotVerts[iA]
  v1 = teapotVerts[iB]
  v2 = teapotVerts[iC]
  e1 = sub(v1, v0)
  e2 = sub(v2, v0)
  h = cross(d, e2)
  a = dot(e1, h)
  return best if a > -EPS and a < EPS
  f = 1 / a
  s = neg(v0)                       # s = origin - v0 = -v0
  u = f * dot(s, h)
  return best if u < 0 or u > 1
  q = cross(s, e1)
  v = f * dot(d, q)
  return best if v < 0 or u + v > 1
  t = f * dot(e2, q)
  return best if t < EPS
  if t < best then t else best

traverseBVH = (node, d, best) ->
  entry = rayAABBEntry(d, node.lo, node.hi)
  return best unless entry?
  # Early-out: if even the closest possible hit in this subtree is farther
  # than what we've already found, skip the whole subtree.
  return best if entry >= best
  if node.triIdx?
    return rayHitsTri(d, node.triIdx, best)
  best = traverseBVH(node.left,  d, best)
  best = traverseBVH(node.right, d, best)
  best

export teapotRadialDistance = (d) ->
  bvhRoot ?= buildBVH()
  best = traverseBVH(bvhRoot, d, Infinity)
  if best is Infinity then null else best
