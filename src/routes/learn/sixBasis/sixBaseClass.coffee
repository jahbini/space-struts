phi = (1 + Math.sqrt(5)) / 2

SixVector = class

  # Static basis shared across all instances
  @basis = [
    [phi, 0, 1]
    [phi, 0, -1]
    [0, 1, phi]
    [0, -1, phi]
    [1, phi, 0]
    [-1, phi, 0]
  ]

  constructor: (input) ->
    if input.length isnt 6
      throw new Error("SixVector input must be an array of 6 values (numbers or nulls)")

    @coeffs = []
    @isComplete = true

    for i in [0..5]
      val = input[i]
      if typeof val is 'number' and not isNaN(val)
        @coeffs[i] = val
      else
        @coeffs[i] = 0
        @isComplete = false

  complete: ->
    return if @isComplete

    known = []
    for i in [0..5]
      val = @coeffs[i]
      if val? and typeof val is 'number' and val != 0
        known.push [i, val]

    if known.length isnt 3
      throw new Error("Cannot complete SixVector: must have exactly 3 known coefficients")

    used = (i for [i, _] in known)
    knownVec = [0, 0, 0]
    for [i, c] in known
      b = SixVector.basis[i]
      knownVec = [
        knownVec[0] + c * b[0]
        knownVec[1] + c * b[1]
        knownVec[2] + c * b[2]
      ]
    console.log "jim here 2", used, knownVec

    unused = (i for i in [0..5] when used.indexOf(i) < 0)
    A = unused.map (i) -> SixVector.basis[i]

    det = (M) ->
      console.log "det of" , M
      M[0][0]*(M[1][1]*M[2][2] - M[1][2]*M[2][1]) -
      M[0][1]*(M[1][0]*M[2][2] - M[1][2]*M[2][0]) +
      M[0][2]*(M[1][0]*M[2][1] - M[1][1]*M[2][0])

    makeMat = (col) ->
      A.map (row, i) ->
        row.map (v, j) ->
          val = if j is col then -knownVec[i] else v
          if typeof val isnt 'number' or isNaN(val)
            throw new Error("Non-numeric entry in matrix at row #{i}, col #{j}: #{val}")
          val

    console.log "jim here4", A
    D = det A
    console.log "jim here 5", D
    if Math.abs(D) < 1e-10
      throw new Error("Degenerate basis system (determinant ~ 0): #{D}")

    x = det(makeMat(0)) / D
    y = det(makeMat(1)) / D
    z = det(makeMat(2)) / D
    console.log "jim not here", x,y,z

    if [x, y, z].some (v) -> typeof v isnt 'number' or isNaN(v)
      throw new Error("Invalid solution: x=#{x}, y=#{y}, z=#{z}")

    @coeffs[unused[0]] = x
    @coeffs[unused[1]] = y
    @coeffs[unused[2]] = z
    @isComplete = true

  toCartesian: ->
    @complete() unless @isComplete
    result = [0, 0, 0]
    for i in [0..5]
      b = SixVector.basis[i]
      c = @coeffs[i]
      result = [
        result[0] + c * b[0]
        result[1] + c * b[1]
        result[2] + c * b[2]
      ]
    result

  toString: ->
    coeffsStr = @coeffs.map((x) -> x?.toFixed?(3) or "null").join(", ")
    cartesian = @toCartesian().map((x) -> x.toFixed(3)).join(", ")
    "6-vector: [#{coeffsStr}]\nCartesian: [#{cartesian}]"


v = new SixVector([null, 2, null, 1, 1, null])
console.log v.toString()
