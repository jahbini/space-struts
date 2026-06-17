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
#     Casts a ray from the origin along the given direction (need not be
#     unit-length; result is in the same units as the direction's magnitude
#     because t is parameter distance along d). Returns the smallest positive
#     t such that the ray hits the mesh, or null if no hit.
#
#   teapotBoundingRadius -> 1.0
#
# The mesh is pre-normalized: centered on its bounding-box centroid and scaled
# so its bounding sphere has radius 1. So `teapotRadialDistance(unitDir)` is
# directly comparable to phi^k for the shell-quantization logic.

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

# Moller-Trumbore ray-triangle intersection from the origin.
# Returns the smallest positive t such that o + t*d hits a tri.
EPS = 1e-9

cross = (a, b) -> [
  a[1] * b[2] - a[2] * b[1]
  a[2] * b[0] - a[0] * b[2]
  a[0] * b[1] - a[1] * b[0]
]
dot = (a, b) -> a[0] * b[0] + a[1] * b[1] + a[2] * b[2]
sub = (a, b) -> [a[0] - b[0], a[1] - b[1], a[2] - b[2]]
neg = (a) -> [-a[0], -a[1], -a[2]]

export teapotRadialDistance = (d) ->
  best = Infinity
  for [iA, iB, iC] in teapotTris
    v0 = teapotVerts[iA]
    v1 = teapotVerts[iB]
    v2 = teapotVerts[iC]
    e1 = sub(v1, v0)
    e2 = sub(v2, v0)
    h = cross(d, e2)
    a = dot(e1, h)
    continue if a > -EPS and a < EPS
    f = 1 / a
    # s = origin - v0 = -v0
    s = neg(v0)
    u = f * dot(s, h)
    continue if u < 0 or u > 1
    q = cross(s, e1)
    v = f * dot(d, q)
    continue if v < 0 or u + v > 1
    t = f * dot(e2, q)
    continue if t < EPS
    best = t if t < best
  if best is Infinity then null else best
