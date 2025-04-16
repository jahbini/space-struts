// Define the phi (Golden Ratio)
const phi = (1 + Math.sqrt(5)) / 2;

// Basis vectors (Normals to faces of the dodecahedron)
const sixBases = [
  [phi, 0, 1],     // Basis 0
  [phi, 0, -1],    // Basis 1
  [0, 1, phi],     // Basis 2
  [0, -1, phi],    // Basis 3
  [1, phi, 0],     // Basis 4
  [-1, phi, 0]     // Basis 5
];

// Helper function to compute the cross product of two vectors
function crossProduct(v1, v2) {
  return [
    v1[1] * v2[2] - v1[2] * v2[1],
    v1[2] * v2[0] - v1[0] * v2[2],
    v1[0] * v2[1] - v1[1] * v2[0]
  ];
}

// Function to compute the intersection point of three planes
function computeIntersection(plane1, plane2, plane3) {
  // Extract the normal vectors from the planes
  const normal1 = plane1.normal;
  const normal2 = plane2.normal;
  const normal3 = plane3.normal;

  // Calculate the determinant of the matrix formed by the normal vectors
  const det = normal1[0] * (normal2[1] * normal3[2] - normal3[1] * normal2[2]) -
              normal1[1] * (normal2[0] * normal3[2] - normal3[0] * normal2[2]) +
              normal1[2] * (normal2[0] * normal3[1] - normal3[0] * normal2[1]);

  if (det === 0) {
    return null; // Planes do not intersect
  }

  // Calculate the intersection point using Cramer's rule
  const dx = plane1.d * (normal2[1] * normal3[2] - normal3[1] * normal2[2]) -
             normal1[1] * (plane2.d * normal3[2] - plane3.d * normal2[2]) +
             normal1[2] * (plane2.d * normal3[1] - plane3.d * normal2[1]);

  const dy = normal1[0] * (plane2.d * normal3[2] - plane3.d * normal2[2]) -
             plane1.d * (normal2[0] * normal3[2] - normal3[0] * normal2[2]) +
             normal1[2] * (plane2.d * normal3[0] - plane3.d * normal2[0]);

  const dz = normal1[0] * (normal2[1] * plane3.d - normal3[1] * plane2.d) -
             normal1[1] * (normal2[0] * plane3.d - normal3[0] * plane2.d) +
             plane1.d * (normal2[0] * normal3[1] - normal3[0] * normal2[1]);

  const x = dx / det;
  const y = dy / det;
  const z = dz / det;

  return [x, y, z];
}

// Function to compute six-basis vectors for dodecahedron
function computeSixBasisVectors() {
  // Define the planes (we are only using the normal vectors here)
  let plane1 = { normal: sixBases[0], d: 1 };
  let plane2 = { normal: sixBases[1], d: 1 };
  let plane3 = { normal: sixBases[2], d: 1 };

  // Step 1: Compute the intersection point
  let intersectionPoint = computeIntersection(plane1, plane2, plane3);
  console.log("Intersection Point:", intersectionPoint);

  // Step 2: Generate the remaining three vectors by forcing them through the intersection point
  let v4 = crossProduct(sixBases[0], sixBases[1]);
  let v5 = crossProduct(sixBases[1], sixBases[2]);
  let v6 = crossProduct(sixBases[2], sixBases[0]);

  return { v4, v5, v6, intersectionPoint };
}

// Example usage
let result = computeSixBasisVectors();
console.log("Six Basis Vectors:", result);
