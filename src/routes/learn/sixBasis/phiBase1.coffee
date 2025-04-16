# Global definition of φ (only used symbolically for our constants)
phi = (1 + Math.sqrt(5)) / 2

# PhiBase represents a number in the form: value = p·φ + x, with p and x integers.
class PhiBase
  constructor: (@p, @x) ->
  
  # Multiply two PhiBase numbers.
  # Let a = p₁·φ + x₁ and b = p₂·φ + x₂.
  # Then a * b = p₁*p₂*φ² + (p₁*x₂ + p₂*x₁)φ + x₁*x₂.
  # Since φ² = φ + 1, we have:
  #   a*b = (x₁*x₂ + p₁*p₂) + (p₁*x₂ + p₂*x₁ + p₁*p₂)·φ.
  mul: (other) ->
    newP = this.p * other.x + this.x * other.p + this.p * other.p
    newX = this.x * other.x + this.p * other.p
    new PhiBase(newP, newX)
  
  # Multiply this PhiBase number by an ordinary integer.
  mulInt: (n) ->
    new PhiBase(this.p * n, this.x * n)
  
  toString: ->
    # Display in the form: p(p,x)
    "p(" + @p + "," + @x + ")"

# Define fixed PhiBase constants (all exact, integer‐only representations)
phiPhi    = new PhiBase(1, 0)   # Represents φ exactly.
one       = new PhiBase(0, 1)   # Represents 1 exactly.
zero      = new PhiBase(0, 0)
negOne    = new PhiBase(0, -1)

# Define the six fixed normals in PhiBase notation.
# Each normal is a triple of PhiBase numbers.
normalsPhiBase = [
  [ phiPhi,    zero,   one ],    # n₀ = [ φ,  0,  1 ]
  [ phiPhi,    zero,   negOne ], # n₁ = [ φ,  0, -1 ]
  [ zero,      one,    phiPhi ],  # n₂ = [ 0,  1,  φ ]
  [ zero,      negOne, phiPhi ],  # n₃ = [ 0, -1,  φ ]
  [ one,       phiPhi, zero ],    # n₄ = [ 1,  φ,  0 ]
  [ negOne,    phiPhi, zero ]     # n₅ = [ -1, φ,  0 ]
]

# Next, we define a conversion routine.
# Input: a 6-vector given as an array of 6 integers (the seed values).
# Output: an array of 6 arrays.
# For each index i (from 0 to 5), the output is a triple of PhiBase numbers,
# computed as seed[i] multiplied (via PhiBase multiplication) by each component of normalsPhiBase[i].
convert6VectorToPhiBaseStructure = (seedVec) ->
  if seedVec.length isnt 6 then throw new Error "Input must be a 6-vector."
  result = []
  for i in [0...6]
    # Convert the seed (an integer) to a PhiBase number.
    seedPhi = new PhiBase(0, seedVec[i])  # represents seedVec[i] exactly.
    # Multiply seedPhi by each component of the i-th normal.
    triple = []
    for j in [0...3]
      triple.push( seedPhi.mul( normalsPhiBase[i][j] ) )
      # Note: normalsPhiBase[i][j] gives the j-th component of normal i.
    result.push(triple)
  result

# --- Example Usage ---

# Example: Let’s assume an input 6-vector of seeds.
# (For illustration only. You mentioned [1,0,1,0,1,0] is not legal—but here we show an example.)
seedVector = [3, 0, 2, 0, 5, 0]  
# Interpretation: For the first coordinate, a seed of 3 means 3*(generator for n₀).
# In our scheme, the generator for n₀ is determined by its normal [φ,0,1].
# Since our fixed notion is that the first basis should yield a PhiBase result of p(3,3),
# the conversion will compute: triple₀ = [ 3 * φ, 3 * 0, 3 * 1 ] in PhiBase arithmetic.
convertedStructure = convert6VectorToPhiBaseStructure(seedVector)

console.log "Converted 6-vector into PhiBase structure (each basis yields a triple):"
for triple in convertedStructure
  # Print the triple in PhiBase notation.
  console.log triple.map((val) -> val.toString()).join(", ")

# The output is an array with 6 entries. For example, for index 0:
#   Triple0 = [ seed_0 * (φ), seed_0 * (0), seed_0 * (1) ] 
#           = [ p(3,0) *? , p(0,0), p(0,3) ]
# In our PhiBase arithmetic, multiplication by an integer is exact.
# Thus, a seed of 3 becomes 3*(φ+1) only if the generator is defined as such.
#
# In this implementation, since each coordinate is computed by exactly
# multiplying the seed (as PhiBase) by the corresponding fixed normal component,
# the resulting output is entirely symbolic (with integer p and x values).
