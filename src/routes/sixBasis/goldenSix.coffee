# dodecahedron_face_jumps.coffee
# This program categorizes the legal jump vectors (differences) from the dodecahedron's vertices
# by the face from which they are derived. We compute both 1-step and 2-step differences.

# ==================================================
# 1. Define the 20 Legal 6-Space Vertices
# (Each vertex is a 6-vector [v0, v1, v2, v3, v4, v5])
vertices = [
  # Bottom pentagon
  [0, 0, -2, 0, 1, 1]
  [1, -1, -1, 1, 0, 1]
  [1, -1, 1, -1, -1, 0]
  [0, 0, 2, 0, -1, -1]
  [-1, 1, 1, -1, 0, -1]

  # Middle belt (10 vertices)
  [1, 1, 0, 0, 1, -1]
  [1, 1, 0, 0, -1, 1]
  [0, 0, 1, -1, 1, 1]
  [0, 0, -1, 1, -1, -1]
  [-1, -1, 0, 0, 1, -1]
  [-1, -1, 0, 0, -1, 1]
  [0, 0, 1, -1, -1, -1]
  [0, 0, -1, 1, 1, 1]
  [1, -1, 1, 0, 0, 1]
  [-1, 1, -1, 0, 0, -1]

  # Top pentagon
  [0, 0, -2, 0, -1, -1]
  [1, -1, -1, 1, 0, -1]
  [1, -1, 1, -1, 1, 0]
  [0, 0, 2, 0, 1, 1]
  [-1, 1, 1, -1, 0, 1]
]

# ==================================================
# 2. Define the 12 Faces of the Dodecahedron
# Each face is represented as a pentagon given by an array of 5 vertex indices,
# listed in circular, counterclockwise order.
faces = [
  # Bottom face (pentagon)
  [0, 1, 2, 3, 4]

  # Top face (pentagon)
  [15, 16, 17, 18, 19]

  # 10 Side faces (each a pentagon connecting the bottom, belt, and top)
  [0, 5, 6, 7, 1]
  [1, 7, 8, 9, 2]
  [2, 9, 10, 11, 3]
  [3, 11, 12, 13, 4]
  [4, 13, 14, 5, 0]
  [15, 10, 9, 8, 16]
  [16, 8, 7, 6, 17]
  [17, 6, 5, 14, 18]
  [18, 14, 13, 12, 19]
  [19, 12, 11, 10, 15]
]

# ==================================================
# 3. Compute and Categorize the Difference (Jump) Vectors by Face
# For each face, we compute:
#   - 1-step differences: difference between consecutive vertices (wrap-around)
#   - 2-step differences: difference between vertices two apart (wrap-around)
# We store the result in an object keyed by the face index.
faceJumps = {}

# Helper function: subtract one 6-vector from another (v2 - v1)
subtractVectors = (v2, v1) ->
  (v2[i] - v1[i] for i in [0...6])

# Iterate over each face to compute jump vectors.
faces.forEach (face, faceIndex) ->
  oneStep = []
  twoStep = []
  n = face.length  # should be 5 for a pentagon

  # Compute 1-step differences
  for i in [0...n]
    iNext = (i + 1) % n
    vCurrent = vertices[face[i]]
    vNext = vertices[face[iNext]]
    oneStep.push subtractVectors(vNext, vCurrent)

  # Compute 2-step differences
  for i in [0...n]
    iNext2 = (i + 2) % n
    vCurrent = vertices[face[i]]
    vNext2 = vertices[face[iNext2]]
    twoStep.push subtractVectors(vNext2, vCurrent)

  faceJumps[faceIndex] = { oneStep: oneStep, twoStep: twoStep }

# ==================================================
# 4. Output the Categorized "Golden Links"
# For each face, we output its index, the corresponding vertex indices, and the jump vectors.
console.log "Categorized Golden Links by Face (jump vectors in 6-space):"
faces.forEach (face, faceIndex) ->
  console.log "Face #{faceIndex} (vertices: #{face}):"
  console.log "  1-step differences:"
  faceJumps[faceIndex].oneStep.forEach (vec, i) ->
    console.log "    from vertex #{face[i]} to vertex #{face[(i + 1) % face.length]}: #{JSON.stringify(vec)}"
  
  console.log "  2-step differences:"
  faceJumps[faceIndex].twoStep.forEach (vec, i) ->
    console.log "    from vertex #{face[i]} to vertex #{face[(i + 2) % face.length]}: #{JSON.stringify(vec)}"
  
  console.log ""
