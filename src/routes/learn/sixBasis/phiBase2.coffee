class PhiExpression
  constructor: (@p, @n) ->

  toString: () ->
    "P(#{@p}, #{@n})"  # For debugging/display purposes

  evaluate: () ->
    # Evaluate the expression to a floating-point number
    phi = (1 + Math.sqrt(5)) / 2
    @p * phi + @n

  add: (other) ->
    # Addition: P(p1, n1) + P(p2, n2) = P(p1 + p2, n1 + n2)
    new PhiExpression(@p + other.p, @n + other.n)

  subtract: (other) ->
    # Subtraction: P(p1, n1) - P(p2, n2) = P(p1 - p2, n1 - n2)
    new PhiExpression(@p - other.p, @n - other.n)

  multiply: (other) ->
    # Multiplication: P(p1, n1) * P(p2, n2) = P(p1*p2 + p1*n2 + n1*p2, n1*n2 + p1*p2)
    # Since Phi^2 = Phi + 1, then (a + b*Phi) * (c + d*Phi) = (ac + ad*Phi + bc*Phi + bd*Phi^2) = (ac + ad*Phi + bc*Phi + bd*(Phi + 1)) = (ac + bd) + (ad + bc + bd)*Phi
    new_p = @p * other.n + @n * other.p + @p * other.p
    new_n = @n * other.n + @p * other.p
    new PhiExpression(new_p, new_n)

  simplify: () ->
    # Simplification (basic):  If p or n are floating point, convert to integers if possible
    @p = Math.round(@p) if (typeof @p == 'number') && (Math.abs(@p - Math.round(@p)) < 1e-9)
    @n = Math.round(@n) if (typeof @n == 'number') && (Math.abs(@n - Math.round(@n)) < 1e-9)
    this # Return the simplified object

# Example Usage:
p1 = new PhiExpression(1, 0)  # Represents Phi
p2 = new PhiExpression(0, 1)  # Represents 1
p3 = new PhiExpression(1, 1)  # Represents Phi + 1

# Addition
sum = p1.add(p2)
console.log "#{p1.toString()} + #{p2.toString()} = #{sum.toString()}"  # Output: P(1, 0) + P(0, 1) = P(1, 1)
console.log "Evaluated: #{sum.evaluate()}" #Evaluated: 2.618033988749895

# Multiplication
product = p1.multiply(p2)
console.log "#{p1.toString()} * #{p2.toString()} = #{product.toString()}" # Output: P(1, 0) * P(0, 1) = P(1, 0)
console.log "Evaluated: #{product.evaluate()}" #Evaluated: 1.618033988749895

product2 = p1.multiply(p1) # Phi * Phi = Phi^2 = Phi + 1
console.log "#{p1.toString()} * #{p1.toString()} = #{product2.toString()}" # Output: P(1, 0) * P(1, 0) = P(1, 1)
console.log "Evaluated: #{product2.evaluate()}" #Evaluated: 2.618033988749895

# Subtraction
difference = p3.subtract(p1)
console.log "#{p3.toString()} - #{p1.toString()} = #{difference.toString()}" # Output: P(1, 1) - P(1, 0) = P(0, 1)
console.log "Evaluated: #{difference.evaluate()}" #Evaluated: 1

# Simplification
complex_expression = new PhiExpression(2.0000000001, 3.9999999999)
simplified_expression = complex_expression.simplify()
console.log "Before simplification: #{complex_expression.toString()}" # Before simplification: P(2.0000000001, 3.9999999999)
console.log "After simplification: #{simplified_expression.toString()}" # After simplification: P(2, 4)
