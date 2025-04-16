export const phi = (1 + Math.sqrt(5)) / 2;

export class SixVector {
  static basis = [
    [phi, 0, 1],
    [phi, 0, -1],
    [0, 1, phi],
    [0, -1, phi],
    [1, phi, 0],
    [-1, phi, 0]
  ];

  constructor(input) {
    if (!Array.isArray(input) || input.length !== 6) {
      throw new Error("SixVector input must be an array of 6 values (numbers or nulls)");
    }

    this.coeffs = [];
    this.isComplete = true;

    for (let i = 0; i < 6; i++) {
      const val = input[i];
      if (typeof val === 'number' && !isNaN(val)) {
        this.coeffs[i] = val;
      } else {
        this.coeffs[i] = 0;
        this.isComplete = false;
      }
    }
  }

  complete() {
    if (this.isComplete) return;

    const known = [];
    for (let i = 0; i < 6; i++) {
      const val = this.coeffs[i];
      if (typeof val === 'number' && val !== 0) {
        known.push([i, val]);
      }
    }

    if (known.length !== 3) {
      throw new Error("Cannot complete SixVector: must have exactly 3 known coefficients");
    }

    const used = known.map(([i, _]) => i);
    const unused = [0, 1, 2, 3, 4, 5].filter(i => used.indexOf(i) < 0);

    let knownVec = [0, 0, 0];
    for (const [i, c] of known) {
      const b = SixVector.basis[i];
      knownVec = [
        knownVec[0] + c * b[0],
        knownVec[1] + c * b[1],
        knownVec[2] + c * b[2]
      ];
    }

    const A = unused.map(i => SixVector.basis[i]);

    const det = (M) => (
      M[0][0] * (M[1][1] * M[2][2] - M[1][2] * M[2][1]) -
      M[0][1] * (M[1][0] * M[2][2] - M[1][2] * M[2][0]) +
      M[0][2] * (M[1][0] * M[2][1] - M[1][1] * M[2][0])
    );

    const makeMat = (col) => A.map((row, i) => row.map((v, j) => j === col ? -knownVec[i] : v));

    const D = det(A);
    if (Math.abs(D) < 1e-10) {
      throw new Error(`Degenerate basis system (determinant ~ 0): ${D}`);
    }

    const x = det(makeMat(0)) / D;
    const y = det(makeMat(1)) / D;
    const z = det(makeMat(2)) / D;

    if ([x, y, z].some(v => typeof v !== 'number' || isNaN(v))) {
      throw new Error(`Invalid solution: x=${x}, y=${y}, z=${z}`);
    }

    this.coeffs[unused[0]] = x;
    this.coeffs[unused[1]] = y;
    this.coeffs[unused[2]] = z;
    this.isComplete = true;
  }

  toCartesian() {
    if (!this.isComplete) this.complete();

    const result = [0, 0, 0];
    for (let i = 0; i < 6; i++) {
      const b = SixVector.basis[i];
      const c = this.coeffs[i];
      result[0] += c * b[0];
      result[1] += c * b[1];
      result[2] += c * b[2];
    }
    return result;
  }

  toString() {
    const coeffsStr = this.coeffs.map(x => x?.toFixed?.(3) ?? "null").join(", ");
    const cartesian = this.toCartesian().map(x => x.toFixed(3)).join(", ");
    return `6-vector: [${coeffsStr}]\nCartesian: [${cartesian}]`;
  }
}

