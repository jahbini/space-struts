// Master Geo namespace with sub-classes for P (point), E (edge), and T (triangle)
const Geo = {};

// GeoPoint -> Geo.P
Geo.P = class {
  constructor(...coeffs) {
    this.vector = new SixPhiVector(coeffs);
    this.name = Geo.P.generateName(this.vector);
  }

  static generateName(vector) {
    const parts = vector.coeffs.map(c => {
      if (c === null) return "";
      if (c instanceof PhiBase) {
        if (c.p === 0) return `${c.n}`;
        if (c.n === 0) return `${c.p}p`;
        return `${c.p}p+${c.n}`;
      }
      return `${c}`;
    });
    return `#${parts.join(',')}`;
  }

  completeIfNeeded() {
    if (!this.vector.isComplete) {
      this.vector.complete();
      this.name = Geo.P.generateName(this.vector);
    }
  }

  toFloatArray() {
    this.completeIfNeeded();
    return this.vector.toFloatArray();
  }

  toString() {
    return this.name;
  }
};

// GeoEdge -> Geo.E
Geo.E = class {
  constructor(pointA, pointB) {
    this.pointA = pointA;
    this.pointB = pointB;
    this.name = Geo.E.generateName(this.pointA, this.pointB);
  }

  static generateName(pA, pB) {
    return `_${pA.name}_${pB.name}`;
  }

  length() {
    const a = this.pointA.toFloatArray();
    const b = this.pointB.toFloatArray();
    const dx = a[0] - b[0];
    const dy = a[1] - b[1];
    const dz = a[2] - b[2];
    return Math.sqrt(dx * dx + dy * dy + dz * dz);
  }

  toString() {
    return this.name;
  }
};

// GeoTriangle -> Geo.T
Geo.T = class {
  constructor(pointA, pointB, pointC) {
    this.pointA = pointA;
    this.pointB = pointB;
    this.pointC = pointC;
    this.name = Geo.T.generateName(this.pointA, this.pointB, this.pointC);
  }

  static generateName(pA, pB, pC) {
    return `∆${pA.name}_${pB.name}_${pC.name}`;
  }

  area() {
    const a = this.pointA.toFloatArray();
    const b = this.pointB.toFloatArray();
    const c = this.pointC.toFloatArray();
    const ab = [b[0] - a[0], b[1] - a[1], b[2] - a[2]];
    const ac = [c[0] - a[0], c[1] - a[1], c[2] - a[2]];
    const cross = [
      ab[1] * ac[2] - ab[2] * ac[1],
      ab[2] * ac[0] - ab[0] * ac[2],
      ab[0] * ac[1] - ab[1] * ac[0]
    ];
    const crossMag = Math.sqrt(cross[0] ** 2 + cross[1] ** 2 + cross[2] ** 2);
    return 0.5 * crossMag;
  }

  toString() {
    return this.name;
  }
};

