// PhiBaseNumber models a + b·phi using integer arithmetic
// PhiBaseNumber models p·phi + n using integer arithmetic
export class PhiBaseNumber {
  constructor(p = 0, n = 0) {
    this.p = p; // multiplier of phi
    this.n = n; // normal integer part
  }

  static fromFloat(value) {
    const phi = (1 + Math.sqrt(5)) / 2;
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
    const real = this.p * other.p + this.n * other.n;
    const phi = this.p * other.n + this.n * other.p + this.p * other.p;
    return new PhiBaseNumber(phi, real);
  }

  exactDivide(other) {
    const c = other.p;
    const d = other.n;
    const denom = c * c - 2 * d * d;
    if (denom === 0) {
      console.warn("Division by zero-like phi denominator");
      return null;
    }
    const realNumer = this.p * c - this.n * d - this.n * d;
    const phiNumer = this.n * c - this.p * d - this.n * d;
    return new PhiBaseNumber(phiNumer / denom, realNumer / denom);
  }

  isInteger() {
    return Number.isInteger(this.p) && Number.isInteger(this.n);
  }

  toFloat() {
    const phi = (1 + Math.sqrt(5)) / 2;
    return this.p * phi + this.n;
  }

  toString() {
    const phiStr = this.p === 0 ? "" : (this.p === 1 ? "ϕ" : `${this.p}ϕ`);
    const nStr = this.n !== 0 ? (this.n > 0 && phiStr ? ` + ${this.n}` : `${this.n}`) : "";
    return (phiStr + nStr) || "0";
  }
} 

// All downstream classes will now rely on p/n instead of a/b for PhiBaseNumber
// The rest of the file (SixPhiVector3, SixPhiVector, debugCompareVectors) is unchanged and inherits this new convention


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

function phiDet3x3(M) {
  const a = M[0][0], b = M[0][1], c = M[0][2];
  const d = M[1][0], e = M[1][1], f = M[1][2];
  const g = M[2][0], h = M[2][1], i = M[2][2];

  return a.multiply(e.multiply(i).subtract(f.multiply(h)))
    .subtract(b.multiply(d.multiply(i).subtract(f.multiply(g))))
    .add(c.multiply(d.multiply(h).subtract(e.multiply(g))));
}

export class SixPhiVector {
  static basis = [
    new SixPhiVector3(new PhiBaseNumber(0,1), new PhiBaseNumber(0,0), new PhiBaseNumber(1,0)),
    new SixPhiVector3(new PhiBaseNumber(0,1), new PhiBaseNumber(0,0), new PhiBaseNumber(-1,0)),
    new SixPhiVector3(new PhiBaseNumber(0,0), new PhiBaseNumber(1,0), new PhiBaseNumber(0,1)),
    new SixPhiVector3(new PhiBaseNumber(0,0), new PhiBaseNumber(-1,0), new PhiBaseNumber(0,1)),
    new SixPhiVector3(new PhiBaseNumber(1,0), new PhiBaseNumber(0,1), new PhiBaseNumber(0,0)),
    new SixPhiVector3(new PhiBaseNumber(-1,0), new PhiBaseNumber(0,1), new PhiBaseNumber(0,0))
  ];

  constructor(input) {
    this.coeffs = input.map(x => (typeof x === 'number' ? x : null));
    this.isComplete = !this.coeffs.includes(null);
  }

  complete(debug = false) {
    if (this.isComplete) return;

    const known = this.coeffs.map((v, i) => v !== null ? [i, v] : null).filter(Boolean);
    if (known.length !== 3) {
      console.warn("Exactly 3 coefficients must be known to complete the vector.");
      return;
    }

    const used = known.map(([i, _]) => i);
    const unused = [0,1,2,3,4,5].filter(i => !used.includes(i));

    let phiVec = new SixPhiVector3();
    let realVec = [0, 0, 0];
    for (const [i, c] of known) {
      phiVec = phiVec.add(SixPhiVector.basis[i].scale(c));
      const f = SixPhiVector.basis[i];
      realVec[0] += f.x.toFloat() * c;
      realVec[1] += f.y.toFloat() * c;
      realVec[2] += f.z.toFloat() * c;
    }

    const A = unused.map(i => SixPhiVector.basis[i]);
    const matPhi = [
      [A[0].x, A[0].y, A[0].z],
      [A[1].x, A[1].y, A[1].z],
      [A[2].x, A[2].y, A[2].z]
    ];
    const bPhi = phiVec.negate();
    const detMain = phiDet3x3(matPhi);

    const buildCol = (colIdx) => [
      [bPhi.x, matPhi[0][(colIdx+1)%3], matPhi[0][(colIdx+2)%3]],
      [bPhi.y, matPhi[1][(colIdx+1)%3], matPhi[1][(colIdx+2)%3]],
      [bPhi.z, matPhi[2][(colIdx+1)%3], matPhi[2][(colIdx+2)%3]]
    ];

    const x = phiDet3x3(buildCol(0)).exactDivide(detMain);
    const y = phiDet3x3(buildCol(1)).exactDivide(detMain);
    const z = phiDet3x3(buildCol(2)).exactDivide(detMain);

    const solved = [x, y, z];
    const allInteger = solved.every(val => val && val.isInteger());

    if (!allInteger) {
      console.warn("Non-integer coefficients detected:", solved.map(s => s?.toString()));
      return;
    }

    if (debug) {
      const cartesian = new SixPhiVector([ ...this.coeffs ]);
      cartesian.coeffs[unused[0]] = x.a;
      cartesian.coeffs[unused[1]] = y.a;
      cartesian.coeffs[unused[2]] = z.a;
      const floatCart = cartesian.toFloatArray();
      console.log("Cartesian result:", floatCart);
    }

    this.coeffs[unused[0]] = x.a;
    this.coeffs[unused[1]] = y.a;
    this.coeffs[unused[2]] = z.a;
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

// Debug test function
export function debugCompareVectors(vecA, vecB) {
  const a = new SixPhiVector(vecA);
  const b = new SixPhiVector(vecB);
  debugger

  a.complete(true);
  b.complete(true);

  const aVec = a.toPhiVector3();
  const bVec = b.toPhiVector3();

  const aFloat = aVec.toFloatArray();
  const bFloat = bVec.toFloatArray();

  const equal = aVec.equalsFloatArray(bFloat);

  console.log("Compare A vs B:", vecA, "vs", vecB);
  console.log("Float A:", aFloat);
  console.log("Float B:", bFloat);
  console.log("Equal?", equal);
} 

