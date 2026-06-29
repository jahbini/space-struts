// build-teapot-json.mjs
//
// One-shot generator for src/routes/explore/hull/teapot.json.
// Uses three.js's TeapotGeometry (Newell Utah teapot via Bezier patches).
//
// Run from repo root:
//   node src/routes/explore/hull/build-teapot-json.mjs
//
// Output: src/routes/explore/hull/teapot.json
//   { verts: [[x,y,z], ...], tris: [[i,j,k], ...], boundingRadius: 1.0 }
//
// The teapot is centered at the centroid of its bounding box and uniformly
// scaled so its bounding sphere has radius 1. The robot's phi-shell logic
// reads radial distances relative to this normalization.

import { writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { TeapotGeometry } from 'three/examples/jsm/geometries/TeapotGeometry.js';

const __dirname = dirname(fileURLToPath(import.meta.url));

// segments=4 -> ~530 tris. size=1 is the natural three.js size; we re-normalize.
const geom = new TeapotGeometry(1, 4, true, true, true, false, true);

const posAttr = geom.getAttribute('position');
const index = geom.getIndex();

// three.js TeapotGeometry is non-indexed when constructed this way; check.
const triCount = index ? index.count / 3 : posAttr.count / 3;

// First pass: collect raw verts (dedup via spatial hash to make the JSON smaller).
const rawVerts = [];
for (let i = 0; i < posAttr.count; i++) {
  rawVerts.push([posAttr.getX(i), posAttr.getY(i), posAttr.getZ(i)]);
}

// Dedup vertices to 5-decimal precision.
const key = (v) => v.map((c) => c.toFixed(5)).join(',');
const vertMap = new Map();
const verts = [];
const remap = new Array(rawVerts.length);
for (let i = 0; i < rawVerts.length; i++) {
  const k = key(rawVerts[i]);
  if (!vertMap.has(k)) {
    vertMap.set(k, verts.length);
    verts.push(rawVerts[i]);
  }
  remap[i] = vertMap.get(k);
}

// Build tris.
const tris = [];
if (index) {
  for (let i = 0; i < index.count; i += 3) {
    tris.push([remap[index.getX(i)], remap[index.getX(i + 1)], remap[index.getX(i + 2)]]);
  }
} else {
  for (let i = 0; i < posAttr.count; i += 3) {
    tris.push([remap[i], remap[i + 1], remap[i + 2]]);
  }
}

// Center on bounding-box centroid.
let xMin = Infinity, yMin = Infinity, zMin = Infinity;
let xMax = -Infinity, yMax = -Infinity, zMax = -Infinity;
for (const [x, y, z] of verts) {
  if (x < xMin) xMin = x; if (x > xMax) xMax = x;
  if (y < yMin) yMin = y; if (y > yMax) yMax = y;
  if (z < zMin) zMin = z; if (z > zMax) zMax = z;
}
const cx = (xMin + xMax) / 2;
const cy = (yMin + yMax) / 2;
const cz = (zMin + zMax) / 2;
for (const v of verts) { v[0] -= cx; v[1] -= cy; v[2] -= cz; }

// Compute bounding-sphere radius (max |v|) and normalize so radius = 1.
let rMax = 0;
for (const [x, y, z] of verts) {
  const r2 = x * x + y * y + z * z;
  if (r2 > rMax) rMax = r2;
}
rMax = Math.sqrt(rMax);
for (const v of verts) { v[0] /= rMax; v[1] /= rMax; v[2] /= rMax; }

// Trim float precision in output (4 decimals — ~0.0001 of bounding radius).
const trimVerts = verts.map(([x, y, z]) => [
  Number(x.toFixed(4)),
  Number(y.toFixed(4)),
  Number(z.toFixed(4)),
]);

const out = {
  verts: trimVerts,
  tris,
  boundingRadius: 1.0,
  meta: {
    source: 'three/examples/jsm/geometries/TeapotGeometry (Newell Utah teapot)',
    segments: 4,
    triCount: tris.length,
    vertCount: trimVerts.length,
    generatedBy: 'src/routes/explore/hull/build-teapot-json.mjs',
  },
};

const outPath = join(__dirname, 'teapot.json');
writeFileSync(outPath, JSON.stringify(out));
console.log(`wrote ${outPath}`);
console.log(`  verts: ${trimVerts.length}`);
console.log(`  tris:  ${tris.length}`);
console.log(`  bytes: ${JSON.stringify(out).length}`);
