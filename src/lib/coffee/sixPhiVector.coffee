# sixPhiVector.coffee
# Full six-basis vector math, symbolic PhiBase style

import { PhiBase, ZERO , ONE } from './phiBase.coffee'
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
  constructor: (list,@scaleFactor=PhiBase.ONE) ->
    if list.length isnt 6
      throw new Error("SixPhiVector must have exactly 6 elements")
    @v = for x in list
           if x instanceof PhiBase 
             x
           else 
             new PhiBase(0, x)

  clone: ->
    new SixPhiVector(@v.map((x) -> x.clone()),@scaleFactor)

  add: (other) ->
    myScale = @scaleFactor
    new SixPhiVector(@v.map((x, i) -> x.mul(myScale).add(other.v[i].mul(other.scaleFactor) )), @scaleFactor.mul(other.scaleFactor) )

  sub: (other) ->
    myScale = @scaleFactor
    new SixPhiVector(@v.map((x, i) -> x.scale(myScale).sub(other.v[i].scale(other.scaleFactor) )),@scaleFactor.mul(other.scaleFactor))

  equals: (other)->
    result = true
    @v.map( (x,i) -> result= result and x.equals other.v[i] )
    return result and @scaleFactor == other.scaleFactor

  scale: (c) ->
    myScale = @scaleFactor
    return new SixPhiVector(@v.map((x) -> x),@scaleFactor.scale(c))
      
  negate: ->
    new SixPhiVector(@v.map((x) -> x.negate()),@scaleFactor)

  dot: (other) ->
    result = p(0, 0)
    dotScale=@scaleFactor.mul(other.scaleFactor)
    for i in [0..5]
      for j in [0..5]
        result = result.add(@v[i].mul(other.v[j]).mul(G[i][j]))
    result.div(dotScale).scale(G_SCALE)

  magnitudeSquared: ->
    @dot(@)

  magnitude: ->
    @magnitudeSquared().toFloat() ** 0.5

  round: ->
    new SixPhiVector(
      @v.map((x) ->
        new PhiBase(Math.round(x.p), Math.round(x.n))
      )
    )

  toFloatArray: ->
    sF=@scaleFactor
    @v.map((x) -> x.div(sF).toFloat())

  toName: ->
    '[' + @v.map((x) -> x.toName()).join(', ') + '|' + @scaleFactor.toName() + ']'

  toString: ->
    '[' + @v.map((x) -> x.toString()).join(', ') + '|' + @scaleFactor.toName() + ']'

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
    scaleResult = p(2,4).mul(@scaleFactor)
    return [
      (e.sub(f).add(p(1,0).mul(a.add(b)))).div(scaleResult,true).toFloat(), 
      (c.sub(d).add(p(1,0).mul(e.add(f)))).div(scaleResult,true).toFloat(),
      (a.sub(b).add(p(1,0).mul(c.add(d)))).div(scaleResult,true).toFloat()
    ]

  reflectSymbolic: (faceChar) ->
    swapPairs =
      A: [0, 1]
      B: [2, 3]
      C: [4, 5]
      D: [0, 2]
      E: [1, 4]
      F: [3, 5]

    [i, j] = swapPairs[faceChar]
    newV = @v.slice()
    tmp = newV[i]
    newV[i] = newV[j]
    newV[j] = tmp

    new SixPhiVector(newV, @scaleFactor)

  reflect: (k) ->
    v=@.v
    u = new SixPhiVector [0,0,0,0,0,0]
    u.v[k] = p(0,1)  # symbolic unit
    dotVU = p(0,0); dotUU = p(0,0)
    for i in [0...6]
      for j in [0...6]
        dotVU = dotVU.add( v[i].mul(G[i][j]).mul(u.v[j]) )
        dotUU = dotUU.add( u.v[i].mul(G[i][j]).mul(u.v[j]) )

    # Multiply numerator to project and subtract 2×proj from v
    numerator = dotVU.mul(p(0,2))  # projection scaled by 2

    reflected = []
    for i in [0...6]
      proj = u.v[i].mul(numerator)
      reflected[i] = v[i].sub(proj)
    new SixPhiVector reflected, @scaleFactor.mul(dotUU) 


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

