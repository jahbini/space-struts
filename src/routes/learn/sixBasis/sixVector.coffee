# Define your six basis vectors (as you provided)
phi = (1 + Math.sqrt(5)) / 2
sixBases = [
  [phi, 0, 1],
  [phi, 0, -1],
  [0, 1, phi],
  [0, -1, phi],
  [1, phi, 0],
  [-1, phi, 0]
]

six_vector_to_cartesian = (v) ->
  # Converts a 6-vector to Cartesian coordinates.
  result = [0, 0, 0]
  for i in [0...6]
    for j in [0...3]
      result[j] += v[i] * sixBases[i][j]
  return result

generate_lattice_points = (max_coeff = 5) ->
  # Generates a set of lattice points within a given coefficient range.
  points = []
  vectors = []
  for a in [-max_coeff..max_coeff]
    for b in [-max_coeff..max_coeff]
      for c in [-max_coeff..max_coeff]
        for d in [-max_coeff..max_coeff]
          for e in [-max_coeff..max_coeff]
            for f in [-max_coeff..max_coeff]
              v = [a, b, c, d, e, f]
              point = six_vector_to_cartesian(v)
              points.push(point)
              vectors.push(v)
  return [ points, vectors ]

accept_reject_6_vector = (v, lattice_points, lattice_vectors, threshold = 0.1) ->
  # Accepts or rejects a 6-vector based on proximity to lattice points.
  point = six_vector_to_cartesian(v)
  min_distance = Infinity
  closest_vector = null
  
  for i in [0...lattice_points.length]
    distance = Math.sqrt((point[0] - lattice_points[i][0])**2 + (point[1] - lattice_points[i][1])**2 + (point[2] - lattice_points[i][2])**2)
    if distance < min_distance
      min_distance = distance
      closest_vector = lattice_vectors[i]

  if min_distance < threshold
    # Accept
    return  [true ,closest_vector]
  else
    # Reject
    return  [false, null]

# Example Usage
[lattice_points, lattice_vectors] = generate_lattice_points(max_coeff = 3) # Generate a relatively small lattice for testing

test_vector = [1, 2, -1, 0, 1, -2]
[accepted, closest_vector] = accept_reject_6_vector(test_vector, lattice_points, lattice_vectors, threshold = 0.1)

if accepted
  console.log("Vector #{test_vector} accepted. Closest lattice vector: #{closest_vector}")
else
  console.log("Vector #{test_vector} rejected.")

test_vector_2 = [1.5, 2.3, -1.1, 0.4, 0.9, -2.2] # Non integer coefficients
[accepted, closest_vector] = accept_reject_6_vector(test_vector_2, lattice_points, lattice_vectors, threshold = 0.1)

if accepted
  console.log("Vector #{test_vector_2} accepted. Closest lattice vector: #{closest_vector}")
else
  console.log("Vector #{test_vector_2} rejected.")
