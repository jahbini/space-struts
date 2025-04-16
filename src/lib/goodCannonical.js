import * as THREE from "three";
/**
 * generateCanonicalData.js
 *
 * This script generates canonical data based on a Fibonacci construction
 * with Golden Triangles and Golden Gnomons.
 *
 * The valid points are now generated using the sixDotter logic.
 */

const phi = (1 + Math.sqrt(5)) / 2;

// Six basis vectors as defined in the patent.
const sixBases = [
  [phi, 0, 1],
  [phi, 0, -1],
  [0, 1, phi],
  [0, -1, phi],
  [1, phi, 0],
  [-1, phi, 0]
];

/**
 * Solves a 3x3 system A * x = b.
 * @param {number[][]} A - A 3x3 coefficient matrix.
 * @param {number[]} b - Right-hand side vector.
 * @returns {number[]|null} The solution vector x, or null if the system is singular.
 */
function solve3x3(A, b) {
  const [a11, a12, a13] = A[0],
        [a21, a22, a23] = A[1],
        [a31, a32, a33] = A[2];

  const det = a11 * (a22 * a33 - a23 * a32) -
              a12 * (a21 * a33 - a23 * a31) +
              a13 * (a21 * a32 - a22 * a31);

  if (Math.abs(det) < 1e-6) return null;
  const invDet = 1 / det;
  const inv = [
    [
      (a22 * a33 - a23 * a32) * invDet,
      (a13 * a32 - a12 * a33) * invDet,
      (a12 * a23 - a13 * a22) * invDet
    ],
    [
      (a23 * a31 - a21 * a33) * invDet,
      (a11 * a33 - a13 * a31) * invDet,
      (a13 * a21 - a11 * a23) * invDet
    ],
    [
      (a21 * a32 - a22 * a31) * invDet,
      (a12 * a31 - a11 * a32) * invDet,
      (a11 * a22 - a12 * a21) * invDet
    ]
  ];

  return [
    inv[0][0] * b[0] + inv[0][1] * b[1] + inv[0][2] * b[2],
    inv[1][0] * b[0] + inv[1][1] * b[1] + inv[1][2] * b[2],
    inv[2][0] * b[0] + inv[2][1] * b[1] + inv[2][2] * b[2]
  ];
}

/**
 * Completes a partially specified 6-vector by solving for the unique intersection point.
 * Missing entries (denoted by null) are filled using: round((P · b_i) / |b_i|²).
 * @param {Array<number|null>} vPartial - A partially specified 6-vector.
 * @returns {Object} An object with the complete vector v and intersection point P.
 */
function completePartialVector(vPartial) {
  const indices = [];
  for (let i = 0; i < 6; i++) {
    if (vPartial[i] !== null) indices.push(i);
  }
  if (indices.length < 3) throw new Error("At least 3 values required.");

  const A = [], b = [];
  for (let k = 0; k < 3; k++) {
    const i = indices[k];
    const bi = sixBases[i];
    const norm2 = bi[0] ** 2 + bi[1] ** 2 + bi[2] ** 2;
    A.push(bi);
    b.push(vPartial[i] * norm2);
  }
  const P = solve3x3(A, b);
  if (P === null) throw new Error("No unique intersection.");

  const vComplete = vPartial.slice();
  for (let i = 0; i < 6; i++) {
    if (vComplete[i] === null) {
      const bi = sixBases[i];
      const norm2 = bi[0] ** 2 + bi[1] ** 2 + bi[2] ** 2;
      const dotP = P[0] * bi[0] + P[1] * bi[1] + P[2] * bi[2];
      vComplete[i] = Math.round(dotP / norm2);
    }
  }
  return { v: vComplete, P };
}

/**
 * Encodes a 6-dimensional vector into a unique string representation.
 * The encoding outputs the first number and then, for each subsequent value,
 * prepends a comma only if that value is non-negative.
 *
 * For example, the vector [-2, -2, 0, -1, -1, 2] is encoded as:
 *   "-2-2,0-1-1,2"
 *
 * This encoding is reversible.
 *
 * @param {number[]} v - A 6-dimensional vector.
 * @returns {string} The encoded string.
 */
function encodeSixVector(v) {
  if (v.length !== 6) throw new Error("Expected 6 values");
  let encoding = v[0].toString();
  for (let i = 1; i < 6; i++) {
    if (v[i] >= 0) encoding += ',';
    encoding += v[i].toString();
  }
  return encoding;
}

/**
 * Decodes an encoded six-vector string back into an array of 6 integers.
 *
 * @param {string} str - The encoded string.
 * @returns {number[]} The decoded 6-dimensional vector.
 */
function decodeSixVector(str) {
  const result = [];
  let current = "";
  for (let i = 0; i < str.length; i++) {
    const ch = str[i];
    if (ch === ',') {
      if (current.length > 0) {
        result.push(parseInt(current, 10));
        current = "";
      }
    } else {
      if (ch === '-' && current !== "" && current[current.length - 1] !== ',') {
        result.push(parseInt(current, 10));
        current = "-";
      } else {
        current += ch;
      }
    }
  }
  if (current.length > 0) result.push(parseInt(current, 10));
  if (result.length !== 6) throw new Error("Decoded vector does not have 6 elements");
  return result;
}

/**
 * Encodes a triangle by encoding each of its vertices (6-dimensional vectors),
 * then sorting the encoded strings lexicographically and joining them with a pipe delimiter.
 *
 * @param {Array<number[]>} triangle - An array of three 6-dimensional vectors.
 * @returns {string} The unique triangle ID.
 */
function encodeTriangle(triangle) {
  const encodedVertices = triangle.map(encodeSixVector);
  encodedVertices.sort(); // Lexicographical sort for uniqueness.
  return encodedVertices.join('|');
}

/* ================================
   SixDotter Generation Logic Start
   ================================

Below is the generation logic as provided in the sixDotter text.
This code generates the valid points exactly as defined by sixDotter.
It iterates over the three designated pairs ([0,1], [2,3], [4,5])
and assigns ±1 to one index in each pair, then completes the vector.
No range adjustments or extraneous parameters are introduced.
*/

function generateValidPoints() {
  const candidates = [];
  const vals = [1, -1];
  // For each of the three pairs [0,1], [2,3], [4,5] choose one index and assign ±1.
  for (const i0 of [0, 1]) {
    for (const i1 of [2, 3]) {
      for (const i2 of [4, 5]) {
        for (const s0 of vals) {
          for (const s1 of vals) {
            for (const s2 of vals) {
              const candidate = [null, null, null, null, null, null];
              candidate[i0] = s0;
              candidate[i1] = s1;
              candidate[i2] = s2;
              try {
                candidates.push(completePartialVector(candidate));
              } catch (e) {
                // If completion fails, skip this candidate.
              }
            }
          }
        }
      }
    }
  }
  // Deduplicate candidates by their encoded six-vector.
  const unique = new Map();
  candidates.forEach(obj => {
    unique.set(encodeSixVector(obj.v), obj);
  });
  return Array.from(unique.values());
}

/* ================================
   SixDotter Generation Logic End
   ================================ */

/**
 * Converts a six-vector v = [a, b, c, d, e, f] into Cartesian coordinates.
 *
 * @param {number[]} v - The six-vector.
 * @returns {number[]} Cartesian coordinates [x, y, z].
 */
function sixToCartesian(v) {
  const [a, b, c, d, e, f] = v;
  return [
    phi * (a + b) + (e - f),
    (c - d) + phi * (e + f),
    (a - b) + phi * (c + d)
  ];
}

/**
 * Computes golden triangles from canonical points.
 * For each triple of points (converted to Cartesian coordinates), checks if the triangle
 * is isosceles with a long-to-short edge ratio approximating φ (or its reciprocal) within tolerance.
 *
 * Each point is keyed by its encoded six-vector.
 *
 * @param {Array} points - Array of objects with property v (the six-vector) and optionally P.
 * @param {number} tolRatio - Tolerance ratio (default is 0.05).
 * @returns {Array} An array of unique golden triangles, each represented as an array of encoded vertex IDs.
 */
function computeGoldenTriangles(points, tolRatio = 0.05) {
  const pts = points.map(obj => {
    const key = encodeSixVector(obj.v);
    const P = obj.P ? obj.P : sixToCartesian(obj.v);
    return { key, P };
  });

  const triangles = [];
  const n = pts.length;
  for (let i = 0; i < n; i++) {
    for (let j = i + 1; j < n; j++) {
      for (let k = j + 1; k < n; k++) {
        const P1 = new THREE.Vector3(...pts[i].P);
        const P2 = new THREE.Vector3(...pts[j].P);
        const P3 = new THREE.Vector3(...pts[k].P);
        const d12 = P1.distanceTo(P2);
        const d23 = P2.distanceTo(P3);
        const d31 = P3.distanceTo(P1);
        let shortEdge, longEdge;

        if (Math.abs(d12 - d31) < 0.1 * d12) {
          shortEdge = d12;
          longEdge = d23;
        } else if (Math.abs(d12 - d23) < 0.1 * d12) {
          shortEdge = d12;
          longEdge = d31;
        } else if (Math.abs(d23 - d31) < 0.1 * d23) {
          shortEdge = d23;
          longEdge = d12;
        } else continue;

        const ratio = longEdge / shortEdge;
        if (
          Math.abs(ratio - phi) / phi < tolRatio ||
          Math.abs(1 / ratio - phi) / phi < tolRatio
        ) {
          const tri = [pts[i].key, pts[j].key, pts[k].key];
          tri.sort();
          triangles.push(tri);
        }
      }
    }
  }

  const unique = new Map();
  triangles.forEach(tri => {
    unique.set(tri.join('|'), tri);
  });
  return Array.from(unique.values());
}

/**
 * Main execution function.
 */
function main() {
  // Generate valid points using sixDotter's generation logic.
  const validPoints = generateValidPoints();

  // Prepare points object using encoded six-vectors as keys.
  const pointsObj = {};
  validPoints.forEach(obj => {
    pointsObj[encodeSixVector(obj.v)] = { obj };
  });

  // Compute golden triangles from all valid points.
  const triangles = computeGoldenTriangles(validPoints);
  const trianglesObj = {};
  triangles.forEach(tri => {
    trianglesObj[tri.join('|')] = { tri };
  });

  const data = { points: pointsObj, triangles: trianglesObj };
  process.stdout.write(JSON.stringify(data, null, 2) + "\n");
}
console.log( "vector???",completePartialVector([1,0,1,0,1,0]) );

// main();
