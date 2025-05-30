# phiBase.coffee
# Represents numbers of the form (p * φ + n)

PHI = (1 + Math.sqrt(5)) / 2

class PhiBase
  constructor: (p, n) ->
    @p = p
    @n = n

  PhiBase.PHI=PHI
  # Useful constants
  PhiBase.ZERO = new PhiBase(0, 0)
  PhiBase.ONE = new PhiBase(0, 1)


  clone: ->
    new PhiBase(@p, @n)

  add: (other) ->
    new PhiBase(@p + other.p, @n + other.n)

  sub: (other) ->
    new PhiBase(@p - other.p, @n - other.n)

  negate: ->
    new PhiBase(-@p, -@n)

  scale: (c) ->
    if c instanceof PhiBase
      @mul(c)
    else
      new PhiBase(@p * c, @n * c)

  step: (incr=1) ->
    phiValue = (this.p + 1) * PhiBase.PHI; # φ as static or imported
    nIncr = this.n + incr
    if (nIncr < phiValue) 
      return new PhiBase(this.p, nIncr)
    else 
      return new PhiBase(this.p + 1, this.n)

  mul: (other) ->
    # (p1 * φ + n1) * (p2 * φ + n2) = (p1*n2 + n1*p2 + p1*p2) * φ + (n1*n2 + p1*p2)
    new PhiBase(
      @p * other.n + @n * other.p + @p * other.p,
      @n * other.n + @p * other.p
    )

  div: (other , report = false) ->
    # Phi-algebra division
    phiMinusOne = new PhiBase(1, -1)
    newNumerator = @mul(phiMinusOne)
    newDenominator = other.mul(phiMinusOne)

    denomValue = newDenominator.toFloat()
    if denomValue == 0
      throw new Error("Division by zero in PhiBase")

    resultP = newNumerator.p / denomValue
    resultN = newNumerator.n / denomValue

    if report && (not Number.isInteger(resultP) or not Number.isInteger(resultN))
      console.log "Notice: Non-integer PhiBase division result:", resultP, resultN

    new PhiBase(resultP, resultN)

  equals: (other) ->
    ee = (xx) -> Math.trunc(xx*1000)
    ee=(xx)->Math.sign(xx)*Math.round(Math.abs(xx)*1000)
    ee(@p) == ee(other.p) and ee(@n) == ee(other.n)

  toFloat: ->
    @p * PHI + @n

  toName: ->
    ee = (xx) -> Math.trunc(xx*1000)
    ee=(xx)->Math.sign(xx)*Math.round(Math.abs(xx)*1000)
    "#{ee(@p)}φ," + "#{ee(@n)}"

  toString: ->
    parts = []
    parts.push("#{@p}φ") if @p != 0
    parts.push("#{@n}") if @n != 0
    parts.join(' + ') or '0'

  @fromFloat: (num, tolerance = 1e-8) ->
    neg = false
    if num < 0
      neg = true
      num = -num  # Work with positive value only

    x = new PhiBase(0, 0)
    best = x
    bestErr = Math.abs(x.toFloat() - num)

    while true
      candidate = x.step()
      candVal = candidate.toFloat()
      err = Math.abs(candVal - num)

      if err < bestErr
        best = candidate
        bestErr = err
        x = candidate
      else
        break

    if neg
      return best.scale(-1)  # Negate the result if input was negative
    else
      return best
# Useful constants
ZERO = new PhiBase(0, 0)
ONE  = new PhiBase(0, 1)

export { PHI, PhiBase, ZERO, ONE }
