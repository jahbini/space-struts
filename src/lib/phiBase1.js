// generateCanonicalData.js

// -- PhiBase arithmetic: Represent numbers exactly as x + p·φ --

const phi = (1 + Math.sqrt(5)) / 2;

class PhiBase {
  constructor(p, x) {
    this.p = p; // coefficient for φ (an integer)
    this.x = x; // rational (integer) part
  }
  // Add: (x1 + p1·φ) + (x2 + p2·φ)
  add(other) {
    return new PhiBase(this.p + other.p, this.x + other.x);
  }
  // Subtract.
  sub(other) {
    return new PhiBase(this.p - other.p, this.x - other.x);
  }
  // Multiply:
  // (x1 + p1·φ) * (x2 + p2·φ) = 
  //   x1*x2 + (x1*p2 + x2*p1)*φ + p1*p2·φ²,
  // and φ² = φ + 1, so:
  // = (x1*x2 + p1*p2) + (x1*p2 + x2*p1 + p1*p2)·φ.
  mul(other) {
    const newX = this.x * other.x + this.p * other.p;
    const newP = this.x * other.p + this.p * other.x + this.p * other.p;
    return new PhiBase(newP, newX);
  }
  // Multiply by an integer.
  mulInt(n) {
    return new PhiBase(this.p * n, this.x * n);
  }
  // Convert to a regular floating-point number.
  toNumber() {
    return this.x + this.p * phi;
  }
  // toString: return "p,x"
  toString() {
    return `${this.p},${this.x}`;
  }
}

// -- Fixed PhiBase constants --
const phiPhi = new PhiBase(1, 0);  // Represents φ exactly.
const one = new PhiBase(0, 1);     // Represents 1 exactly.
const negOne = new PhiBase(0, -1);
const zero = new PhiBase(0, 0);

// -- Six Basis Normals in PhiBase Notation --
// Based on the patent:
// n₀ = [φ, 0, 1]
// n₁ = [φ, 0, -1]
// n₂ = [0, 1, φ]
// n₃ = [0, -1, φ]
// n₄ = [1, φ, 0]
// n₅ = [-1, φ, 0]
const normalsPhiBase = [
  [phiPhi, zero, one],
  [phiPhi, zero, negOne],
  [zero, one, phiPhi],
  [zero, negOne, phiPhi],
  [one, phiPhi, zero],
  [negOne, phiPhi, zero]
];

// -- Solver for 3x3 Systems in PhiBase Arithmetic --
// We'll use a simple Gaussian elimination algorithm that operates on PhiBase objects.
function solve3x3Phi(A, B) {
  // Clone A and B.
  let M = A.map(row => row.map(e => new PhiBase(e.p, e.x)));
  let R = B.map(e => new PhiBase(e.p, e.x));
  const n = 3;
  for (let i = 0; i < n; i++) {
    // Find pivot (assume nonzero exists).
    let pivot = M[i][i];
    if (pivot.toNumber() === 0) {
      let swap = i + 1;
      while (swap < n && M[swap][i].toNumber() === 0) {
        swap++;
      }
      if (swap === n) return null;
      [M[i], M[swap]] = [M[swap], M[i]];
      [R[i], R[swap]] = [R[swap], R[i]];
      pivot = M[i][i];
    }
    // Divide row i by pivot.
    for (let j = i; j < n; j++) {
      M[i][j] = M[i][j].divInt(pivot.toNumber() ); // division by an integer approximation; 
      // In practice, our numbers are small and we expect pivot to be rational.
    }
    R[i] = R[i].divInt(pivot.toNumber());
    // Eliminate below.
    for (let k = i + 1; k < n; k++) {
      let factor = M[k][i];
      for (let j = i; j < n; j++) {
        M[k][j] = M[k][j].sub(factor.mul(M[i][j]));
      }
      R[k] = R[k].sub(factor.mul(R[i]));
    }
  }
  // Back substitution.
  let X = Array(n).fill(null);
  for (let i = n - 1; i >= 0; i--) {
    let sum = new PhiBase(0, 0);
    for (let j = i + 1; j < n; j++) {
      sum = sum.add(M[i][j].mul(X[j]));
    }
    X[i] = R[i].sub(sum);
  }
  return X;
}

// For our purposes, since our numbers are small, we will use division by an integer
// via a helper. (A robust implementation would need proper division in Q(φ).)
PhiBase.prototype.divInt = function(n) {
  return new PhiBase(this.p / n, this.x / n);
};

// -- Canonical Data Generation in PhiBase Arithmetic --

// Our six-vector candidate will be an array of 6 elements (each a PhiBase or null).
// We require at least 3 specified entries. We use the first 3 to solve for a 3-vector P,
// then fill in the missing entries by computing: candidate[i] = round((P · b_i) / norm²(b_i))
// where b_i is the i-th basis normal in PhiBase. For our fixed normals, norm² is fixed.
function completePartialVectorExact(vPartial) {
  let indices = [];
  for (let i = 0; i < 6; i++) {
    if (vPartial[i] != null) indices.push(i);
  }
  if (indices.length < 3) throw new Error("At least 3 values required.");
  let A = [], B = [];
  for (let k = 0; k < 3; k++) {
    const i = indices[k];
    // Convert the i-th basis normal from normalsPhiBase.
    let bi = normalsPhiBase[i]; // this is an array of 3 PhiBase numbers.
    // For our fixed normals, norm² = (φ)^2 + (0)^2 + (1)^2 = (φ+2) for n₀, similar for others.
    // We assume all normals have the same norm² = Q.
    A.push(bi);
    // B[k] = candidate value multiplied by Q (converted to PhiBase).
    B.push(new PhiBase(0, vPartial[i].toNumber() * Q));
    // Here vPartial[i] is assumed to be either one or negOne, so toNumber() returns ±1.
  }
  const P = solve3x3Phi(A, B);
  if (P === null) throw new Error("No unique intersection.");
  let vComplete = vPartial.slice();
  for (let i = 0; i < 6; i++) {
    if (vComplete[i] == null) {
      let bi = normalsPhiBase[i];
      // Compute dot product P · bi.
      let dot = new PhiBase(0, 0);
      for (let j = 0; j < 3; j++) {
        dot = dot.add(P[j].mul(bi[j]));
      }
      // Divide by Q (which is Q = φ+2, but in PhiBase let’s represent it as an integer value,  QInt = ?).
      // We expect the result to be an integer.
      // For simplicity, we convert dot.toNumber() and round.
      vComplete[i] = new PhiBase(0, Math.round(dot.toNumber() / Q));
    }
  }
  // Full consistency check could be added here.
  return { v: vComplete, P: P };
}

// Generate canonical one-step candidates.
// For each basis pair ([0,1], [2,3], [4,5]) choose one index and assign either one or negOne.
function generateOneStepCandidates() {
  let candidates = [];
  const vals = [one, negOne]; // Using our PhiBase representation for ±1.
  for (let i0 of [0, 1]) {
    for (let i1 of [2, 3]) {
      for (let i2 of [4, 5]) {
        for (let s0 of vals) {
          for (let s1 of vals) {
            for (let s2 of vals) {
              let candidate = [null, null, null, null, null, null];
              candidate[i0] = s0;
              candidate[i1] = s1;
              candidate[i2] = s2;
              try {
                candidates.push(completePartialVectorExact(candidate));
              } catch (e) { }
            }
          }
        }
      }
    }
  }
  let unique = new Map();
  candidates.forEach(obj => {
    unique.set(obj.v.map(x => x.toString()).join(','), obj);
  });
  return Array.from(unique.values());
}

// Generate canonical two-step candidates by summing pairs of one-step moves.
// We define addition for arrays elementwise.
function addPhiArrays(v1, v2) {
  return v1.map((a, i) => a.add(v2[i]));
}
function generateTwoStepCandidates(oneSteps) {
  let candidates = [];
  for (let i = 0; i < oneSteps.length; i++) {
    for (let j = i; j < oneSteps.length; j++) {
      let sum = addPhiArrays(oneSteps[i].v, oneSteps[j].v);
      try {
        candidates.push(completePartialVectorExact(sum.slice()));
      } catch (e) { }
    }
  }
  let unique = new Map();
  candidates.forEach(obj => {
    unique.set(obj.v.map(x => x.toString()).join(','), obj);
  });
  return Array.from(unique.values());
}

// Patent conversion for display: Convert a PhiBase number to a floating-point number.
function phiToNumber(a) {
  return a.x + a.p * phi;
}
// Convert a six-vector (each component a PhiBase) to Cartesian (for display only).
function sixToCartesianDisplay(v) {
  const [a, b, c, d, e, f] = v;
  return [
    phi*(phiToNumber(a)+phiToNumber(b)) + (phiToNumber(e) - phiToNumber(f)),
    (phiToNumber(c) - phiToNumber(d)) + phi*(phiToNumber(e) + phiToNumber(f)),
    (phiToNumber(a) - phiToNumber(b)) + phi*(phiToNumber(c) + phiToNumber(d))
  ];
}

// Compute average unit jump length from one-step moves (using display conversion).
function computeUnitLength(oneSteps) {
  let total = 0, count = 0;
  oneSteps.forEach(obj => {
    const P = sixToCartesianDisplay(obj.v);
    const d = Math.hypot(...P);
    total += d;
    count++;
  });
  return total / count;
}

// Compute golden triangles from the union of canonical points.
// 'points' is an array of objects: { v, key } where key is the canonical six-vector string.
// Only consider triangles with at least one edge ≈ unit jump (tolUnit)
// and no edge longer than roughly 2 jumps (tolEdge), and with long-to-short edge ratio ≈ φ.
// Each triangle is stored as a sorted array of vertex keys.
function computeGoldenTriangles(points, unitLength, tolRatio = 0.05, tolUnit = 0.1, tolEdge = 0.1) {
  let triangles = [];
  const n = points.length;
  for (let i = 0; i < n; i++) {
    for (let j = i+1; j < n; j++) {
      for (let k = j+1; k < n; k++) {
        const P1 = new THREE.Vector3(...sixToCartesianDisplay(points[i].v));
        const P2 = new THREE.Vector3(...sixToCartesianDisplay(points[j].v));
        const P3 = new THREE.Vector3(...sixToCartesianDisplay(points[k].v));
        const d12 = P1.distanceTo(P2);
        const d23 = P2.distanceTo(P3);
        const d31 = P3.distanceTo(P1);
        if (d12 > 2*(1+tolEdge)*unitLength || d23 > 2*(1+tolEdge)*unitLength || d31 > 2*(1+tolEdge)*unitLength) continue;
        if ((Math.abs(d12-unitLength)/unitLength > tolUnit) &&
            (Math.abs(d23-unitLength)/unitLength > tolUnit) &&
            (Math.abs(d31-unitLength)/unitLength > tolUnit)) continue;
        let shortEdge, longEdge;
        if (Math.abs(d12-d31) < 0.1*d12) { shortEdge = d12; longEdge = d23; }
        else if (Math.abs(d12-d23) < 0.1*d12) { shortEdge = d12; longEdge = d31; }
        else if (Math.abs(d23-d31) < 0.1*d23) { shortEdge = d23; longEdge = d12; }
        else continue;
        const ratio = longEdge/shortEdge;
        if (Math.abs(ratio-phi)/phi < tolRatio || Math.abs((1/ratio)-phi)/phi < tolRatio) {
          let tri = [points[i].key, points[j].key, points[k].key].sort();
          triangles.push(tri);
        }
      }
    }
  }
  let unique = new Map();
  triangles.forEach(tri => { unique.set(tri.join('|'), tri); });
  return Array.from(unique.values());
}

function main() {
  const oneSteps = generateOneStepCandidates();
  const twoSteps = generateTwoStepCandidates(oneSteps);
  // Merge one-step and two-step candidates into a single set.
  let allPointsMap = new Map();
  oneSteps.concat(twoSteps).forEach(obj => {
    allPointsMap.set(obj.v.map(x => x.toString()).join(','), obj);
  });
  const allPoints = Array.from(allPointsMap.values()).map(obj => ({
    v: obj.v,
    key: obj.v.map(x => x.toString()).join(',')
  }));
  const unitLength = computeUnitLength(oneSteps);
  const triangles = computeGoldenTriangles(allPoints, unitLength);
  
  // Build final output objects (omit Cartesian coordinates).
  let pointsObj = {};
  allPoints.forEach(obj => { pointsObj[obj.key] = { v: obj.v.map(x => x.toString()) }; });
  let trianglesObj = {};
  triangles.forEach(tri => { trianglesObj[tri.join('|')] = tri; });
  const data = { points: pointsObj, triangles: trianglesObj };
  
  // Output pretty-printed JSON.
  console.log(JSON.stringify(data, null, 2));
}

main();
