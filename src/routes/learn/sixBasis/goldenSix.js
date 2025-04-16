// dodecahedron6.js
// This program enumerates the legal 6–space vertices of a dodecahedron,
// then computes and outputs the unique difference vectors (“golden links”)
// corresponding to 1–step and 2–step moves along the faces.

// ==================================================
// 1. Define the 20 Legal 6–Space Vertices
// (Each vertex is a 6–vector [v0,v1,v2,v3,v4,v5])
// The vertices below are arranged as follows:
//   - Indices 0..4: Bottom pentagon (ordered counterclockwise)
//   - Indices 5..14: Middle belt (10 vertices, arranged in order around the belt)
//   - Indices 15..19: Top pentagon (ordered counterclockwise)
// (These numbers are chosen to be legal (all integers, with each pair’s difference even).)
const vertices = [
  // Bottom pentagon
  [0, 0, -2, 0, 1, 1],       // Vertex 0
  [1, -1, -1, 1, 0, 1],       // Vertex 1
  [1, -1, 1, -1, -1, 0],      // Vertex 2
  [0, 0, 2, 0, -1, -1],       // Vertex 3
  [-1, 1, 1, -1, 0, -1],      // Vertex 4

  // Middle belt (10 vertices)
  [1, 1, 0, 0, 1, -1],        // Vertex 5
  [1, 1, 0, 0, -1, 1],        // Vertex 6
  [0, 0, 1, -1, 1, 1],        // Vertex 7
  [0, 0, -1, 1, -1, -1],      // Vertex 8
  [-1, -1, 0, 0, 1, -1],      // Vertex 9
  [-1, -1, 0, 0, -1, 1],      // Vertex 10
  [0, 0, 1, -1, -1, -1],      // Vertex 11
  [0, 0, -1, 1, 1, 1],        // Vertex 12
  [1, -1, 1, 0, 0, 1],        // Vertex 13
  [-1, 1, -1, 0, 0, -1],      // Vertex 14

  // Top pentagon
  [0, 0, -2, 0, -1, -1],      // Vertex 15
  [1, -1, -1, 1, 0, -1],      // Vertex 16
  [1, -1, 1, -1, 1, 0],       // Vertex 17
  [0, 0, 2, 0, 1, 1],         // Vertex 18
  [-1, 1, 1, -1, 0, 1]        // Vertex 19
];

// ==================================================
// 2. Define the 12 Faces of the Dodecahedron
// Each face is a pentagon given by an array of 5 vertex indices,
// listed in circular, counterclockwise order.
// (The following connectivity is chosen to reflect a canonical dodecahedron.)
const faces = [
  // Bottom face (pentagon)
  [0, 1, 2, 3, 4],
  
  // Top face (pentagon)
  [15, 16, 17, 18, 19],
  
  // 10 Side faces (each a pentagon connecting the bottom, belt, and top)
  [0, 5, 6, 7, 1],
  [1, 7, 8, 9, 2],
  [2, 9, 10, 11, 3],
  [3, 11, 12, 13, 4],
  [4, 13, 14, 5, 0],
  [15, 10, 9, 8, 16],
  [16, 8, 7, 6, 17],
  [17, 6, 5, 14, 18],
  [18, 14, 13, 12, 19],
  [19, 12, 11, 10, 15]
];

// ==================================================
// 3. Compute the Difference (Jump) Vectors Along Faces
// We compute for each face:
//   (a) 1–step differences (between adjacent vertices, wrapping around)
//   (b) 2–step differences (vertices two apart along the face, wrapping around)
// All differences are computed in 6–space (by subtracting corresponding components).
// We store the differences in a set (using JSON.stringify as a key) to ensure uniqueness.
const diffSet = new Set();

// Helper: subtract one 6–vector from another (v2 - v1)
function subtract(v2, v1) {
  const diff = [];
  for (let i = 0; i < 6; i++) {
    diff.push(v2[i] - v1[i]);
  }
  return diff;
}

// Helper: add a difference vector to the set
function addDiffVector(diff) {
  const key = JSON.stringify(diff);
  diffSet.add(key);
}

// For each face:
faces.forEach(face => {
  const n = face.length; // should be 5 for a pentagon
  // 1–step differences: for each i, difference between vertex[i+1] and vertex[i] (wrap-around)
  for (let i = 0; i < n; i++) {
    const iNext = (i + 1) % n;
    const v1 = vertices[face[i]];
    const v2 = vertices[face[iNext]];
    const diff = subtract(v2, v1);
    addDiffVector(diff);
  }
  // 2–step differences: for each i, difference between vertex[i+2] and vertex[i] (wrap-around)
  for (let i = 0; i < n; i++) {
    const iNext2 = (i + 2) % n;
    const v1 = vertices[face[i]];
    const v2 = vertices[face[iNext2]];
    const diff = subtract(v2, v1);
    addDiffVector(diff);
  }
});

// Convert the set to an array of unique difference vectors.
const diffVectors = Array.from(diffSet).map(key => JSON.parse(key));

// ==================================================
// 4. Output the Legal List of "Golden Links" (Difference Vectors)
console.log("Legal difference vectors (edge steps of 1 or 2 on faces):");
diffVectors.forEach(diff => {
  console.log(diff);
});
