# Decodes a six-basis encoded string into either:
#   - an object for a single vertex (if no pipe "|" is present)
#   - an array of vertex objects (if one or more pipe characters are found)
#
# Each vertex object contains:
#   - sixVector: a flat array of 6 coefficients [a1, b1, a2, b2, a3, b3]
#   - cartesian: the computed Cartesian coordinate [x, y, z]
#
# For each vertex, the contributions from the three pairs are:
#   Pair A (indices 0 & 1): [ (a+b)*phi,  0,  (a-b) ]
#   Pair B (indices 2 & 3): [  0,  (a-b), (a+b)*phi ]
#   Pair C (indices 4 & 5): [ (a-b), (a+b)*phi,  0 ]
#
# @param encodedString - The six-basis encoded string.
# @returns An object (for a single vertex) or an array of objects (for multiple vertices).
decodeTriangle = (encodedString) ->
  phi = (1 + Math.sqrt(5)) / 2

  # Determine if the string represents a single vertex or multiple vertices.
  if encodedString.indexOf('|') is -1
    vertexStrings = [ encodedString.trim() ]
  else
    vertexStrings = encodedString.split('|').map (s) -> s.trim()

  results = vertexStrings.map (vertexStr, idx) ->
    # Extract all signed numbers using a regular expression.
    matches = vertexStr.match /-?\d+/g
    unless matches? and matches.length is 6
      throw new Error "Vertex #{idx + 1} does not contain exactly 6 numbers."
    
    # Convert extracted strings to numbers to form a flat sixVector.
    sixVector = matches.map (n) -> Number(n)
    
    # Compute the contributions for each pair.
    # Pair A: indices 0 and 1.
    a1 = sixVector[0]
    b1 = sixVector[1]
    contributionA = [ (a1 + b1) * phi, 0, (a1 - b1) ]
    
    # Pair B: indices 2 and 3.
    a2 = sixVector[2]
    b2 = sixVector[3]
    contributionB = [ 0, (a2 - b2), (a2 + b2) * phi ]
    
    # Pair C: indices 4 and 5.
    a3 = sixVector[4]
    b3 = sixVector[5]
    contributionC = [ (a3 - b3), (a3 + b3) * phi, 0 ]
    
    # Sum the contributions to get the Cartesian coordinates.
    cartesian = [
      contributionA[0] + contributionB[0] + contributionC[0],
      contributionA[1] + contributionB[1] + contributionC[1],
      contributionA[2] + contributionB[2] + contributionC[2]
    ]
    
    { sixVector, cartesian }
  
  # Return a single object if only one vertex was provided.
  if results.length is 1 then results[0] else results

# Example usage:
# For a triangle (multiple vertices):
encodedTriangle = "-1-4,1,4-4-1 | -4-1-4-1-4-1 | 1-1,1,2-1-1"
triangleResult = decodeTriangle(encodedTriangle)
console.log "Triangle Result:", JSON.stringify(triangleResult, null, 2)

# For a single point (no pipe character):
encodedPoint = "-1-4,1,4-4-1"
pointResult = decodeTriangle(encodedPoint)
console.log "Single Point Result:", JSON.stringify(pointResult, null, 2)
