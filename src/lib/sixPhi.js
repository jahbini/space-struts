// PhiBaseNumber models p·phi + n using integer arithmetic
const phi = (1 + Math.sqrt(5)) / 2;
export class PhiBaseNumber {
  constructor(p = 0, n = 0) {
    this.p = p; // phi multiplier
    this.n = n; // integer offset
  }

  static fromFloat(value) {
    const p = Math.round((value - Math.round(value)) / phi);
    const n = Math.round(value - p * phi);
    return new PhiBaseNumber(p, n);
  }

  add(other) {
    return new PhiBaseNumber(this.p + other.p, this.n + other.n);
  }

  subtract(other) {
    return new PhiBaseNumber(this.p - other.p, this.n - other.n);
  }

  scale(scalar) {
    return new PhiBaseNumber(this.p * scalar, this.n * scalar);
  }

  negate() {
    return new PhiBaseNumber(-this.p, -this.n);
  }

  multiply(other) {
    const p = this.p * other.n + this.n * other.p + this.p * other.p;
    const n = this.p * other.p + this.n * other.n;
    return new PhiBaseNumber(p, n);
  }

exactDivide(other) {
  const conj = new PhiBaseNumber(-other.p, other.p + other.n);

  const numerator = this.multiply(conj);
  const denominator = other.multiply(conj); // this will be phi-free: p=0, just n

  if (denominator.p !== 0) {
    console.warn("Unexpected phi term in denominator after conjugation");
    return null;
  }

  if (denominator.n === 0) {
    console.warn("Division by zero after conjugation");
    return null;
  }

  return new PhiBaseNumber(numerator.p / denominator.n, numerator.n / denominator.n);
}
  xexactDivide(other) {
    const oP = other.p;
    const oN = other.n;
    const denom = oP * oP - 2 * oN * oN;
    if (denom === 0) {
      console.warn("Division by zero-like phi denominator");
      return null;
    }
    const numP = this.n * oP - this.p * oN - this.n * oN;
    const numN = this.p * oP - this.n * oN - this.n * oN;
    return new PhiBaseNumber(numP / denom, numN / denom);
  }

  isInteger() {
    return Number.isInteger(this.p) && Number.isInteger(this.n);
  }

  toFloat() {
    return this.p * phi + this.n;
  }

  toString() {
    const phiStr = this.p === 0 ? "" : (this.p === 1 ? "ϕ" : `${this.p}ϕ`);
    const nStr = this.n !== 0 ? (this.n > 0 && phiStr ? ` + ${this.n}` : `${this.n}`) : "";
    return (phiStr + nStr) || "0";
  }
}

export class SixPhiVector3 {
  constructor(x = new PhiBaseNumber(), y = new PhiBaseNumber(), z = new PhiBaseNumber()) {
    this.x = x;
    this.y = y;
    this.z = z;
  }

  add(other) {
    return new SixPhiVector3(
      this.x.add(other.x),
      this.y.add(other.y),
      this.z.add(other.z)
    );
  }

  scale(scalar) {
    return new SixPhiVector3(
      this.x.scale(scalar),
      this.y.scale(scalar),
      this.z.scale(scalar)
    );
  }

  negate() {
    return new SixPhiVector3(
      this.x.negate(),
      this.y.negate(),
      this.z.negate()
    );
  }

  toFloatArray() {
    return [this.x.toFloat(), this.y.toFloat(), this.z.toFloat()];
  }

  toString() {
    return `(${this.x.toString()}, ${this.y.toString()}, ${this.z.toString()})`;
  }

  equalsFloatArray(other, epsilon = 1e-9) {
    const a = this.toFloatArray();
    return a.every((v, i) => Math.abs(v - other[i]) < epsilon);
  }
}

function realDet3x3(M) {
  // Assumes M is a 3x3 array of floats: [[a,b,c], [d,e,f], [g,h,i]]
  const a = M[0][0], b = M[0][1], c = M[0][2];
  const d = M[1][0], e = M[1][1], f = M[1][2];
  const g = M[2][0], h = M[2][1], i = M[2][2];

  const ei = e * i;
  const fh = f * h;
  const di = d * i;
  const fg = f * g;
  const dh = d * h;
  const eg = e * g;

  const term1 = a * (ei - fh);
  const term2 = b * (di - fg);
  const term3 = c * (dh - eg);

  return term1 - term2 + term3;
}

function phiDet3x3(M) {
  // Destructure matrix entries for clarity
  const a = M[0][0], b = M[0][1], c = M[0][2];
  const d = M[1][0], e = M[1][1], f = M[1][2];
  const g = M[2][0], h = M[2][1], i = M[2][2];

  // Compute each of the minor terms
  const ei = e.multiply(i);   // e * i
  const fh = f.multiply(h);   // f * h
  const ei_minus_fh = ei.subtract(fh);  // (ei - fh)

  const di = d.multiply(i);   // d * i
  const fg = f.multiply(g);   // f * g
  const di_minus_fg = di.subtract(fg);  // (di - fg)

  const dh = d.multiply(h);   // d * h
  const eg = e.multiply(g);   // e * g
  const dh_minus_eg = dh.subtract(eg);  // (dh - eg)

  // Multiply by corresponding cofactors
  const termA = a.multiply(ei_minus_fh);
  const termB = b.multiply(di_minus_fg);
  const termC = c.multiply(dh_minus_eg);

  // Final determinant: a(ei - fh) - b(di - fg) + c(dh - eg)
  const det = termA.subtract(termB).add(termC);

  return det;
}
export class SixPhiVector {
  static basis = [
    new SixPhiVector3(new PhiBaseNumber(1, 0), new PhiBaseNumber(0, 0), new PhiBaseNumber(0, 1)),
    new SixPhiVector3(new PhiBaseNumber(1, 0), new PhiBaseNumber(0, 0), new PhiBaseNumber(0, -1)),
    new SixPhiVector3(new PhiBaseNumber(0, 0), new PhiBaseNumber(0, 1), new PhiBaseNumber(1, 0)),
    new SixPhiVector3(new PhiBaseNumber(0, 0), new PhiBaseNumber(0, -1), new PhiBaseNumber(1, 0)),
    new SixPhiVector3(new PhiBaseNumber(0, 1), new PhiBaseNumber(1, 0), new PhiBaseNumber(0, 0)),
    new SixPhiVector3(new PhiBaseNumber(0, -1), new PhiBaseNumber(1, 0), new PhiBaseNumber(0, 0))
  ];

  constructor(input) {
    function g(xx) {
    if (typeof xx === 'number' ) {
     return new PhiBaseNumber(0,xx);
    }
    if (typeof xx === 'PhiBaseNumber' ) {
     return xx;
    }
    return null;
    }
    this.coeffs = input.map(g);
    this.isComplete = !this.coeffs.includes(null);
  }

complete(debug = false) {
  function buildCol(A, bVec, colIndex) {
  // A is a 3x3 matrix of PhiBaseNumbers (rows of 3 each)
  // bVec is a SixPhiVector3: { x, y, z }
  // colIndex = 0, 1, or 2 indicating which column to replace

  return [
    [
      colIndex === 0 ? bVec.x : A[0][0],
      colIndex === 1 ? bVec.x : A[0][1],
      colIndex === 2 ? bVec.x : A[0][2]
    ],
    [
      colIndex === 0 ? bVec.y : A[1][0],
      colIndex === 1 ? bVec.y : A[1][1],
      colIndex === 2 ? bVec.y : A[1][2]
    ],
    [
      colIndex === 0 ? bVec.z : A[2][0],
      colIndex === 1 ? bVec.z : A[2][1],
      colIndex === 2 ? bVec.z : A[2][2]
    ]
  ];
}

function buildRealCol(A, bVec, colIndex) {
  return [
    [
      colIndex === 0 ? bVec[0] : A[0][0],
      colIndex === 1 ? bVec[0] : A[0][1],
      colIndex === 2 ? bVec[0] : A[0][2]
    ],
    [
      colIndex === 0 ? bVec[1] : A[1][0],
      colIndex === 1 ? bVec[1] : A[1][1],
      colIndex === 2 ? bVec[1] : A[1][2]
    ],
    [
      colIndex === 0 ? bVec[2] : A[2][0],
      colIndex === 1 ? bVec[2] : A[2][1],
      colIndex === 2 ? bVec[2] : A[2][2]
    ]
  ];
}

  if (this.isComplete) return;

  // Step 1: Identify known and unknown indices
  const known = this.coeffs.map((v, i) => v !== null ? [i, v] : null).filter(Boolean);
  const used = known.map(([i]) => i);
  const unused = [0,1,2,3,4,5].filter(i => !used.includes(i));

  if (known.length !== 3) {
    console.warn("You must provide exactly 3 known coefficients.");
    return;
  }

  // Step 2: Build RHS vectors (phi and real)
  let phiB = new SixPhiVector3();
  let realB = [0, 0, 0];

  for (const [i, c] of known) {
    const phiBasis = SixPhiVector.basis[i];
    const realBasis = phiBasis.toFloatArray();

    phiB = phiB.add(phiBasis.scale(c));
    realB[0] += realBasis[0] * c;
    realB[1] += realBasis[1] * c;
    realB[2] += realBasis[2] * c;
  }

  phiB = phiB.negate();
  realB = realB.map(x => -x);

  // Step 3: Build LHS matrix rows
  debugger;
  const phiA = unused.map(i => {
    const b = SixPhiVector.basis[i];
    return [b.x, b.y, b.z];  // Each is a PhiBaseNumber
  });
  const realA = unused.map(i => SixPhiVector.basis[i].toFloatArray());

  // Step 4: Compute determinants (main and minors)
  const phiMainDet = phiDet3x3(phiA);
  const realMainDet = realDet3x3(realA); // you'd define this float version

  const phiDetX = phiDet3x3(buildCol(phiA, phiB, 0));
  const phiDetY = phiDet3x3(buildCol(phiA, phiB, 1));
  const phiDetZ = phiDet3x3(buildCol(phiA, phiB, 2));

  const realDetX = realDet3x3(buildRealCol(realA, realB, 0));
  const realDetY = realDet3x3(buildRealCol(realA, realB, 1));
  const realDetZ = realDet3x3(buildRealCol(realA, realB, 2));

  // Step 5: Divide minors by main determinant
  const phiX = phiDetX.exactDivide(phiMainDet);
  const phiY = phiDetY.exactDivide(phiMainDet);
  const phiZ = phiDetZ.exactDivide(phiMainDet);

  const realX = realDetX / realMainDet;
  const realY = realDetY / realMainDet;
  const realZ = realDetZ / realMainDet;

  // Step 6: Compare results
  const phiResults = [phiX, phiY, phiZ];
  const realResults = [realX, realY, realZ];

  if (!phiResults.every(p => p && p.isInteger())) {
    console.warn("PhiBase result has non-integer values:", phiResults.map(p => p?.toString()));
    return;
  }

  if (debug) {
    console.log("PhiBase complete:", phiResults.map(p => p.toString()));
    console.log("Real-space complete:", realResults);
  }

  // Step 7: Store results
  this.coeffs[unused[0]] = phiX.n;
  this.coeffs[unused[1]] = phiY.n;
  this.coeffs[unused[2]] = phiZ.n;
  this.isComplete = true;
}

  toPhiVector3() {
    if (!this.isComplete) this.complete();
    let result = new SixPhiVector3();
    for (let i = 0; i < 6; i++) {
      result = result.add(SixPhiVector.basis[i].scale(this.coeffs[i] || 0));
    }
    return result;
  }

  toFloatArray() {
    return this.toPhiVector3().toFloatArray();
  }

  toString() {
    const coeffsStr = this.coeffs.map(c => c === null ? "?" : c).join(", ");
    return `SixPhiVector: [${coeffsStr}] => ${this.toPhiVector3().toString()}`;
  }
}

export function debugCompareVectors(vecA, vecB) {
  const a = new SixPhiVector(vecA);
  const b = new SixPhiVector(vecB);
  a.complete(true);
  b.complete(true);
  const aFloat = a.toFloatArray();
  const bFloat = b.toFloatArray();
  const equal = a.toPhiVector3().equalsFloatArray(bFloat);
  console.log("Compare A:", vecA, "→", aFloat);
  console.log("Compare B:", vecB, "→", bFloat);
  console.log("Equal?", equal);
}

