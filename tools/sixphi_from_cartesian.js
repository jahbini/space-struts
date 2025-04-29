
// sixphi_from_cartesian.js
SixPhiVector.fromCartesianPhiBase = function(x, y, z) {
  const rhs = [x, y, z];
  const A = [[], [], []];
  for (let j = 0; j < 6; j++) {
    const b = SixPhiVector.basis[j];
    A[0][j] = b.x;
    A[1][j] = b.y;
    A[2][j] = b.z;
  }
  const coeffs = symbolicSolve6x3(A, rhs);
  return new SixPhiVector(coeffs);
};
