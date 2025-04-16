import { Memo } from  './memo.js'
memo = new Memo()
phi = (1 + Math.sqrt 5) / 2

export class PhiBase
  constructor: (@p, @x) ->

  # Addition: (p₁,x₁) + (p₂,x₂) = (p₁+p₂, x₁+x₂)
  add: (other) ->
    new PhiBase @p + other.p, @x + other.x

  # Subtraction: (p₁,x₁) - (p₂,x₂) = (p₁-p₂, x₁-x₂)
  sub: (other) ->
    new PhiBase @p - other.p, @x - other.x

  # Multiply two PhiBase numbers exactly:
  # (p₁φ + x₁) * (p₂φ + x₂) = (p₁x₂ + p₂x₁ + p₁p₂)φ + (x₁x₂ + p₁p₂)
  mul: (other) ->
    newP = @p * other.x + @x * other.p + @p * other.p
    newX = @x * other.x + @p * other.p
    new PhiBase newP, newX

  # Multiply by an integer n:
  mulInt: (n) ->
    new PhiBase @p * n, @x * n

  # Conjugate: φ ↦ (1 - φ), thus (p,x) ↦ (-p, x+p)
  conjugate: ->
    new PhiBase -@p, @x + @p

  # Norm: N(pφ+x) = (pφ+x)*(p(1-φ)+x+p) is integer: x² + x*p - p²
  norm: ->
    (@x * @x) + (@x * @p) - (@p * @p)

  # Division: a/b = a * conjugate(b) / norm(b)
  div: (other) ->
    normB = other.norm()
    throw new Error "Divide by zero" if normB is 0
    numerator = @mul other.conjugate()
    new PhiBase numerator.p / normB, numerator.x / normB

  # Exact equality check
  equals: (other) ->
    @p is other.p and @x is other.x

  # Convert PhiBase number exactly to floating-point for final display only.
  value: ->
    @p * phi + @x

  # Friendly string representation: p(p,x)
  toString: ->
    "p(#{@p},#{@x})"


# Storing and retrieving PhiBase pairs
phiKey = "P1,2" # φ*1 + 2 exactly
memo.saveThis phiKey, new PhiBase(1,2)

# Retrieve exactly later
retrievedPhi = memo.theLowdown(phiKey).value
console.log retrievedPhi.toString()  # Outputs: "p(1,2)"

# Storing six-basis vectors exactly
vectorKey = "V1-2,2-1-1,0"
sixVector = [1,-2,2,-1,-1,0]
memo.saveThis vectorKey, sixVector

# Wait asynchronously for a dependent computation:
memo.waitFor ["P1,2", "V1-2,2-1-1,0"], ->
  phiVal = memo.theLowdown("P1,2").value
  vecVal = memo.theLowdown("V1-2,2-1-1,0").value
  console.log "Values ready:", phiVal.toString(), vecVal
# Additional methods for convenience

Memo::savePhiBase = (p,x)->
  key = "P#{p},#{x}"
  @saveThis key, new PhiBase(p,x)

Memo::getPhiBase = (p,x)->
  key = "P#{p},#{x}"
  @theLowdown(key).value

Memo::saveSixVector = (vec)->
  key = "V#{vec.join(',')}"
  @saveThis key, vec

Memo::getSixVector = (vec)->
  key = "V#{vec.join(',')}"
  @theLowdown(key).value
a = new PhiBase 2, 3
b = new PhiBase -1, 5

console.log "a:", a.toString()       # "p(2,3)"
console.log "b:", b.toString()       # "p(-1,5)"

c = a.add b
console.log "a+b:", c.toString()     # "p(1,8)"

d = a.mul b
console.log "a*b:", d.toString()     # Calculated exactly

e = a.div b
console.log "a/b:", e.toString()     # Exact division result

console.log "a equals b?", a.equals b  # false
