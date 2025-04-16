class SixBasisManager
  constructor: ->
    # Define the six fixed plane normals (one per blade)
    @phi = (1 + Math.sqrt(5)) / 2
    @normals =
      [
        [ @phi,   0,   1 ],   # n₀
        [ @phi,   0,  -1 ],   # n₁
        [  0,     1,  @phi ], # n₂
        [  0,    -1,  @phi ], # n₃
        [  1,   @phi,  0 ],   # n₄
        [ -1,   @phi,  0 ]    # n₅
      ]
    @tolerance = 1e-9
    @points = []      # store completed 6–vectors with intersection point
    @triangles = []   # store arrays of 3 such points

  # -------------------------------
  # String Parsing Helper
  # -------------------------------
  # Given a string like "1-1,1,2-1-1", extract the 6 integers.
  decodeSixVectorString: (s) ->
    # Use a regular expression to match signed integers.
    matches = s.match /-?\d+/g
    if matches? and matches.length is 6
      matches.map (m) -> parseInt(m, 10)
    else
      throw new Error "Invalid six–vector string: #{s}"

  # -------------------------------
  # Basic Linear Algebra Helpers
  # -------------------------------
  dot: (u, v) ->
    sum = 0
    for i in [0...u.length]
      sum += u[i] * v[i]
    sum

  matVec: (M, v) ->
    result = []
    for row in M
      result.push(@dot(row, v))
    result

  transpose: (M) ->
    n = M[0].length
    T = (for j in [0...n] then [])
    for row in M
      for j in [0...n]
        T[j].push(row[j])
    T

  matMul: (A, B) ->
    result = []
    for i in [0...A.length]
      row = []
      for j in [0...B[0].length]
        sum = 0
        for k in [0...B.length]
          sum += A[i][k] * B[k][j]
        row.push(sum)
      result.push(row)
    result

  invert3x3: (M) ->
    a = M[0][0]; b = M[0][1]; c = M[0][2]
    d = M[1][0]; e = M[1][1]; f = M[1][2]
    g = M[2][0]; h = M[2][1]; i = M[2][2]
    det = a*(e*i - f*h) - b*(d*i - f*g) + c*(d*h - e*g)
    if Math.abs(det) < @tolerance
      throw new Error "Matrix is singular or nearly singular."
    invDet = 1.0/det
    [
      [ (e*i - f*h)*invDet, (c*h - b*i)*invDet, (b*f - c*e)*invDet ],
      [ (f*g - d*i)*invDet, (a*i - c*g)*invDet, (c*d - a*f)*invDet ],
      [ (d*h - e*g)*invDet, (b*g - a*h)*invDet, (a*e - b*d)*invDet ]
    ]

  solve3: (A, b) ->
    invA = @invert3x3(A)
    x = []
    for i in [0...3]
      sum = 0
      for j in [0...3]
        sum += invA[i][j] * b[j]
      x.push(sum)
    x

  # -------------------------------
  # Completing a 6–Vector
  # -------------------------------
  # Given a partial 6–vector d (an array of 6 numbers, with missing ones as null),
  # use any three provided offsets (from independent planes) to solve for the unique
  # intersection point x, then complete the vector by computing:
  #   d_complete[i] = – (nᵢ · x)   for i = 0,…,5.
  completeSixVector: (d) ->
    if d.length isnt 6
      throw new Error "Input must be a 6–vector."
    providedIndices = []
    for i in [0...6]
      if d[i] != null then providedIndices.push(i)
    if providedIndices.length < 3
      throw new Error "At least 3 provided offsets are required to determine an intersection point."
    combinations = []
    n = providedIndices.length
    for i in [0...n]
      for j in [(i+1)...n]
        for k in [(j+1)...n]
          combinations.push([providedIndices[i], providedIndices[j], providedIndices[k]])
    chosen = null
    x = null
    for combo in combinations
      A = []
      b = []
      for idx in combo
        A.push(@normals[idx])
        b.push(- d[idx])
      try
        xCandidate = @solve3(A, b)
        chosen = combo
        x = xCandidate
        break
      catch error
        continue
    if chosen == null
      throw new Error "No independent set of 3 provided offsets found."
    d_complete = (for i in [0...6] then - @dot(@normals[i], x))
    { completeVector: d_complete, intersection: x }

  # -------------------------------
  # Data Management: Points and Triangles
  # -------------------------------
  # In addPoint and addTriangle, if the input is a string then convert it.
  ensureArray: (d) ->
    if typeof d is "string"
      @decodeSixVectorString(d)
    else if Array.isArray(d)
      d
    else
      throw new Error "Input must be a 6–vector string or array."

  addPoint: (d) ->
    dArray = @ensureArray(d)
    result = @completeSixVector(dArray)
    pt = { sixVector: result.completeVector, intersection: result.intersection }
    @points.push(pt)
    pt

  addTriangle: (vecArray) ->
    if not Array.isArray(vecArray) or vecArray.length isnt 3
      throw new Error "Triangle must be an array of 3 six–vectors."
    pts = vecArray.map (d) -> @addPoint(d)
    x0 = pts[0].intersection
    for pt in pts
      for i in [0...3]
        if Math.abs(pt.intersection[i] - x0[i]) > @tolerance
          throw new Error "Triangle vertices do not share the same intersection point."
    @triangles.push(pts)
    pts

  exportToJSON: ->
    JSON.stringify { points: @points, triangles: @triangles }, null, 2

# -------------------------------
# Example Usage
# -------------------------------
manager = new SixBasisManager()

# Using a string encoded 6–vector.
stringVector = "1-1,2,3-4,5"  # Note: Adjust this to represent 6 integers. For example, "1-1,2,3-4,5" should yield [1, -1, 2, 3, -4, 5].
ptFromString = manager.addPoint(stringVector)
console.log "Stored point from string:", ptFromString

# Using an array of 6 integers (with some entries null).
partialVector = [ 1, null, 2, null, -4, null ]
ptFromPartial = manager.addPoint(partialVector)
console.log "Stored point from partial array:", ptFromPartial

# Adding a triangle, mixing string and array representations.
triangle = manager.addTriangle([
  "1-1,2,3-4,5",   # string encoding of a 6–vector
  [ 1, null, 2, null, -4, null ],
  "1-1,2,3-4,5"    # same as the first one
])
console.log "Stored triangle:", triangle
