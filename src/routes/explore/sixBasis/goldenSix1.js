// Define the golden ratio and the six basis vectors.
const phi = (1 + Math.sqrt(5)) / 2;
const sixBases = [
  [phi,  0,  1],
  [phi,  0, -1],
  [0,    1,  phi],
  [0,   -1,  phi],
  [1,   phi,  0],
  [-1,  phi,  0]
];

/**
 * Converts a 6-dimensional integer vector (six–basis representation)
 * into standard Cartesian coordinates.
 *
 * Using the new basis, a six–vector [a, b, c, d, e, f] is mapped by:
 *   x = φ*(a + b) + (e - f)
 *   y = (c - d) + φ*(e + f)
 *   z = (a - b) + φ*(c + d)
 *
 * @param {number[]} six - Array [a, b, c, d, e, f] of integers.
 * @returns {Object} An object with properties x, y, z.
 */
function sixToCartesian(six) {
  const [a, b, c, d, e, f] = six;
  let x = phi * (a + b) + (e - f);
  let y = (c - d) + phi * (e + f);
  let z = (a - b) + phi * (c + d);
  return { x, y, z };
}

/**
 * Converts Cartesian coordinates (assumed to lie exactly on the φ–lattice)
 * back into the 6–basis integer representation.
 *
 * Each Cartesian coordinate is assumed to be exactly expressible in the form:
 *    value = (integer part) + φ × (phi part)
 *
 * For example, represent x as: { int: X0, phi: X1 } so that x = X0 + φ·X1.
 *
 * @param {Object} cartesian - An object with properties x, y, z.
 *   Each property is an object with two integer fields: { int, phi }.
 * @returns {number[]} An array [a, b, c, d, e, f] of six–basis integers.
 */
function cartesianToSix(cartesian) {
  const { x, y, z } = cartesian;
  // Decompose into integer and φ–parts.
  let X0 = x.int, X1 = x.phi;
  let Y0 = y.int, Y1 = y.phi;
  let Z0 = z.int, Z1 = z.phi;
  
  let a = (X1 + Z0) / 2;
  let b = (X1 - Z0) / 2;
  let c = (Y0 + Z1) / 2;
  let d = (Z1 - Y0) / 2;
  let e = (X0 + Y1) / 2;
  let f = (Y1 - X0) / 2;
  
  // Ensure that all computed components are integers.
  const components = [a, b, c, d, e, f];
  if (!components.every(num => Number.isInteger(num))) {
    throw new Error("The provided Cartesian coordinates are not on the φ–lattice.");
  }
  
  return components;
}

// ----- Example usage of conversion functions -----
// For a given six–vector coordinate:
let sixCoord = [1, -1, 1, -1, 1, -1];  // for example, one vertex from a dodecahedron
let cartesian = sixToCartesian(sixCoord);
console.log("Cartesian coordinates:", cartesian);
