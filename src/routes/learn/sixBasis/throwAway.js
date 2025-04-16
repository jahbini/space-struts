import numpy as np

# Define your six basis vectors (as you provided)
phi = (1 + np.sqrt(5)) / 2
sixBases = np.array([
    [phi, 0, 1],
    [phi, 0, -1],
    [0, 1, phi],
    [0, -1, phi],
    [1, phi, 0],
    [-1, phi, 0]
])

def six_vector_to_cartesian(v):
  """Converts a 6-vector to Cartesian coordinates."""
  return np.sum(v[:, None] * sixBases, axis=0) #More efficient

def generate_lattice_points(max_coeff=5):
  """Generates a set of lattice points within a given coefficient range."""
  points = []
  vectors = []
  for a in range(-max_coeff, max_coeff + 1):
    for b in range(-max_coeff, max_coeff + 1):
      for c in range(-max_coeff, max_coeff + 1):
        for d in range(-max_coeff, max_coeff + 1):
          for e in range(-max_coeff, max_coeff + 1):
            for f in range(-max_coeff, max_coeff + 1):
              v = np.array([a, b, c, d, e, f])
              point = six_vector_to_cartesian(v)
              points.append(point)
              vectors.append(v)
  return np.array(points), np.array(vectors)

def accept_reject_6_vector(v, lattice_points, lattice_vectors, threshold=0.1):
  """Accepts or rejects a 6-vector based on proximity to lattice points."""
  point = six_vector_to_cartesian(v)
  distances = np.linalg.norm(lattice_points - point, axis=1)
  min_distance = np.min(distances)
  closest_index = np.argmin(distances)

  if min_distance < threshold:
    #Accept
    return True, lattice_vectors[closest_index] #Return closest vector
  else:
    #Reject
    return False, None

# Example Usage
lattice_points, lattice_vectors = generate_lattice_points(max_coeff=3) #Generate a relatively small lattice for testing

test_vector = np.array([1, 2, -1, 0, 1, -2])
accepted, closest_vector = accept_reject_6_vector(test_vector, lattice_points, lattice_vectors, threshold=0.1)

if accepted:
  print(f"Vector {test_vector} accepted. Closest lattice vector: {closest_vector}")
else:
  print(f"Vector {test_vector} rejected.")

test_vector_2 = np.array([1.5, 2.3, -1.1, 0.4, 0.9, -2.2]) #Non integer coefficients
accepted, closest_vector = accept_reject_6_vector(test_vector_2, lattice_points, lattice_vectors, threshold=0.1)

if accepted:
  print(f"Vector {test_vector_2} accepted. Closest lattice vector: {closest_vector}")
else:
  print(f"Vector {test_vector_2} rejected.")
