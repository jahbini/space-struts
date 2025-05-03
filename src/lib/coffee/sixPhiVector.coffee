# sixPhiVector.coffee
# Full six-basis vector math, symbolic PhiBase style

import { PhiBase, ZERO } from './phiBase.coffee'

PHI=PhiBase.PHI
# sixBasisPhi.coffee
# Defines the six basis vectors using PhiBase notation

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

sixBases =
  [
    [ PHI, 0, 1 ]   # phi, 0, 1
    [ PHI, 0, -1 ]  # phi, 0, -1
    [ 0, 1, PHI ]    # 0, 1, phi
    [ 0, -1, PHI ]   # 0, -1, phi
    [ 1, PHI, 0 ]    # 1, phi, 0
    [ -1, PHI, 0 ]   # -1, phi, 0
  ]

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

  scale: (c) ->
    new SixPhiVector(@v.map((x) -> x.scale(c)))

  negate: ->
    new SixPhiVector(@v.map((x) -> x.negate()))

  dot: (other) ->
    result = ZERO
    for i in [0..5]
      result = result.add(@v[i].mul(other.v[i]))
    result

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
