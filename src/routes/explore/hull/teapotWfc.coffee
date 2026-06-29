# teapotWfc.coffee
#
# Bridge from the 2D Robinson-tile WFC to the 3D teapot surface.
#
# Each dodecahedron face is a PLANAR PENTAGON in 3D. For each face we:
#   1. Set up a 2D plane + (e₀, e₇₂) basis on that plane.
#   2. Run the puzzle's WFC Assembly with the pentagon canvas matched to
#      the face's circumradius.
#   3. Lift the resulting 2D triangle vertices back to 3D.
# Aggregate across all 12 dodec faces and return a state-compatible
# `{triangles, vertices}` structure the existing teapot-page renderer can
# consume.
#
# The puzzle WFC modules need their `await init()` calls (anglePalette,
# vertexWords, robinson) BEFORE this module's functions are used. Caller
# is responsible.

import { PhiBase } from '$lib/coffee/phiBase.coffee'
import { PhiPoint2D } from '$lib/coffee/wfc/phiPoint2D.coffee'
import { Assembly } from '$lib/coffee/wfc/assembly.coffee'

PHI = (1 + Math.sqrt(5)) / 2

# Cartesian circumradius of the puzzle's pentagon canvas (apothem 4).
# R = apothem · 2/φ = 4 · 2/φ = 8(φ−1) ≈ 4.944.
WFC_PENTAGON_R_CARTESIAN = 8 * (PHI - 1)

# Group 3D triangles by face index. Returns array (length = max face index
# + 1) where each slot is an array of triangles for that face.
groupByFace = (triangles, origFaces) ->
  byFace = []
  for tri, i in triangles
    f = origFaces[i]
    continue unless f?
    byFace[f] ?= []
    byFace[f].push tri
  byFace

# Compute centroid of an array of 3D points.
centroid3d = (pts) ->
  n = pts.length
  cx = 0; cy = 0; cz = 0
  for [x, y, z] in pts
    cx += x; cy += y; cz += z
  [cx / n, cy / n, cz / n]

# 3D vector helpers.
vsub = (a, b) -> [a[0] - b[0], a[1] - b[1], a[2] - b[2]]
vadd = (a, b) -> [a[0] + b[0], a[1] + b[1], a[2] + b[2]]
vscale = (v, s) -> [v[0] * s, v[1] * s, v[2] * s]
vdot = (a, b) -> a[0]*b[0] + a[1]*b[1] + a[2]*b[2]
vcross = (a, b) -> [
  a[1]*b[2] - a[2]*b[1]
  a[2]*b[0] - a[0]*b[2]
  a[0]*b[1] - a[1]*b[0]
]
vmag = (v) -> Math.hypot(v[0], v[1], v[2])
vunit = (v) ->
  m = vmag(v)
  if m < 1e-12 then [0, 0, 0] else [v[0]/m, v[1]/m, v[2]/m]

# Extract the unique 5 vertices of a face's pentagon, sorted CCW as seen
# from OUTSIDE the polyhedron (i.e. CCW around the outward normal).
# `triangles` is the face's triangles; `vertices` is the global vertex
# array; `outwardRef` is a 3D point we treat as "outside" for orienting
# the normal (default: origin → outward = away from origin).
pentagonCorners = (triangles, vertices, outwardRef = [0, 0, 0]) ->
  vIdxs = new Set()
  for tri in triangles
    vIdxs.add v for v in tri
  verts = (vertices[i] for i from vIdxs)
  return null if verts.length != 5
  c = centroid3d(verts)
  # Compute face plane normal via Newell's method on the (unordered)
  # vertices — robust to non-convex / non-planar accidents.
  n = [0, 0, 0]
  for i in [0...verts.length]
    cur = verts[i]
    nxt = verts[(i + 1) % verts.length]
    n[0] += (cur[1] - nxt[1]) * (cur[2] + nxt[2])
    n[1] += (cur[2] - nxt[2]) * (cur[0] + nxt[0])
    n[2] += (cur[0] - nxt[0]) * (cur[1] + nxt[1])
  n = vunit(n)
  # Flip so it points away from `outwardRef` (i.e. outward from the
  # polyhedron's interior).
  outward = vunit(vsub(c, outwardRef))
  n = vscale(n, -1) if vdot(n, outward) < 0
  # Build an in-plane basis (u, v) and sort verts by angle around c.
  u = vunit(vsub(verts[0], c))
  v = vcross(n, u)
  angled = for vv in verts
    d = vsub(vv, c)
    a = vdot(d, u)
    b = vdot(d, v)
    { pt: vv, angle: Math.atan2(b, a) }
  angled.sort (x, y) -> x.angle - y.angle
  (a.pt for a in angled)

# WFC-fill one 3D pentagon. Returns array of { verts: [3D, 3D, 3D], kind }.
#   pentagon3d: 5 vertices in CCW order from outside.
#   tileScale:  PhiBase scale for Robinson tiles.
#   maxSteps:   WFC step cap.
export wfcFillPentagon = (pentagon3d, tileScale, maxSteps = 200) ->
  c = centroid3d(pentagon3d)
  # In-plane basis aligned with the pentagon's first vertex.
  u_raw = vsub(pentagon3d[0], c)
  pentagonR_3d = vmag(u_raw)
  u = vunit(u_raw)
  # Outward normal via cross of two pentagon edges.
  e1 = vsub(pentagon3d[1], pentagon3d[0])
  e2 = vsub(pentagon3d[2], pentagon3d[0])
  n_raw = vcross(e1, e2)
  # Make sure n points outward (from origin) — assumes centroid is on the
  # outside of the origin in our use cases (dodec around origin).
  n = vunit(n_raw)
  outward = vunit(c)
  n = vscale(n, -1) if vdot(n, outward) < 0
  # v = n × u completes the right-handed in-plane basis.
  v = vcross(n, u)
  # Cartesian scale: shrink the WFC's pentagon (R ≈ 4.944) to fit the
  # 3D pentagon's R.
  s = pentagonR_3d / WFC_PENTAGON_R_CARTESIAN
  map2dTo3d = (cart2d) ->
    x = cart2d[0] * s
    y = cart2d[1] * s
    [
      c[0] + x * u[0] + y * v[0]
      c[1] + x * u[1] + y * v[1]
      c[2] + x * u[2] + y * v[2]
    ]
  # Set up Assembly with the same pentagon canvas as the puzzle page.
  target =
    center:           PhiPoint2D.ZERO
    apothem2:         new PhiBase(0, 8)         # apothem 4
    apothem2Overhang: new PhiBase(0, 10)
    tileScale:        tileScale
  assembly = new Assembly(target)
  assembly.seed('T')
  for _ in [0...maxSteps]
    result = assembly.step()
    break if result != 'progress'
  # Lift triangles to 3D. Each Piece in `assembly.pieces` holds its own
  # 3 Vertex refs in `piece.verts`; there is no separate triangles array
  # on the Assembly. The Vertex's exact 2D position lives on `v.pos`
  # (PhiPoint2D); we convert to Cartesian once for the 3D mapping.
  out = []
  for piece in assembly.pieces
    [v0, v1, v2] = piece.verts
    pa = map2dTo3d(v0.pos.toCartesian())
    pb = map2dTo3d(v1.pos.toCartesian())
    pc = map2dTo3d(v2.pos.toCartesian())
    out.push { verts: [pa, pb, pc], kind: piece.kind }
  out

# Aggregate WFC fills across all faces of an existing dodec-shaped state.
# Returns the same `{state, origFaces}` shape the teapot page expects.
#   dodecState:  { triangles: [[i,j,k],...], vertices: [[x,y,z],...] }
#   origFaces:   parallel array, origFaces[i] = face index of triangles[i]
#   tileScale:   PhiBase for Robinson tile size
#   maxSteps:    per-face WFC step cap
export buildWfcDodecSurface = (dodecState, origFaces, tileScale, maxSteps = 200) ->
  byFace = groupByFace(dodecState.triangles, origFaces)
  # Build pentagons per face.
  pentagons = []
  for tris, faceIdx in byFace
    continue unless tris? and tris.length > 0
    p = pentagonCorners(tris, dodecState.vertices)
    pentagons.push { faceIdx, pentagon: p } if p?
  # WFC each pentagon, accumulate.
  allVerts = []
  allTris = []
  allFaceIdx = []
  vertKey = (v) -> "#{v[0].toFixed(5)},#{v[1].toFixed(5)},#{v[2].toFixed(5)}"
  vertMap = new Map()
  indexFor = (v) ->
    k = vertKey(v)
    if vertMap.has(k)
      vertMap.get(k)
    else
      idx = allVerts.length
      allVerts.push v.slice()
      vertMap.set(k, idx)
      idx
  for { faceIdx, pentagon } in pentagons
    tris3d = wfcFillPentagon(pentagon, tileScale, maxSteps)
    for { verts, kind } in tris3d
      allTris.push [indexFor(verts[0]), indexFor(verts[1]), indexFor(verts[2])]
      allFaceIdx.push faceIdx
  state: { triangles: allTris, vertices: allVerts }
  origFaces: allFaceIdx

# Just enumerate the pentagons for incremental processing — lets the page
# WFC each face during one animation tick instead of all up front.
# Returns array of { faceIdx, pentagon: [5×[x,y,z] CCW from outside] }.
export extractDodecPentagons = (dodecState, origFaces) ->
  byFace = groupByFace(dodecState.triangles, origFaces)
  out = []
  for tris, faceIdx in byFace
    continue unless tris? and tris.length > 0
    p = pentagonCorners(tris, dodecState.vertices)
    out.push { faceIdx, pentagon: p } if p?
  out
