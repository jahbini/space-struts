# sixPhiVector3.coffee
# 3D vector with PhiBase components

import { PhiBase, ZERO } from './phiBase.coffee'

class SixPhiVector3
  constructor: (list) ->
    if list.length isnt 3
      throw new Error("SixPhiVector3 must have exactly 3 elements")
    @x = (if list[0] instanceof PhiBase then list[0] else new PhiBase(0, list[0]))
    @y = (if list[1] instanceof PhiBase then list[1] else new PhiBase(0, list[1]))
    @z = (if list[2] instanceof PhiBase then list[2] else new PhiBase(0, list[2]))

  clone: ->
    new SixPhiVector3([@x.clone(), @y.clone(), @z.clone()])

  set: (list) ->
    if list.length isnt 3
      throw new Error("SixPhiVector3.set requires 3 elements")
    @x = (if list[0] instanceof PhiBase then list[0] else new PhiBase(0, list[0]))
    @y = (if list[1] instanceof PhiBase then list[1] else new PhiBase(0, list[1]))
    @z = (if list[2] instanceof PhiBase then list[2] else new PhiBase(0, list[2]))
    @

  add: (other) ->
    new SixPhiVector3([
      @x.add(other.x),
      @y.add(other.y),
      @z.add(other.z)
    ])

  sub: (other) ->
    new SixPhiVector3([
      @x.sub(other.x),
      @y.sub(other.y),
      @z.sub(other.z)
    ])

  scale: (c) ->
    new SixPhiVector3([
      @x.scale(c),
      @y.scale(c),
      @z.scale(c)
    ])

  negate: ->
    new SixPhiVector3([
      @x.negate(),
      @y.negate(),
      @z.negate()
    ])

  dot: (other) ->
    @x.mul(other.x).add(
      @y.mul(other.y)
    ).add(
      @z.mul(other.z)
    )

  cross: (other) ->
    new SixPhiVector3([
      @y.mul(other.z).sub(@z.mul(other.y)),
      @z.mul(other.x).sub(@x.mul(other.z)),
      @x.mul(other.y).sub(@y.mul(other.x))
    ])

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
    new SixPhiVector3([
      new PhiBase(Math.round(@x.p), Math.round(@x.n)),
      new PhiBase(Math.round(@y.p), Math.round(@y.n)),
      new PhiBase(Math.round(@z.p), Math.round(@z.n))
    ])

  toFloatArray: ->
    [@x.toFloat(), @y.toFloat(), @z.toFloat()]

  toString: ->
    "[#{@x.toString()}, #{@y.toString()}, #{@z.toString()}]"

export { SixPhiVector3 }
