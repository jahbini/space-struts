# geoSixPhi.coffee
# Replacement for Geo.coffee using SixPhiVector and PhiBase math
# Outputs a Memo (M) structure exactly like old Geo

import { PhiBase, ZERO, ONE } from './phiBase.coffee'
import { SixPhiVector } from './sixPhiVector.coffee'

# Helper: convert a symbol like '#pzF' into a SixPhiVector
symbolToSixPhi = (str) ->
  mapping = (char) ->
    switch char
      when 'z' then new PhiBase(0, 0)
      when 'O' then new PhiBase(0, 1)
      when 'o' then new PhiBase(0, -1)
      when 'P' then new PhiBase(1, 0)
      when 'p' then new PhiBase(-1, 0)
      when 'F' then new PhiBase(1, -1)
      when 'f' then new PhiBase(-1, 1)
      else throw new Error("Unknown symbol: #{char}")

  if str[0] != '#' or str.length isnt 4
    throw new Error("Invalid symbol format: #{str}")

  [a, b, c] = str.slice(1).split('')
  components = [
    mapping(a),
    mapping(a),
    mapping(b),
    mapping(b),
    mapping(c),
    mapping(c)
  ]
  new SixPhiVector(components)


# Symbolic point definitions
points =
  '#zfp': symbolToSixPhi('#zfp')
  '#zfP': symbolToSixPhi('#zfP')
  '#zPf': symbolToSixPhi('#zPf')
  '#zPF': symbolToSixPhi('#zPF')
  '#fpz': symbolToSixPhi('#fpz')
  '#fPz': symbolToSixPhi('#fPz')
  '#pfz': symbolToSixPhi('#pfz')
  '#pFz': symbolToSixPhi('#pFz')
  '#fzp': symbolToSixPhi('#fzp')
  '#fzP': symbolToSixPhi('#fzP')
  '#fPz': symbolToSixPhi('#fPz')
  '#pFz': symbolToSixPhi('#pFz')
  # (You would continue adding points here to match your full old set)

# Faces built from symbolic point names
faces = [
  ['#zfp', '#zfP', '#zPf', '#zPF', '#zfp'],
  ['#fpz', '#fPz', '#pfz', '#pFz', '#fpz'],
  ['#fzp', '#fzP', '#fPz', '#Fpz', '#fzp'],
  # Extend as needed
]

# Helper to compute a rough center of a face
computeFaceCenter = (face) ->
  acc = new SixPhiVector([ZERO, ZERO, ZERO, ZERO, ZERO, ZERO])
  for name in face
    acc = acc.add(points[name])
  acc.scale(1 / face.length)

# Generate full Memo structure
generateMemo = ->
  M = {}

  for face in faces
    center = computeFaceCenter(face)

    for i in [0..face.length-2]
      a = face[i]
      b = face[i+1]
      c = 'center' + i  # Unique center names if needed internally
      centerPoint = center  # Use one center point for now (refine later if needed)

      id = "#{a}>#{b}>center"

      M[id] =
        path: [a, b, "center"]
        segments: ["#{a}-#{b}", "#{b}-center", "center-#{a}"]
        points: [points[a], points[b], centerPoint]  # Raw SixPhi points (for internal use)

  console.log "Generated #{Object.keys(M).length} triangles."
  return M

export { generateMemo }
