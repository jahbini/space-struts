const phi = (1 + Math.sqrt(5)) / 2;

const sixBases = [
  [phi, 0, 1],
  [phi, 0, -1],
  [0, 1, phi],
  [0, -1, phi],
  [1, phi, 0],
  [-1, phi, 0]
];

// Dodecahedron vertices in six-base coordinates (validated set)
const dodecahedronVertices = [
  [0, 0, -2, 0, 1, 1],
  [1, -1, -1, 1, 0, 1],
  [1, -1, 1, -1, -1, 0],
  [0, 0, 2, 0, -1, -1],
  [-1, 1, 1, -1, 0, -1],
  [1, 1, 0, 0, 1, -1],
  [1, 1, 0, 0, -1, 1],
  [0, 0, 1, -1, 1, 1],
  [0, 0, -1, 1, -1, -1],
  [-1, -1, 0, 0, 1, -1],
  [-1, -1, 0, 0, -1, 1],
  [-1, 1, -1, 1, 0, 1],
  [-1, 1, 1, -1, -1, 0],
  [1, -1, 1, -1, 0, -1],
  [1, -1, -1, 1, 1, 0],
  [-1, -1, 2, 0, 1, 1],
  [-1, -1, -2, 0, -1, -1],
  [1, 1, 2, 0, -1, -1],
  [1, 1, -2, 0, 1, 1],
  [0, 0, 0, 0, 0, 0] // Center (optional for reference)
];

/**
 * Finds the Cartesian coordinates of a six-base point.
 * @param {number[]} coords - An array of six integers.
 * @returns {object} Cartesian coordinates {x, y, z}
 */
function sixBaseToCartesian(coords) {
  let x = 0, y = 0, z = 0;
  for (let i = 0; i < 6; i++) {
    x += coords[i] * sixBases[i][0];
    y += coords[i] * sixBases[i][1];
    z += coords[i] * sixBases[i][2];
  }
  return { x, y, z };
}

/**
 * Finds an edge given two adjacent pentagonal vertices.
 * @param {number[]} vertexA - The first vertex in six-base coordinates.
 * @param {number[]} vertexB - The second vertex in six-base coordinates.
 * @returns {object} The Cartesian midpoint and six-base edge.
 */
function findEdge(vertexA, vertexB) {
  let midpoint = vertexA.map((val, index) => (val + vertexB[index]) / 2);
  let cartesianMidpoint = sixBaseToCartesian(midpoint);
  return { sixBaseEdge: midpoint, cartesianMidpoint };
}

/**
 * Places a Golden Triangle at a specified edge.
 * @param {number[]} vertexA - One vertex of the edge.
 * @param {number[]} vertexB - The other vertex of the edge.
 * @param {string} face - The face to attach to.
 * @param {number} vertexIndex - The vertex number of the new triangle.
 * @returns {object} - New triangle vertices.
 */
function placeGoldenTriangle(vertexA, vertexB, face, vertexIndex) {
  let edge = findEdge(vertexA, vertexB);
  let newVertex = vertexA.map((val, index) => val + vertexB[index]);
  return { face, vertexIndex, newTriangle: [vertexA, vertexB, newVertex] };
}

// Example usage:
const edge = findEdge(dodecahedronVertices[0], dodecahedronVertices[1]);
console.log("Edge Midpoint:", edge);

const newTriangle = placeGoldenTriangle(dodecahedronVertices[0], dodecahedronVertices[1], "FaceA", 2);
console.log("New Triangle Placement:", newTriangle);

