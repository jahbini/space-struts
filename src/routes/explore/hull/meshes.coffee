# Shape registry for the teapot route.
#
# Each registered mesh exposes the same interface, so the page can swap
# meshes through a single picker:
#
#   getMesh(name) ->
#     name              : string
#     verts             : [[x,y,z], ...]    centered, scaled by current scale
#     tris              : [[i,j,k], ...]
#     boundingRadius    : Number             updated by setScale
#     radialDistance(d) : Number | null      ray from origin (in scaled space)
#     seenModel(seen, mat) -> seen.Model     one path per triangle, scaled
#     setScale(s)                            mutate verts / radius in place
#                                            (invalidates internal BVH)
#
# The teapot entry is a thin wrapper around ./teapotMesh.coffee (which
# lives next to this file — page-specific mesh code is kept out of $lib).
# The other entries define their meshes procedurally and reuse the BVH
# helper in this file. This module is the only "lib" code added for the
# multi-mesh feature, and it lives next to the page that uses it.

import {
  teapotVerts, teapotTris, teapotBoundingRadius,
  teapotRadialDistance, teapotSeenModel, setTeapotScale, getTeapotScale
} from './teapotMesh.coffee'

# ---- shared math helpers ---------------------------------------------
EPS = 1e-9
cross = (a, b) -> [
  a[1] * b[2] - a[2] * b[1]
  a[2] * b[0] - a[0] * b[2]
  a[0] * b[1] - a[1] * b[0]
]
dot = (a, b) -> a[0] * b[0] + a[1] * b[1] + a[2] * b[2]
sub = (a, b) -> [a[0] - b[0], a[1] - b[1], a[2] - b[2]]
neg = (a) -> [-a[0], -a[1], -a[2]]

# ---- BVH-backed mesh wrapper -----------------------------------------
# Builds a mutable mesh whose verts can be scaled in place, with a BVH
# accelerating radialDistance queries. The BVH is rebuilt lazily on the
# first query after a setScale call. Used for any mesh other than the
# teapot, which has its own equivalent implementation in teapotMesh.
makeBvhMesh = ({ name, verts: rawVerts, tris }) ->
  unscaled = (v.slice() for v in rawVerts)
  verts = (v.slice() for v in unscaled)
  bRadius = computeBoundingRadius(verts)
  unscaledRadius = bRadius
  currentScale = 1.0
  bvhRoot = null

  triAABB = (triIdx) ->
    [iA, iB, iC] = tris[triIdx]
    v0 = verts[iA]; v1 = verts[iB]; v2 = verts[iC]
    lo = [
      Math.min(v0[0], v1[0], v2[0])
      Math.min(v0[1], v1[1], v2[1])
      Math.min(v0[2], v1[2], v2[2])
    ]
    hi = [
      Math.max(v0[0], v1[0], v2[0])
      Math.max(v0[1], v1[1], v2[1])
      Math.max(v0[2], v1[2], v2[2])
    ]
    { lo, hi }

  triCentroid = (triIdx) ->
    [iA, iB, iC] = tris[triIdx]
    v0 = verts[iA]; v1 = verts[iB]; v2 = verts[iC]
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
    bounds = (triAABB(i) for i in [0...tris.length])
    centroids = (triCentroid(i) for i in [0...tris.length])
    build = (indices) ->
      if indices.length is 1
        idx = indices[0]
        return { lo: bounds[idx].lo, hi: bounds[idx].hi, triIdx: idx }
      aabb = unionAABB(indices, bounds)
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
    build (i for i in [0...tris.length])

  rayAABBEntry = (d, lo, hi) ->
    tMin = -Infinity; tMax = Infinity
    for axis in [0..2]
      di = d[axis]
      if di > -EPS and di < EPS
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

  rayHitsTri = (d, triIdx, best) ->
    [iA, iB, iC] = tris[triIdx]
    v0 = verts[iA]; v1 = verts[iB]; v2 = verts[iC]
    e1 = sub(v1, v0); e2 = sub(v2, v0)
    h = cross(d, e2)
    a = dot(e1, h)
    return best if a > -EPS and a < EPS
    f = 1 / a
    s = neg(v0)
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
    return best if entry >= best
    if node.triIdx?
      return rayHitsTri(d, node.triIdx, best)
    best = traverseBVH(node.left, d, best)
    best = traverseBVH(node.right, d, best)
    best

  radialDistance = (d) ->
    bvhRoot ?= buildBVH()
    best = traverseBVH(bvhRoot, d, Infinity)
    if best is Infinity then null else best

  seenModel = (seen, material = null) ->
    model = new seen.Model()
    mat = material ? new seen.Material(seen.Colors.hex('#888888'))
    mat.a = 0x80 unless material?
    for [i, j, k] in tris
      [a, b, c] = [verts[i], verts[j], verts[k]]
      pa = seen.P(a[0], a[1], a[2])
      pb = seen.P(b[0], b[1], b[2])
      pc = seen.P(c[0], c[1], c[2])
      path = seen.Shapes.path([pa, pb, pc])
      path.cullBackfaces = false
      path.fill(mat)
      path.surfaces[0].fillMaterial = mat
      model.add(path)
    model

  mesh = null
  setScale = (s) ->
    return currentScale if s == currentScale
    for v, idx in unscaled
      verts[idx][0] = v[0] * s
      verts[idx][1] = v[1] * s
      verts[idx][2] = v[2] * s
    bRadius = unscaledRadius * s
    mesh.boundingRadius = bRadius if mesh?
    currentScale = s
    bvhRoot = null
    s

  mesh =
    name: name
    verts: verts
    tris: tris
    boundingRadius: bRadius
    radialDistance: radialDistance
    seenModel: seenModel
    setScale: setScale
    getScale: -> currentScale
  mesh

computeBoundingRadius = (verts) ->
  best = 0
  for v in verts
    r2 = v[0]*v[0] + v[1]*v[1] + v[2]*v[2]
    best = r2 if r2 > best
  Math.sqrt(best)

# ---- procedural torus ------------------------------------------------
# Major radius R, minor radius r, segments along each direction.
# Parameter ranges: u ∈ [0, 2π) around the tube, v ∈ [0, 2π) around the
# centerline. Vertex (u, v) at:
#   x = (R + r·cos u)·cos v
#   y = (R + r·cos u)·sin v
#   z = r·sin u
# Triangulation: each (u, v) quad becomes two triangles. The whole mesh
# is then centered (already at origin) and scaled so bounding radius = 1.
buildTorusGeometry = (R = 0.72, r = 0.28, uSegs = 24, vSegs = 36) ->
  verts = []
  for ui in [0...uSegs]
    u = (ui / uSegs) * Math.PI * 2
    cu = Math.cos(u); su = Math.sin(u)
    for vi in [0...vSegs]
      v = (vi / vSegs) * Math.PI * 2
      cv = Math.cos(v); sv = Math.sin(v)
      verts.push [
        (R + r * cu) * cv
        (R + r * cu) * sv
        r * su
      ]
  tris = []
  idx = (ui, vi) -> ((ui %% uSegs) * vSegs) + (vi %% vSegs)
  for ui in [0...uSegs]
    for vi in [0...vSegs]
      a = idx(ui,     vi    )
      b = idx(ui + 1, vi    )
      c = idx(ui + 1, vi + 1)
      d = idx(ui,     vi + 1)
      tris.push [a, b, c]
      tris.push [a, c, d]
  # Normalize so bounding radius = 1.
  bMax = computeBoundingRadius(verts)
  verts = ([v[0]/bMax, v[1]/bMax, v[2]/bMax] for v in verts)
  { verts, tris }

# Capture the canonical (unscaled) torus radii so isInside stays exact
# under setScale: both major and minor radii grow proportionally.
TORUS_R_BASE = 0.72
TORUS_r_BASE = 0.28
torusGeom = buildTorusGeometry(TORUS_R_BASE, TORUS_r_BASE)
# After normalize-to-unit-bounding-sphere in buildTorusGeometry, the
# verts were divided by (R+r). Update the live radii accordingly.
torusNorm = TORUS_R_BASE + TORUS_r_BASE
TORUS_R_UNIT = TORUS_R_BASE / torusNorm
TORUS_r_UNIT = TORUS_r_BASE / torusNorm
torusMesh = makeBvhMesh
  name: 'torus'
  verts: torusGeom.verts
  tris:  torusGeom.tris
# Analytical inside-test for the torus. A point p is inside iff its
# distance from the centerline circle (radius R, in the xy-plane) is
# less than the tube radius r — both scaled by the current setScale.
torusMesh.isInside = (p) ->
  s = torusMesh.getScale()
  R = TORUS_R_UNIT * s
  r = TORUS_r_UNIT * s
  dAxis = Math.hypot(p[0], p[1])
  dCenter = Math.hypot(dAxis - R, p[2])
  dCenter < r

# ---- teapot wrapper to match the same interface ----------------------
# The teapot's BVH + scaling logic already lives in teapotMesh.coffee.
# Wrap it in the same shape so getMesh('teapot') is uniform with the rest.
# boundingRadius is mutated when setScale runs so callers can read it as
# a plain property without worrying about the lib's live binding.
teapotMesh =
  name: 'teapot'
  verts: teapotVerts
  tris:  teapotTris
  boundingRadius: teapotBoundingRadius
  radialDistance: teapotRadialDistance
  seenModel: (seen, mat) -> teapotSeenModel(seen, mat)
  # Star-shape test from origin — fine for the teapot (it's body-of-
  # revolution with the handle/spout sticking out but still hit at most
  # once along any radial ray).
  isInside: (pos) ->
    r = Math.hypot(pos[0], pos[1], pos[2])
    return true if r < 1e-9
    rT = teapotRadialDistance([pos[0]/r, pos[1]/r, pos[2]/r])
    return false unless rT?
    r < rT
  setScale: (s) ->
    setTeapotScale(s)
    teapotMesh.boundingRadius = teapotBoundingRadius
    s
  getScale: -> getTeapotScale()

MESHES =
  teapot: teapotMesh
  torus:  torusMesh

export meshNames = -> (k for k of MESHES)
export getMesh = (name) -> MESHES[name] ? teapotMesh
