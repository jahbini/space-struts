# phiBase.coffee
# Represents numbers of the form (p * φ + n) / d  —  exact elements of Q(φ).
# d defaults to 1, so an integer pair P(p, n) is the lattice element pφ + n.
# Division is exact (conjugate / algebraic-norm); a result with d == 1 lies in
# Z[φ], a result with d > 1 has left the integer lattice (membership test).

PHI = (1 + Math.sqrt(5)) / 2

igcd = (a, b) ->
  a = Math.abs(a); b = Math.abs(b)
  while b != 0
    [a, b] = [b, a % b]
  a

class PhiBase
  constructor: (p, n, d = 1) ->
    @p = p
    @n = n
    @d = d
    @_reduce()

  PhiBase.PHI = PHI
  PhiBase.ZERO = new PhiBase(0, 0)
  PhiBase.ONE = new PhiBase(0, 1)

  # Canonicalize the fraction: positive denominator, lowest terms. The d == 1
  # case (the overwhelming majority) returns immediately at zero cost, so plain
  # integer/float PhiBase numbers behave exactly as before.
  _reduce: ->
    return this if @d == 1
    throw new Error("PhiBase denominator zero") if @d == 0
    if @d < 0
      @p = -@p; @n = -@n; @d = -@d
    if Number.isInteger(@p) and Number.isInteger(@n) and Number.isInteger(@d)
      g = igcd(igcd(@p, @n), @d)
      if g > 1
        @p /= g; @n /= g; @d /= g
    this

  clone: ->
    new PhiBase(@p, @n, @d)

  # true when the value is an integer lattice element of Z[φ] (no denominator)
  inLattice: ->
    @d == 1

  add: (other) ->
    if @d == 1 and other.d == 1
      return new PhiBase(@p + other.p, @n + other.n)
    new PhiBase(@p * other.d + other.p * @d, @n * other.d + other.n * @d, @d * other.d)

  sub: (other) ->
    if @d == 1 and other.d == 1
      return new PhiBase(@p - other.p, @n - other.n)
    new PhiBase(@p * other.d - other.p * @d, @n * other.d - other.n * @d, @d * other.d)

  negate: ->
    new PhiBase(-@p, -@n, @d)

  scale: (c) ->
    if c instanceof PhiBase
      @mul(c)
    else
      new PhiBase(@p * c, @n * c, @d)

  step: (incr=1) ->
    phiValue = (this.p + 1) * PhiBase.PHI; # φ as static or imported
    nIncr = this.n + incr
    if (nIncr < phiValue)
      return new PhiBase(this.p, nIncr)
    else
      return new PhiBase(this.p + 1, this.n)

  mul: (other) ->
    # (p1 φ + n1)(p2 φ + n2) = (p1 n2 + n1 p2 + p1 p2) φ + (n1 n2 + p1 p2),
    # using φ² = φ + 1; denominators multiply.
    if @d == 1 and other.d == 1
      return new PhiBase(
        @p * other.n + @n * other.p + @p * other.p,
        @n * other.n + @p * other.p)
    new PhiBase(
      @p * other.n + @n * other.p + @p * other.p,
      @n * other.n + @p * other.p,
      @d * other.d)

  # algebraic conjugate of the numerator: pφ+n ↦ -pφ+(p+n)
  conjugate: ->
    new PhiBase(-@p, @p + @n, @d)

  # algebraic norm of the numerator: N(pφ+n) = n² + np − p²  (a rational integer)
  norm: ->
    @n * @n + @n * @p - @p * @p

  div: (other) ->
    return @clone() if other.p == 0 and other.n == 1 and other.d == 1
    throw new Error("Division by zero in PhiBase") if other.p == 0 and other.n == 0
    # (a/da) / (b/db) = (a · conj(b) · db) / (N(b) · da)
    cp = -other.p
    cn = other.p + other.n
    numP = @p * cn + @n * cp + @p * cp
    numN = @n * cn + @p * cp
    bNorm = other.n * other.n + other.n * other.p - other.p * other.p
    new PhiBase(numP * other.d, numN * other.d, bNorm * @d)

  equals: (other) ->
    Math.abs(@toFloat() - other.toFloat()) < 1e-9

  toFloat: ->
    (@p * PHI + @n) / @d

  toName: ->
    ee = (xx) -> Math.trunc(xx * 1000)
    base = "#{ee(@p)}φ,#{ee(@n)}"
    if @d == 1 then base else base + "/#{@d}"

  toID: ->
    if @d == 1 then "P(#{@p},#{@n})" else "P(#{@p},#{@n},#{@d})"

  toString: ->
    parts = []
    parts.push("#{@p}φ") if @p != 0
    parts.push("#{@n}") if @n != 0
    body = parts.join(' + ') or '0'
    if @d == 1 then body else "(#{body}) / #{@d}"

  @fromFloat1: (num, tolerance = 1e-8) ->
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

  @fromFloat: (num, tolerance = 1e-6, maxOrder = 20) ->
    best = { p: 0, n: 0, value: 0, error: Infinity };

    F = [0, 1]; # Fibonacci seed
    for k in [ 2 .. maxOrder]
      F[k] = F[k - 1] + F[k - 2];

    for i in [ 2 .. maxOrder]
      p = F[i];
      n = -F[i + 1];

      for delta in [ -2 .. 2]
        testP = p + delta;
        testN = n + Math.round( num - testP * PHI );

        val = testP * PHI + testN;
        error = Math.abs(val - num);

        if (error < best.error)
          best = new PhiBase testP, testN
          best.value = val
          if error < tolerance
            return best;

    return best;


# Useful constants
ZERO = new PhiBase(0, 0)
ONE  = new PhiBase(0, 1)

export { PHI, PhiBase, ZERO, ONE }
