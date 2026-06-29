# dodecWfc3D.coffee
#
# 3D Wave-Function-Collapse on the surface of a regular dodecahedron.
# Vertex positions are exact SixPhiVectors (Z[φ]³); the puzzle's 2D
# Robinson WFC is run within each face plane and the per-tile vertex
# positions are lifted to 3D with exact arithmetic.
#
# Phase 1 (this file): structure extraction, face plane basis, per-face
# WFC. Faces fill INDEPENDENTLY at this stage — boundary edge vertices
# don't yet propagate between adjacent faces, so the visible mismatch
# along dodec edges is expected. Phase 2 will add the edge-vertex
# pre-seeding so adjacent face WFCs share boundary vertices.
#
# Why SixPhiVector + this lift is exact: the puzzle's pentagon canvas
# has circumradius R = 8·(φ−1) = 8/φ. Then 1/R = φ/8, which is just a
# rational PhiBase value (`PhiBase(1, 0, 8)`). So mapping a tile vertex
# at PhiPoint2D(a, b) to 3D is
#     3D = center + (a · (1/R)) · u_offset + (b · (1/R)) · v_offset
# where center, u_offset, v_offset are SixPhiVectors derived from the
# dodec's vertex positions. Every scalar in this expression lives in
# Q[φ], so the result is an exact SixPhiVector — no Cartesian round-trip.

import { PhiBase } from '$lib/coffee/phiBase.coffee'
import { SixPhiVector } from '$lib/coffee/sixPhiVector.coffee'
import { PhiPoint2D } from '$lib/coffee/wfc/phiPoint2D.coffee'
import { Assembly } from '$lib/coffee/wfc/assembly.coffee'

# 1/R as a PhiBase. R is the puzzle pentagon canvas circumradius
# 8·(φ−1) = 8/φ, so 1/R = φ/8.
INV_R_PB = new PhiBase(1, 0, 8)        # = φ/8

# ---- SixPhi helpers (treat the input vectors as carrying scaleFactor=1,
# which is what GeoPhi.createPhiPoint produces — all dodec vertices land
# in Z[φ]³). Each helper builds a fresh SixPhiVector with scaleFactor=1.
spvAdd = (a, b) ->
  new SixPhiVector(a.v[i].add(b.v[i]) for i in [0...6])
spvSub = (a, b) ->
  new SixPhiVector(a.v[i].sub(b.v[i]) for i in [0...6])
spvScale = (vec, scalar) ->
  new SixPhiVector(vec.v[i].mul(scalar) for i in [0...6])
# Centroid of `n` SixPhiVectors with equal weights. Returns a SixPhiVector
# whose Cartesian is the geometric average (exact in Q[φ] but the result
# has a 1/n that we encode as a PhiBase with denominator n).
spvCentroidOf = (vecs) ->
  s = vecs[0]
  s = spvAdd(s, vecs[i]) for i in [1...vecs.length]
  inv = new PhiBase(0, 1, vecs.length)   # = 1/n
  spvScale(s, inv)

# Convert a SixPhi vector to a Cartesian [x,y,z] float (for SVG / seen
# rendering only — never for legality).
spvToCart3 = (v) -> v.sixPhiToCartesianDisplay()

# ---- 1. Structure extraction --------------------------------------------
# Returns { vertices, faces, edges, corners } using the GeoPhi dodecahedron.
#   vertices[i]: SixPhiVector for dodec vertex i (i in 0..19)
#   faces[i]:    { faceIdx, vertexIndices: [5 CCW from outside] }
#   edges[i]:    { v0, v1, faces: [2 face indices], index }
#   corners[i]:  { vertexIndex: i, faces: [3 face indices] }
export extractDodecStructure = (gPhi) ->
  rawVerts = gPhi.Polyhedra.Dodecahedron1
  vertices = rawVerts[..]

  vertNameToIdx = {}
  for v, i in vertices
    vertNameToIdx[v.ID] = i

  # First 12 face strings are the canonical dodec faces. Reflected copies
  # (indices 12..23) belong to the mirror dodec.
  faces = []
  for faceStr, faceIdx in gPhi.Faces[0...12]
    names = faceStr.split('-')
    vIdxs = (vertNameToIdx[name] for name in names)
    if vIdxs.some((i) -> not i?)
      console.warn "extractDodecStructure: face #{faceIdx} has unresolved vertex name"
      continue
    faces.push { faceIdx, vertexIndices: orientCCWFromOutside(vIdxs, vertices) }

  # Edges from face boundaries; each non-degenerate edge appears in exactly 2 faces.
  edgeMap = {}
  edges = []
  for face in faces
    vs = face.vertexIndices
    for i in [0...vs.length]
      a = vs[i]
      b = vs[(i + 1) % vs.length]
      key = if a < b then "#{a}-#{b}" else "#{b}-#{a}"
      if edgeMap[key]?
        edgeMap[key].faces.push face.faceIdx
      else
        e = { v0: Math.min(a, b), v1: Math.max(a, b), faces: [face.faceIdx], index: edges.length }
        edges.push e
        edgeMap[key] = e

  # Corners: each vertex sits at the intersection of 3 faces (dodec).
  vertToFaces = ([] for _ in [0...vertices.length])
  for face in faces
    for vIdx in face.vertexIndices
      vertToFaces[vIdx].push face.faceIdx
  corners = ({ vertexIndex: i, faces: vertToFaces[i] } for i in [0...vertices.length])

  { vertices, faces, edges, corners }

# Ensure a face's 5 vertices are listed CCW as seen from OUTSIDE the dodec
# (i.e. CCW around the face's outward normal). The face's plane normal is
# computed by Newell's method on the float Cartesian, then we sort by
# angle around the centroid. Uses float positions for the orientation
# step only; the resulting INDEX ORDER is then used everywhere downstream
# in the exact SixPhi paths.
orientCCWFromOutside = (vIdxs, vertices) ->
  cart = (spvToCart3(vertices[i]) for i in vIdxs)
  # Centroid (float, orientation-only).
  cx = (c[0] for c in cart).reduce((a, b) -> a + b) / cart.length
  cy = (c[1] for c in cart).reduce((a, b) -> a + b) / cart.length
  cz = (c[2] for c in cart).reduce((a, b) -> a + b) / cart.length
  # Newell normal.
  n = [0, 0, 0]
  for i in [0...cart.length]
    cur = cart[i]
    nxt = cart[(i + 1) % cart.length]
    n[0] += (cur[1] - nxt[1]) * (cur[2] + nxt[2])
    n[1] += (cur[2] - nxt[2]) * (cur[0] + nxt[0])
    n[2] += (cur[0] - nxt[0]) * (cur[1] + nxt[1])
  # Outward = away from origin (dodec is centred at origin).
  if n[0]*cx + n[1]*cy + n[2]*cz < 0
    n = [-n[0], -n[1], -n[2]]
  # In-plane basis u = first vertex offset.
  u = [cart[0][0] - cx, cart[0][1] - cy, cart[0][2] - cz]
  # v = n × u.
  vx = n[1]*u[2] - n[2]*u[1]
  vy = n[2]*u[0] - n[0]*u[2]
  vz = n[0]*u[1] - n[1]*u[0]
  angled = for [px, py, pz], i in cart
    dx = px - cx
    dy = py - cy
    dz = pz - cz
    a = dx*u[0] + dy*u[1] + dz*u[2]
    b = dx*vx   + dy*vy   + dz*vz
    { vIdx: vIdxs[i], angle: Math.atan2(b, a) }
  angled.sort (x, y) -> x.angle - y.angle
  (a.vIdx for a in angled)

# ---- 2. Face plane basis (exact) ----------------------------------------
# For a face with 5 vertex indices, computes (center, u_offset, v_offset)
# as SixPhiVectors such that
#   center           = (1/5)·Σ vertices
#   u_offset = vertex[0] − center        (corner 0 of the canvas)
#   v_offset = vertex[1] − center        (corner 1, 72° CCW from corner 0)
# When the puzzle canvas's R = 8(φ−1) is mapped onto this face, corner 0
# in 2D coincides exactly with dodec vertex[0] in 3D, corner 1 with
# vertex[1], etc. (because the dodec face is a regular pentagon whose
# corners ARE the canvas corners). So 2D-PhiPoint2D(a, b) maps to:
#   3D = center + (a · INV_R_PB)·u_offset + (b · INV_R_PB)·v_offset
# All exact in Z[φ].
export facePlane = (face, vertices) ->
  vs = (vertices[i] for i in face.vertexIndices)
  center = spvCentroidOf(vs)
  uOff = spvSub(vs[0], center)
  vOff = spvSub(vs[1], center)
  { center, uOff, vOff }

# Map a 2D PhiPoint2D position to a 3D SixPhi position on the face plane.
# All arithmetic exact in Z[φ].
mapPhiPoint2DToSixPhi = (p2, plane) ->
  aScaled = p2.a.mul(INV_R_PB)
  bScaled = p2.b.mul(INV_R_PB)
  spvAdd(plane.center, spvAdd(spvScale(plane.uOff, aScaled), spvScale(plane.vOff, bScaled)))

# ---- 3. Per-face WFC -----------------------------------------------------
# Run the puzzle Assembly inside one face, mapping each placed tile's three
# vertex positions into 3D via the face plane. Returns an array of
# { verts: [3D, 3D, 3D] in floats, kind: 'T' | 'G' }. The floats are
# obtained once at the end via sixPhiToCartesianDisplay() — exclusively
# for SVG / seen rendering; the legality layer stayed exact.
export wfcFillFace3D = (face, vertices, tileScale, maxSteps = 200) ->
  plane = facePlane(face, vertices)
  # Same pentagon canvas the puzzle page uses.
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
  out = []
  for piece in assembly.pieces
    cart3 = for v in piece.verts
      spv = mapPhiPoint2DToSixPhi(v.pos, plane)
      spvToCart3(spv)
    out.push { verts: cart3, kind: piece.kind, faceIdx: face.faceIdx }
  out

# ---- 4. Whole-dodec aggregation ----------------------------------------
# Run wfcFillFace3D over all 12 faces, return all tiles. Each face is still
# independent — boundary mismatches at shared edges will be visible until
# Phase 2 adds edge-vertex propagation.
export buildSingleDodec3D = (gPhi, tileScale, maxSteps = 200) ->
  struct = extractDodecStructure(gPhi)
  out = []
  for face in struct.faces
    facetiles = wfcFillFace3D(face, struct.vertices, tileScale, maxSteps)
    out.push facetiles...
  out
