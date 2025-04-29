
// sixPhi.js
SixPhiVector.prototype.complete = function (debug = false) {
  if (this.isComplete) return;

  const known = [];
  const unknownIndices = [];

  for (let i = 0; i < 6; i++) {
    if (this.coeffs[i]) {
      known.push([i, this.coeffs[i]]);
    } else {
      unknownIndices.push(i);
    }
  }

  if (known.length !== 3 || unknownIndices.length !== 3) {
    if (debug) console.warn("Cannot complete: vector must have exactly 3 known coefficients.");
    return null;
  }

  let x = new PhiBase(0, 0), y = new PhiBase(0, 0), z = new PhiBase(0, 0);
  for (const [i, val] of known) {
    const b = SixPhiVector.basis[i];
    x = x.add(b.x.mul(val));
    y = y.add(b.y.mul(val));
    z = z.add(b.z.mul(val));
  }

  const A = [[], [], []];
  for (const i of unknownIndices) {
    const b = SixPhiVector.basis[i];
    A[0].push(b.x);
    A[1].push(b.y);
    A[2].push(b.z);
  }

  const rhs = [x.neg(), y.neg(), z.neg()];
  const solved = symbolicSolve6x3(A, rhs);
  for (let i = 0; i < 3; i++) {
    this.coeffs[unknownIndices[i]] = solved[i];
  }

  this.isComplete = true;
};
