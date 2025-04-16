// generateCanonicalData.js

const phi = (1 + Math.sqrt(5)) / 2;

// --- PhiBase Arithmetic ---
// Every number is represented as { p, x } meaning x + p·φ.

// Addition: (p1, x1) + (p2, x2) = (p1+p2, x1+x2)
function phiAdd(a, b) {
  return { p: a.p + b.p, x: a.x + b.x };
}
// Subtraction.
function phiSub(a, b) {
  return { p: a.p - b.p, x: a.x - b.x };
}
// Multiplication:
// (x1 + p1φ) * (x2 + p2φ)
// = x1*x2 + (x1*p2 + p1*x2)*φ + p1*p2*φ²,
// and φ² = φ + 1, so:
function phiMul(a, b) {
  return {
    p: a.x * b.p + a.p * b.x + a.p * b.p,
    x: a.x * b.x + a.p * b.p
  };
}
// Conjugate: For a = x + p·φ, its conjugate is x + p*(1-φ).
function phiConjugate(a) {
  return { p: -a.p, x: a.x + a.p };
}
// Norm: N(a) = a * conjugate(a). This will be an integer.
function phiNorm(a) {
  const conj = phiConjugate(a);
  const prod = phiMul(a, conj);
  return prod.x; // our product is represented as {p, x} but norm is rational.
}
// Division: a/b = a * inv(b) with inv(b)= conjugate(b) / N(b).
function phiDiv(a, b) {
  const normB = phiNorm(b);
  if (normB === 0) throw new Error("Division by zero in Phi arithmetic");
  const conjB = phiConjugate(b);
  const prod = phiMul(a, conjB);
  // We assume normB divides prod exactly.
  return { p: prod.p / normB, x: prod.x / normB };
}
// Equality test.
function phiEqual(a, b) {
  return a.p === b.p && a.x === b.x;
}

// Represent an integer as a PhiBase number.
function phiFromInt(n) {
  return { p: 0, x: n };
}
// φ itself:
const phiNum = { p: 1, x: 0 };

// --- Basis Vectors in PhiBase Representation ---
// We want to represent each coordinate exactly.
// b₁ = [φ, 0, 1] becomes: [phiNum, phiFromInt(0), phiFromInt(1)]
const b1 = [ { ...phiNum }, { p: 0, x: 0 }, { p: 0, x: 1 } ];
const b2 = [ { ...phiNum }, { p: 0, x: 0 }, { p: 0, x: -1 } ];
const b3 = [ { p: 0, x: 0 }, { p: 0, x: 1 }, { ...phiNum } ];
const b4 = [ { p: 0, x: 0 }, { p: 0, x: -1 }, { ...phiNum } ];
const b5 = [ { p: 0, x: 1 }, { ...phiNum }, { p: 0, x: 0 } ];
const b6 = [ { p: 0, x: -1 }, { ...phiNum }, { p: 0, x: 0 } ];
const basisPhi = [b1, b2, b3, b4, b5, b6];

// --- Solving 3x3 Systems in Q(φ) ---
// We implement Gaussian elimination using our PhiBase arithmetic.
function solve3x3Exact(A, B) {
  // A: 3x3 array of Phi numbers; B: length-3 array of Phi numbers.
  let M = A.map(row => row.map(e => ({ ...e })));
  let R = B.map(e => ({ ...e }));
  for (let i = 0; i < 3; i++) {
    // Pivot
    let pivot = M[i][i];
    if (pivot.p === 0 && pivot.x === 0) {
      let swap = i+1;
      while (swap < 3 && M[swap][i].p === 0 && M[swap][i].x === 0) {
        swap++;
      }
      if (swap === 3) return null;
      [M[i], M[swap]] = [M[swap], M[i]];
      [R[i], R[swap]] = [R[swap], R[i]];
      pivot = M[i][i];
    }
    // Divide row i by pivot.
    for (let j = i; j < 3; j++) {
      M[i][j] = phiDiv(M[i][j], pivot);
    }
    R[i] = phiDiv(R[i], pivot);
    // Eliminate below.
    for (let k = i+1; k < 3; k++) {
      let factor = M[k][i];
      for (let j = i; j < 3; j++) {
        M[k][j] = phiSub(M[k][j], phiMul(factor, M[i][j]));
      }
      R[k] = phiSub(R[k], phiMul(factor, R[i]));
    }
  }
  // Back substitution.
  let X = Array(3).fill(null);
  for (let i = 2; i >= 0; i--) {
    let sum = { p: 0, x: 0 };
    for (let j = i+1; j < 3; j++) {
      sum = phiAdd(sum, phiMul(M[i][j], X[j]));
    }
    X[i] = phiSub(R[i], sum);
  }
  return X;
}

// --- Completion of a Partial Six-Vector ---
// Our candidate is an array of 6 elements, each either a PhiBase number or null.
// We require that at least 3 entries are specified.
// We solve for the intersection P (a 3-vector of Phi numbers) from the first 3 specified indices:
// For each specified index i, we require: P · b_i = v[i] * norm²(b_i).
// Note: For our basis, norm²(b_i) = φ+2, which in PhiBase is represented as {p:1, x:2} (since φ+2 = 2 + 1·φ).
const Qphi = { p: 1, x: 2 };
function completePartialVectorExact(vPartial) {
  let indices = [];
  for (let i = 0; i < 6; i++) {
    if (vPartial[i] != null) indices.push(i);
  }
  if (indices.length < 3) throw new Error("At least 3 values required.");
  let A = [], B = [];
  for (let k = 0; k < 3; k++) {
    const i = indices[k];
    // Convert the i-th basis vector to PhiBase representation.
    let bi = sixBases[i].map(num => {
      if (num === phi) return { p: 1, x: 0 };
      else return { p: 0, x: num };
    });
    A.push(bi);
    // B[k] = v[i] * Qphi.
    B.push(phiMul(vPartial[i], Qphi));
  }
  const P = solve3x3Exact(A, B);
  if (P === null) throw new Error("No unique intersection.");
  let vComplete = vPartial.slice();
  for (let i = 0; i < 6; i++) {
    if (vComplete[i] == null) {
      let bi = sixBases[i].map(num => {
        if (num === phi) return { p: 1, x: 0 };
        else return { p: 0, x: num };
      });
      // Compute dot product P · b_i.
      let dot = { p: 0, x: 0 };
      for (let j = 0; j < 3; j++) {
        dot = phiAdd(dot, phiMul(P[j], bi[j]));
      }
      vComplete[i] = phiDiv(dot, Qphi);
      // We assume the result is an integer in PhiBase form.
    }
  }
  // Optional: full consistency check could be added here.
  return { v: vComplete, P: P };
}

// --- Candidate Generation ---
// One-step candidates: For each pair ([0,1], [2,3], [4,5]), choose one index and assign ±1 (as Phi numbers: {0,1} or {0,-1}).
function generateOneStepCandidates() {
  let candidates = [];
  const vals = [ { p: 0, x: 1 }, { p: 0, x: -1 } ];
  for (let i0 of [0,1]) {
    for (let i1 of [2,3]) {
      for (let i2 of [4,5]) {
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
    unique.set(obj.v.map(x => x.p + "," + x.x).join(','), obj);
  });
  return Array.from(unique.values());
}

// Two-step candidates: Sum pairs of one-step moves (using PhiBase addition) and complete.
function generateTwoStepCandidates(oneSteps) {
  let candidates = [];
  function addPhiArrays(v1, v2) {
    return v1.map((a, i) => phiAdd(a, v2[i]));
  }
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
    unique.set(obj.v.map(x => x.p + "," + x.x).join(','), obj);
  });
  return Array.from(unique.values());
}

// --- Patent Conversion for Display ---
// Convert a PhiBase number to a floating-point number: value = x + p * φ.
function phiToNumber(a) {
  return a.x + a.p * phi;
}
// Convert a six-vector (each component a Phi number) to Cartesian (for display only).
function sixToCartesianDisplay(v) {
  const [a, b, c, d, e, f] = v;
  return [
    phi * (phiToNumber(a) + phiToNumber(b)) + (phiToNumber(e) - phiToNumber(f)),
    (phiToNumber(c) - phiToNumber(d)) + phi * (phiToNumber(e) + phiToNumber(f)),
    (phiToNumber(a) - phiToNumber(b)) + phi * (phiToNumber(c) + phiToNumber(d))
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
// 'points' is an array of objects: { v, key } where key = v represented as a string.
// Only consider triangles with at least one edge ≈ unit jump (tolUnit)
// and no edge longer than roughly 2 jumps (tolEdge), and with long-to-short edge ratio ≈ φ.
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
        const ratio = longEdge / shortEdge;
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
  // Merge one-step and two-step candidates into one set.
  let allPointsMap = new Map();
  oneSteps.concat(twoSteps).forEach(obj => {
    allPointsMap.set(obj.v.map(x => x.p + "," + x.x).join(','), obj);
  });
  const allPoints = Array.from(allPointsMap.values()).map(obj => ({
    v: obj.v,
    key: obj.v.map(x => x.p + "," + x.x).join(',')
  }));
  const unitLength = computeUnitLength(oneSteps);
  const triangles = computeGoldenTriangles(allPoints, unitLength);
  
  // Build final output objects (omit Cartesian coordinates).
  let pointsObj = {};
  allPoints.forEach(obj => { pointsObj[obj.key] = { v: obj.v }; });
  let trianglesObj = {};
  triangles.forEach(tri => { trianglesObj[tri.join('|')] = tri; });
  const data = { points: pointsObj, triangles: trianglesObj };
  
  console.log(JSON.stringify(data, null, 2));
}

main();
