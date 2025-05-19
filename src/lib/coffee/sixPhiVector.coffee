# sixPhiVector.coffee
# Full six-basis vector math, symbolic PhiBase style

import { PhiBase, ZERO } from './phiBase.coffee'
import { GeoPhi } from './geoPhi.coffee'

PHI=PhiBase.PHI
# set the scaling factor for the dot product to one for calibration
# G_SCALE will be corrected when the class is properly defined below
G_SCALE = 1.0
testing = false # end of file confidence tests of this class

# sixBasisPhi.coffee
# Defines the six basis vectors using PhiBase notation
sixBases =
  [
    [ PHI, 0, 1 ]   # phi, 0, 1
    [ PHI, 0, -1 ]  # phi, 0, -1
    [ 0, 1, PHI ]    # 0, 1, phi
    [ 0, -1, PHI ]   # 0, -1, phi
    [ 1, PHI, 0 ]    # 1, phi, 0
    [ -1, PHI, 0 ]   # -1, phi, 0
  ]

# Assumes PhiBase is already loaded or imported
p = (phi, n) -> new PhiBase(phi, n)

sixPhiBases =
  [
    [ p(1, 0), p(0, 0), p(0, 1) ]  # +phi along x, +1 along z
    [ p(1, 0), p(0, 0), p(0,-1) ] # +phi along x, -1 along z
    [ p(0, 0), p(0, 1), p(1, 0) ]  # +phi along y, +1 along z
    [ p(0, 0), p(0,-1), p(1, 0) ] # -phi along y, +1 along z
    [ p(0, 1), p(1, 0), p(0, 0) ]  # +1 along x, +phi along y
    [ p(0,-1), p(1, 0), p(0, 0) ] # +1 along x, -phi along y
  ]
# PhiBase Metric Tensor G for sixPhi system
# Each entry G[i][j] = PhiBase(p, n) means p*phi + n

# Generate exact metric tensor G from basis vectors
G = []
for i in [0...6]
  row = []
  for j in [0...6]
    sum = p(0, 0)
    for k in [0..2]
      sum = sum.add(sixPhiBases[i][k].mul(sixPhiBases[j][k]))
    row.push(sum)
  G.push(row)

testing = false
if testing
  # Optional diagnostic: dump G as .toName() for readability
  console.log "\nExact Metric Tensor G (symbolic):"
  for row in G
    console.log row.map((g) -> g.toName()).join(', ')

buildReferenceVector = ->
  new SixPhiVector([
    p(1,1), p(1,-1), p(1,1),
    p(1,-1), p(1,1), p(1,-1)
  ])



class SixPhiVector
  constructor: (list) ->
    if list.length isnt 6
      throw new Error("SixPhiVector must have exactly 6 elements")
    @v = for x in list
           if x instanceof PhiBase 
             x
           else 
             new PhiBase(0, x)

  clone: ->
    new SixPhiVector(@v.map((x) -> x.clone()))

  set: (list) ->
    if list.length isnt 6
      throw new Error("SixPhiVector.set requires 6 elements")
    @v = for x in list
          if x instanceof PhiBase 
            x 
          else 
            new PhiBase(0, x)
    @

  add: (other) ->
    new SixPhiVector(@v.map((x, i) -> x.add(other.v[i])))

  sub: (other) ->
    new SixPhiVector(@v.map((x, i) -> x.sub(other.v[i])))

  equals: (other)->
    result = true
    @v.map( (x,i) -> result= result and x.equals other.v[i] )
    return result

  scale: (c) ->
    new SixPhiVector(@v.map((x) -> x.scale(c)))

  negate: ->
    new SixPhiVector(@v.map((x) -> x.negate()))

  dot: (other) ->
    result = p(0, 0)
    for i in [0..5]
      for j in [0..5]
        result = result.add(@v[i].mul(other.v[j]).mul(G[i][j]))
    result.scale(G_SCALE)

  magnitudeSquared: ->
    @dot(@)

  magnitude: ->
    @magnitudeSquared().toFloat() ** 0.5

  normalize: ->
    mag = @magnitude()
    if mag == 0
      throw new Error("Cannot normalize a zero vector")
    scaleFactor = 1 / mag
    @scale(scaleFactor)

  round: ->
    new SixPhiVector(
      @v.map((x) ->
        new PhiBase(Math.round(x.p), Math.round(x.n))
      )
    )

  toFloatArray: ->
    @v.map((x) -> x.toFloat())

  toString: ->
    '[' + @v.map((x) -> x.toString()).join(', ') + ']'

  @fromCartesian: (x, y, z) ->
    v = for b in sixBases
      dot = x*b[0] + y*b[1] + z*b[2]
      PhiBase.fromFloat(dot)
    return new SixPhiVector v 

  @fromPhiPoint: ( x, y, z) ->
    v = for b in sixPhiBases
      dot = x.mul b[0]
      dot = dot.add y.mul( b[1]) 
      dot = dot.add z.mul( b[2])
    return new SixPhiVector v 
  
  sixPhiToCartesianDisplay: ()->
    [a, b, c, d, e, f] = @v
    return [
      (e.sub(f).add(p(1,0).mul(a.add(b)))).div(p(2,4)).toFloat(), 
      (c.sub(d).add(p(1,0).mul(e.add(f)))).div(p(2,4)).toFloat(),
      (a.sub(b).add(p(1,0).mul(c.add(d)))).div(p(2,4)).toFloat()
    ]

  reflect: ( faceID ) ->
    r = new sixPhiVector @.v
    r.v[faceID] = r.v[faceID].negate()
    r

G_SCALE = 3 / buildReferenceVector().dot(buildReferenceVector()).toFloat()

# Input: Cartesian coordinates (x, y, z)
# Output: { sixPhiVector, residual: [dx, dy, dz], distance }
quantizedFromCartesian = (x, y, z) ->
  v = new SixPhiVector(SixPhiVector.fromCartesian(x, y, z))  # Best symbolic approximation
  [xp, yp, zp] = v.toCartesian()

  dx = x - xp
  dy = y - yp
  dz = z - zp

  distance = Math.sqrt(dx*dx + dy*dy + dz*dz)

  return {
    sixPhiVector: v
    residual: [dx, dy, dz]
    distance: distance
  }
# Useful constant
ZERO6 = new SixPhiVector([ZERO, ZERO, ZERO, ZERO, ZERO, ZERO])
export { quantizedFromCartesian, SixPhiVector, ZERO6 }

testing = false
if testing
    # --- Symmetry check ---
  console.log "Checking symmetry of G..."
  for i in [0...6]
    for j in [0...6]
      unless G[i][j].equals(G[j][i])
        console.error "G[\#{i}][\#{j}] ≠ G[\#{j}][\#{i}]"

  # --- Positive semi-definiteness ---
  console.log "Checking positive semi-definiteness of G..."
  for i in [0...6]
    v = [0,0,0,0,0,0].map (x, j) -> if j == i then PhiBase.ONE else PhiBase.ZERO
    vec = new SixPhiVector(v)
    mag2 = vec.dot(vec).toFloat()
    if mag2 < 0
      console.warn "G makes basis vector \#{i} have negative squared magnitude: \#{mag2}"

  # --- Expected dot products ---
  expected = {
    '0-1': p(1,0),
    '0-5': p(0,-2),
    '3-4': p(0,-2)
  }
  for key, val of expected
    [i, j] = key.split('-').map(Number)
    actual = G[i][j]
    unless actual.equals(val)
      console.error "Mismatch: G[\#{i}][\#{j}] = \#{actual.toName()} ≠ expected \#{val.toName()}"

  # Define two test points
  A = new SixPhiVector([p(0,1), p(0,0), p(0,0), p(0,0), p(0,0), p(0,0)])  # unit in dir 0
  B = new SixPhiVector([p(0,0), p(0,0), p(0,0), p(0,0), p(0,0), p(0,0)])  # origin

  # Compute vector difference and magnitude
  D = A.sub(B)
  console.log "D = ", D.toString()
  mag2 = D.dot(D, true)
  console.log "distance² = #{mag2.toName()} → float: #{mag2.toFloat()}"
  console.log "All G matrix and dot product checks complete."

