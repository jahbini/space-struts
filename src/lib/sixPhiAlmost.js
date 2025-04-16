// PhiBaseNumber models a + b·phi using integer arithmetic
export class PhiBaseNumber {
  constructor(a = 0, b = 0) {
    this.a = a; // integer part
    this.b = b; // phi multiple
  }

  static fromFloat(value, tolerance = 1e-9) {
    const phi = (1 + Math.sqrt(5)) / 2;
    const b = Math.round((value / phi - Math.floor(value / phi)) * 1000) / 1000;
    const a = value - b * phi;
    return new PhiBaseNumber(a, b);
  }

  add(other) {
    return new PhiBaseNumber(this.a + other.a, this.b + other.b);
  }

  subtract(other) {
    return new PhiBaseNumber(this.a - other.a, this.b - other.b);
  }

  scale(scalar) {
    return new PhiBaseNumber(this.a * scalar, this.b * scalar);
  }

  negate() {
    return new PhiBaseNumber(-this.a, -this.b);
  }

  multiply(other) {
    const a1 = this.a, b1 = this.b;
    const a2 = other.a, b2 = other.b;
    const real = a1 * a2 + b1 * b2;
    const phiPart = a1 * b2 + b1 * a2 + b1 * b2;
    return new PhiBaseNumber(real, phiPart);
  }

  exactDivide(other) {
    const c = other.a;
    const d = other.b;
    const denom = c * c - 2 * d * d; // since phi^2 = phi + 1
    if (denom === 0) {
      console.warn("Division by zero-like phi denominator");
      return null;
    }
    const a = this.a, b = this.b;
    const realNumer = a * c - b * d - b * d;
    const phiNumer = b * c - a * d - b * d;
    return new PhiBaseNumber(realNumer / denom, phiNumer / denom);
  }

  toFloat() {
    const phi = (1 + Math.sqrt(5)) / 2;
    return this.a + this.b * phi;
  }

  toString() {
    const parts = [];
    if (this.a !== 0) parts.push(`${this.a}`);
    if (this.b !== 0) parts.push(`${this.b === 1 ? '' : this.b}ϕ`);
    return parts.length > 0 ? parts.join(' + ') : '0';
  }

  divideApprox(other) {
    return this.toFloat() / other.toFloat();
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

  toFloatArray() {
    return [this.x.toFloat(), this.y.toFloat(), this.z.toFloat()];
  }

  toString() {
    return `(${this.x.toString()}, ${this.y.toString()}, ${this.z.toString()})`;
  }
}

function phiDet3x3(M) {
  const a = M[0][0], b = M[0][1], c = M[0][2];
  const d = M[1][0], e = M[1][1], f = M[1][2];
  const g = M[2][0], h = M[2][1], i = M[2][2];

  const term1 = a.multiply(e.multiply(i).subtract(f.multiply(h)));
  const term2 = b.multiply(d.multiply(i).subtract(f.multiply(g)));
  const term3 = c.multiply(d.multiply(h).subtract(e.multiply(g)));

  return term1.subtract(term2).add(term3);
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
    if (!Array.isArray(input) || input.length !== 6) {
      console.error("SixPhiVector input must be an array of 6 values (integers or nulls)");
      return;
    }

    this.coeffs = [];
    this.isComplete = true;

    for (let i = 0; i < 6; i++) {
      const val = input[i];
      if (typeof val === 'number') {
        this.coeffs[i] = val;
      } else {
        this.coeffs[i] = null;
        this.isComplete = false;
      }
    }
  }

  complete() {
    if (this.isComplete) return;

    const known = [];
    for (let i = 0; i < 6; i++) {
      if (this.coeffs[i] !== null) known.push([i, this.coeffs[i]]);
    }
    if (known.length !== 3) {
      console.warn("Cannot complete SixPhiVector: must have exactly 3 known coefficients");
      return;
    }

    const used = known.map(([i, _]) => i);
    const unused = [0,1,2,3,4,5].filter(i => used.indexOf(i) < 0);

    let knownVec = new SixPhiVector3();
    for (const [i, c] of known) {
      knownVec = knownVec.add(SixPhiVector.basis[i].scale(c));
    }

    debugger;
    const A = unused.map(i => SixPhiVector.basis[i]);
    const bVec = new SixPhiVector3(
      knownVec.x.negate(),
      knownVec.y.negate(),
      knownVec.z.negate()
    );

    const mat = [
      [A[0].x, A[0].y, A[0].z],
      [A[1].x, A[1].y, A[1].z],
      [A[2].x, A[2].y, A[2].z]
    ];

    const detMain = phiDet3x3(mat);
    if (Math.abs(detMain.toFloat()) < 1e-10) {
      console.warn("Degenerate phi matrix (determinant ~ 0)");
      return;
    }

    const buildCol = (colIdx) => [
      [bVec.x, mat[0][(colIdx+1)%3], mat[0][(colIdx+2)%3]],
      [bVec.y, mat[1][(colIdx+1)%3], mat[1][(colIdx+2)%3]],
      [bVec.z, mat[2][(colIdx+1)%3], mat[2][(colIdx+2)%3]]
    ];

    const x = phiDet3x3(buildCol(0)).exactDivide(detMain);
    const y = phiDet3x3(buildCol(1)).exactDivide(detMain);
    const z = phiDet3x3(buildCol(2)).exactDivide(detMain);

    this.coeffs[unused[0]] = x;
    this.coeffs[unused[1]] = y;
    this.coeffs[unused[2]] = z;
    this.isComplete = true;
  }

  toPhiVector3() {
    if (!this.isComplete) this.complete();
    let result = new SixPhiVector3();
    for (let i = 0; i < 6; i++) {
      result = result.add(SixPhiVector.basis[i].scale(this.coeffs[i]));
    }
    return result;
  }

  toFloatArray() {
    return this.toPhiVector3().toFloatArray();
  }

  toString() {
    const coeffsStr = this.coeffs.map(c => typeof c === 'number' ? c.toFixed(3) : c).join(", ");
    return `SixPhiVector: [${coeffsStr}] => ${this.toPhiVector3().toString()}`;
  }
}

