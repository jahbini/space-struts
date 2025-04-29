# sixPhiVector.coffee
# Full six-basis vector math, symbolic PhiBase style

import { PhiBase, ZERO } from './phiBase.coffee'

class SixPhiVector
  constructor: (list) ->
    if list.length isnt 6
      throw new Error("SixPhiVector must have exactly 6 elements")
    @v = (if x instanceof PhiBase then x else new PhiBase(0, x) for x in list)

  clone: ->
    new SixPhiVector(@v.map((x) -> x.clone()))

  set: (list) ->
    if list.length isnt 6
      throw new Error("SixPhiVector.set requires 6 elements")
    @v = (if x instanceof PhiBase then x else new PhiBase(0, x) for x in list)
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

  fromCartesian: (x, y, z) ->
    @v = for b in sixBases
      dot = x*b[0] + y*b[1] + z*b[2]
      PhiBase.fromFloat(dot)
    return @

# Input: Cartesian coordinates (x, y, z)
# Output: { sixPhiVector, residual: [dx, dy, dz], distance }
quantizedFromCartesian = (x, y, z) ->
  v = new sixPhiVector().fromCartesian(x, y, z)  # Best symbolic approximation
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
