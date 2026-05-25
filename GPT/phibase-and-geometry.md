# PhiBase, the geometry engine, and the lessons

## PhiBase — exact golden-ratio arithmetic

`src/lib/coffee/phiBase.coffee`. A value is `P(p, n)/d = (p·φ + n)/d` where
`p, n, d` are integers (`d` defaults to 1). `φ² = φ + 1`.

- `new PhiBase(p, n)` or `new PhiBase(p, n, d)`.
- `.add/.sub/.mul` — exact; the `d==1` fast path matches the legacy integer
  behaviour exactly.
- `.div(other)` — **exact**, via the conjugate `P(-p, p+n)` and the algebraic
  norm `N = n² + np − p²`. Results reduce to lowest terms.
- `.inLattice()` → `d === 1` (the value is a true `Z[φ]` lattice element). This
  is the **exact membership test**: `d > 1` means the result left the lattice.
- `.toFloat()`, `.toID()` → `"P(p,n)"` or `"P(p,n,d)"`, `.toString()`, `.equals`.
- The denominator support was added so reflections (which land in `⅕Z[φ]`) stay
  exact. Geometry is bit-identical to the old float version; the only behavioural
  change was clique grouping dropping 140→100 as float-noise duplicates merged
  (a fix — exact `toName()` keys).

## SixPhiVector

`src/lib/coffee/sixPhiVector.coffee`. A point as six PhiBase coordinates.

- `SixPhiVector.fromPhiPoint(x, y, z)` — Cartesian PhiBase → six-vector.
- `.sixPhiToCartesianDisplay()` → `[x, y, z]` floats (the display Cartesian).
- `.v` — array of 6 `PhiBase`; `.scaleFactor`; `.add/.sub/.dot/.magnitude`.
- Round-trip `fromPhiPoint` → `sixPhiToCartesianDisplay` is exact.

## GeoPhi — the geometry engine

`src/lib/coffee/geoPhi.coffee`. `export class GeoPhi`, `export M` (a `Memo`).

- `new GeoPhi()` builds everything: `@allPoints` (76), `@segmentNames`,
  `@cliques`/`@cliqueNames`, `@fiboTriangles` (336), `@Polyhedra`
  (`.Dodecahedron1`, `.Icosahedron1`, `.Cube`, …), `@Faces`.
- `GeoPhi.createPhiPoint('#zOF')` — **static**, decodes a 3-symbol code to a
  SixPhiVector (cached in `M`). Add a reflection suffix: `'#zOF~A'` reflects
  through plane A; reflected coords carry **denominator 5** (`⅕Z[φ]`).
- `@mirrorPlanes` — the **15 mirror planes of Ih**, each `{label:"A+C", v:{x,y,z}}`.
- `planesContaining(dir3)` — exact `dir·normal == 0` test → plane labels.
- `clique.planes` — each clique tagged with the mirror plane(s) it lies in
  (40 in one plane, 60 on a two-plane axis).
- `@neighborStar` — 60 nearest-neighbour offsets `{offset:{x,y,z}, lenClass:'s'|'L'}`
  (30 short `2/φ` + 30 long `2`) = the `Ih` orbits of the two golden edge vectors.
- `goldenApexCandidates(p1, p2)` — for an edge (two SixPhiVector vertices),
  returns `[{apex:SixPhiVector, cart:{x,y,z}, kind:'golden'|'gnomon'}]`: every
  apex that completes a golden triangle `{s,φs,φs}` (36-72-72) or golden gnomon
  `{s,s,φs}` (108-36-36).

### The 7-symbol coordinate vocabulary
`z=0, O=1, o=−1, P=φ, p=−φ, f=φ−1, F=1−φ`. (Note: in the *code*, `f`/`F` are the
`pφ+n` values shown — the 2026 paper's Table 1 floats label them oppositely; the
code is canonical.)

## Icosahedral facts (verified exactly)

- The six face-normal directions **A–F are 5-fold axes, NOT mirror planes.**
  Reflections perpendicular to them are involutions but every pair has infinite
  order (mirror angles 63.4°/116.6°, never a Coxeter 36/60/90) → they generate an
  **infinite** group, not `Ih`. (The May-2026 paper's Corollary 6.5 is wrong on
  this — flag for revision.)
- The **15 real mirror planes** have normals `nX ± nY` (sum/difference of two
  basis normals): `C(6,2)=15` distinct 2-fold axes, whose reflections **do** close
  to `Ih` (order 120, 15 reflections).
- Reflection denominator: `n·n = P(1,2) = φ+2`, whose norm is `5` → reflected
  coords live in `⅕Z[φ]`.
- Nearest neighbours come from **translation by the edge-star (30 dirs/length)**,
  not reflection. Reflections/cliques only ever reach a fragment.
- Golden tiles: short `s = 2/φ` (dodecahedron edge), long `φs = 2` (icosahedron
  edge). `{s,φs,φs}`→golden triangle, `{s,s,φs}`→golden gnomon.

## The `learn/` lesson series

Seven student lessons; nav auto-discovers each folder via `+layout.js`'s
`import.meta.glob("./*/+page.sv*")` (alphabetical — the `learn/+page.svx` index
gives the intended order). Each folder = `+page.svx` + `+page.js` (`ssr=false`)
+ component(s) importing the real `$lib/coffee/*.coffee`.

Order: **phiBase** (exact arithmetic + `inLattice`) → **spine** (φᵏ = Fibonacci)
→ **sixBasis** (six-basis ↔ Cartesian) → **reflections** (`⅕Z[φ]`, has the
seen visual) → **planes** (15 mirror planes + clique tags) → **neighbors**
(30/30 star) → **goldenHull** (`goldenApexCandidates`).

For the visual pattern these lessons follow, see
[`floater-and-visuals.md`](floater-and-visuals.md). **All seven lessons now have
a `seen` visual** (gated by a `show3D` checkbox), built on the shared
`$lib/seenViz.js` helper. Camera/scale per scene may still want eyeball tuning.

## Headless verification

Node can't run the `.coffee` ESM directly (the `$lib` alias is Vite-only). To
test logic headless: compile copies to a temp dir and rewrite specifiers, e.g.

```bash
for f in phiBase sixPhiVector geoPhi memo; do
  npx coffee -c -b -o /tmp/build src/lib/coffee/$f.coffee
done
cd /tmp/build && sed -i '' -E "s#\\\$lib/coffee/##g; s#'(\\./)?([A-Za-z0-9_]+)\\.coffee'#'./\\2.js'#g" *.js
ln -sf ~/development/space-struts/node_modules ./node_modules
node yourTest.mjs
```

This keeps the `.coffee` source intact (never convert it).
