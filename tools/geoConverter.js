// geo_converter.js
// Reads symbolic path definitions from stdin and outputs structured JSON with PhiBase symbolic coordinates

import readline from 'readline';

const PHI = (1 + Math.sqrt(5)) / 2;

class PhiBase {
  constructor(p, n,name=null) {
    this.p = p;
    this.n = n;
    if (name) { this.name = name }
     else name = this.toName;
  };

  toString() {
    return `(p${this.p},${this.n})`;
  };

  toName() {
    return `p${this.p},${this.n}`;
  };

  valueOf() {
    return this.p * PHI + this.n;
  }
}
const decode = {
  'z': new PhiBase(0, 0, 'z'),
  'O': new PhiBase(0, 1, 'O'),
  'o': new PhiBase(0, -1,'o'),
  'f': new PhiBase(-1, 1, 'f'),
  'F': new PhiBase(1, -1, 'F'),
  'p': new PhiBase(-1, 0, 'p'),
  'P': new PhiBase(1,  0, 'P')
};

const Geo = {
  P: class {
    constructor(px, py, pz) {
      this.coords = [px, py, pz];
      this.name = `#${px.toName()},${py.toName()},${pz.toName()}`;
    }
  },

  E: class {
    constructor(p1, p2) {
      this.name = `_${p1.name}_${p2.name}`;
      this.from = p1.name;
      this.to = p2.name;
    }
  },

  decodeChar(c) {
  if (!(c in decode)) throw new Error(`Invalid symbol character '${c}'`);
  return decode[c];
  },

  
  symbolToPhiBasePoint(symbol) {
    const s = symbol.replace(/^#/, '');
    if (s.length !== 3) throw new Error(`Symbol '${symbol}' must have 3 characters`);
    return new Geo.P(
      Geo.decodeChar(s[0]),
      Geo.decodeChar(s[1]),
      Geo.decodeChar(s[2])
    );
  },

  convertSymbolicFileFromText(fileText, label = 'geo_structure') {
    const lines = fileText
      .trim()
      .split(/\r?\n/)
      .map(line => line.trim())
      .filter(line => line && line.includes('='));

    const globalPoints = {};
    const globalEdges = {};
    const trails = [];

    for (const line of lines) {
      const [id, raw] = line.split('=');
      const trailId = id.trim();
      const pathString = raw.trim().replace(/^['"]|['"]$/g, '');
      const parts = pathString.split('-').map(s => s.trim());

      const trailPoints = [];
      const trailEdges = [];

      for (let i = 0; i < parts.length; i++) {
        const symbol = parts[i];
        const name = symbol;

        if (!(name in globalPoints)) {
          const p = Geo.symbolToPhiBasePoint(symbol);
          globalPoints[name] = {
            name: symbol,
            coords: p.coords.map(c => c.toName())
          };
        }

        trailPoints.push(name);

        if (i > 0) {
          const prev = parts[i - 1];
          const edgeKey = `_${prev}_${name}`;

          if (!(edgeKey in globalEdges)) {
            const e = new Geo.E(
              Geo.symbolToPhiBasePoint(prev),
              Geo.symbolToPhiBasePoint(name)
            );
            globalEdges[edgeKey] = {
              name: e.name,
              from: prev,
              to: name
            };
          }

          trailEdges.push(edgeKey);
        }
      }

      trails.push({
        id: trailId,
        path: pathString,
        points: trailPoints,
        edges: trailEdges,
      });
    }

    return {
      version: "V0.0",
      timestamp: new Date().toISOString(),
      label,
      trails,
      points: globalPoints,
      edges: globalEdges
    };
  }
};

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout,
  terminal: false
});

let inputText = '';
rl.on('line', line => inputText += line + '\n');

rl.on('close', () => {
  try {
    const result = Geo.convertSymbolicFileFromText(inputText);
    console.log(JSON.stringify(result, null, 2));
  } catch (err) {
    console.error("ERROR:", err.message);
    process.exit(1);
  }
});

