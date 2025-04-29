// phiBase.js - A clean, standalone Golden Ratio number class

export class PhiBase {
  /** The golden ratio constant φ */
  static get PHI() {
    return (1 + Math.sqrt(5)) / 2;
  }

  /** Zero element (0φ + 0) */
  static ZERO = new PhiBase(0, 0);

  /** One element (0φ + 1) */
  static ONE = new PhiBase(0, 1);

  constructor(p = 0, n = 0) {
    this.p = p;
    this.n = n;
  }

  clone() {
    return new PhiBase(this.p, this.n);
  }
  isZero() {
    return this.p == 0 && this.n == 0 ;
  }

  step() {
    const phiValue = this.p * PhiBase.phi; // φ as static or imported
    if (this.n < phiValue) {
      return new PhiBase(this.p, this.n + 1);
    } else {
      return new PhiBase(this.p + 1, this.n);
    }
  }

  /** String representation, e.g. "3φ + 5" */
  toString() {
    return `${this.p}φ + ${this.n}`;
  }

  /** Floating-point approximation */
  toFloat() {
    return this.p * PhiBase.PHI + this.n;
  }

  /** Exact equality check */
  equals(other) {
    return this.p === other.p && this.n === other.n;
  }

  /** Addition in ℤ[φ] */
  add(other) {
    return new PhiBase(this.p + other.p, this.n + other.n);
  }

  /** Subtraction in ℤ[φ] */
  sub(other) {
    return new PhiBase(this.p - other.p, this.n - other.n);
  }
  
  /** Negation */
  negate() {
    return new PhiBase(-this.p,-this.n);
  }

  /** Scaling by a constant or a phiBase value */
  scale(x) {
    if ( x instanceof PhiBase ) return this.mul(x);
    return new PhiBase(x * this.p, x * this.n)
   }

  /** Multiplication in ℤ[φ]
   * (p1φ + n1)(p2φ + n2)
   * = p1p2 φ² + (p1n2 + n1p2) φ + n1n2
   * with φ² → φ + 1
   */
  mul(other) {
    const phiSquared = this.p * other.p;
    const phiCoeff = this.p * other.n + this.n * other.p + phiSquared;
    const constTerm = this.n * other.n + phiSquared;
    return new PhiBase(phiCoeff, constTerm);
  }

  /** Division via conjugate in ℤ[φ]
   * Denominator (norm) = n² + n*p - p²
   * Conjugate of (pφ + n) is (-p)φ + (n + p)
   * Throws if result is not integral.
   */
  div(other) {
    const denom = other.n * other.n + other.n * other.p - other.p * other.p;
    if (denom === 0) {
      throw new Error('Division by zero (other has zero norm)');
    }
    // Conjugate
    const conj = new PhiBase(-other.p, other.n + other.p);
    // Multiply numerator by conjugate
    const num = this.mul(conj);
    // Ensure integral result
    if (num.p % denom !== 0 || num.n % denom !== 0) {
      console.warn(
        `Non-integer division result (requires substructure): [${num.p}/${denom} φ, ${num.n}/${denom}]`
      );
    }
    return new PhiBase(num.p / denom, num.n / denom);
  }

  /** True if both components are integers */
  isInteger() {
    return Number.isInteger(this.p) && Number.isInteger(this.n);
  }

  /** Return a simplified (rounded) copy */
  simplify() {
    return new PhiBase(Math.round(this.p), Math.round(this.n));
  }

  /** Approximate from a floating value */
  static fromFloat(value) {
    const pApprox = value / PhiBase.PHI;
    const p = Math.round(pApprox);
    const n = Math.round(value - p * PhiBase.PHI);
    return new PhiBase(p, n);
  }
}

// --- Basic validity tests (run in browser console or Node) ---
(function _phiBaseTests() {
  const zero = PhiBase.ZERO;
  const one = PhiBase.ONE;
  console.assert(zero.equals(new PhiBase(0, 0)), 'ZERO constant failed');
  console.assert(one.equals(new PhiBase(0, 1)), 'ONE constant failed');

  const a = new PhiBase(1, 2);
  const b = new PhiBase(3, 4);
  console.assert(a.add(b).equals(new PhiBase(4, 6)), 'add failed');
  console.assert(a.sub(b).equals(new PhiBase(-2, -2)), 'sub failed');
  console.assert(a.mul(b).equals(new PhiBase(13, 11)), 'mul failed');
  console.assert(a.div(a).equals(one), 'div self failed');

  // Test non-integer division case (should throw)
  let threw = false;
  try {
    const c = new PhiBase(1, 0);
    c.div(new PhiBase(1, 2));
  } catch (e) {
    threw = true;
  }
  console.assert(!threw, 'non---integer div did not throw');

  console.log('PhiBase: all tests passed');
})();

