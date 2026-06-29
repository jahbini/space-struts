# Voxel hull around an arbitrary 3D object — two parts and a classifier

A reusable technique for wrapping any 3D object in a golden-tile hull. The geometry primitives are fixed (two Robinson tile types and a hut module); the only object-specific work is a cell classifier on a regular cubic lattice.

This is the technique that wrapped the Utah teapot at `/explore/hull`. The same code works for any meshed object whose surface you can query — just swap the classifier's per-cube test.

## The two parts (all the golden geometry there is)

- **T** — golden triangle (acute, 36°/72°/72°, edges `(L, S, L)` with `L/S = φ`).
- **G** — golden gnomon (obtuse, 108°/36°/36°, edges `(L, S, S)`).

Everything in this hull is composed from those two. No other tile types exist in the construction.

## The composition module — the Hut

Six golden triangles arranged around a square base. From above the base:
- 1 square (the cube face — never rendered; it's interior to the cube).
- 1 ridge running across the face at perpendicular distance `s/φ`, length `s` along one axis.
- 2 trapezoidal long sides each composed of 2 triangles, plus 2 triangular short sides — 6 rendered triangles total.

The hut's footprint is a cube face, so it snaps directly into a cubic lattice. **Six huts on the six faces of one cube, ridges outward, form a regular dodecahedron** (each pair of adjacent huts contributes one of the 12 pentagonal faces). Same six huts with ridges inward fold back into the cube. That cube↔dodec hinge is what makes the technique work: when a cube cell is fully surrounded by neighbours it disappears into the lattice's interior, and when it's at the boundary its outward-facing huts compose pentagonal patches of the surface dodecahedron with whatever neighbours are also boundary cubes.

## The hull is "the boundary of the filled region"

Tile 3D space with cubic cells. For each cell, decide *filled* or *empty*. The hull consists of one hut per **filled cube face whose neighbour cube is empty**. Adjacent filled cubes share huts internally (no rendering needed); fully empty cubes contribute nothing; the entire boundary is a closed manifold of golden triangles.

**Per-shape work is exactly the per-cube classifier.** Everything else is a property of the lattice and the hut module.

## The classifier — two passes

Object-specific. Tested for the teapot mesh and a procedural torus; generalises to any surface that supports the same queries.

### Pass 1: `isInside(pos)`

A cube `(i, j, k)` is **filled** iff its centre or any of its 8 corners returns `true` from a caller-provided `isInside(pos)` predicate.

- **Star-shaped meshes** (teapot): default test is `r < radialDistance(pos/|pos|)` — the ray from origin through `pos` hits the surface beyond `pos`. One BVH ray per query.
- **Non-star-shaped meshes** (torus, Klein bottle, anything with a hole through which a ray from origin can miss the body): caller supplies an `isInside` that works for that shape. Torus uses the exact analytic formula `distance(p, centerline_circle) < r`. Both meshes plug in through the same option (`opts.isInside`).

Without the isInside hook, the radial-distance rule misclassifies points inside the *tube* of a torus (the ray from origin enters and exits the body — interior points have `r > rT`). That's why this is a per-mesh hook, not hard-coded in the builder.

### Pass 2: triangle rasterization (the feature pass)

For each mesh triangle, **recursively split it along its longest edge until every sub-triangle has its longest edge shorter than the cube edge `2s`**. Force-fill the cube containing each sub-triangle vertex. This guarantees that every cube the mesh surface passes through gets marked filled, no matter how big the original mesh triangle is relative to the cube grid.

This is the fix for the "body holes at n=−6" problem. The older feature pass was just *"3 vertices + 1 centroid per triangle"*, which is fine when mesh triangles are at most a few cubes across — true on the handle, spout, and lid (lots of small triangles packed close). The teapot **body**, however, has *fewer, larger* triangles each spanning many cubes; only the 4 sample points got force-filled and the cubes between them fell through both passes → scattered missing huts. Adaptive subdivision pushes the sampling to scale with cube size: recursion depth `≈ log2(longest mesh edge / cube edge)`, cost negligible compared to the scan.

Pass 1 (cube geometry) and Pass 2 (mesh geometry) are both needed. Pass 1 covers the *interior volume*. Pass 2 covers the *shell* — particularly thin features and any cube the surface clips.

## What's load-bearing about this design

- **Only the classifier is shape-specific.** Drop the teapot, plug in a different meshed object's `verts`, `tris`, `radialDistance` *and* `isInside` — same code wraps it. The shape registry at `src/routes/explore/hull/meshes.coffee` defines a uniform interface (`verts`, `tris`, `boundingRadius`, `radialDistance`, `isInside`, `seenModel`, `setScale`) so swapping shapes is one dropdown click.
- **The hull is closed by construction.** No edge gluing, no patch-stitching. Whichever cube faces have a filled neighbour stay interior; whichever have an empty neighbour render a hut. The dodec↔cube hinge guarantees the boundary tiles compose.
- **Every tile is an exact T or G** (in PhiBase). No deformation. No interpolation. Rendering is the only place float touches anything.
- **A construction robot doesn't need to know the shape.** Hand it a stock of T and G sticks (two SKUs) and the same lattice; the only signal it needs is the per-cube classifier output. That's a deeply compact instruction stream for a physical robot's hull-around-an-object task — "with only two parts," as Jim put it.

## Streaming + bounding-region scan (current build path)

`buildVoxelHullStreaming` is the live builder. Two things made it fast enough to run at n=−7 in seconds:

### 1. Active bounding region — don't enumerate cubes we'd just throw away

The cube grid technically covers `[-range, range]³` with `range = ⌈2.5 · TEAPOT_SCALE / scale⌉`. At n=−5 that's ~800k cubes. The mesh occupies a sphere of radius ≈ `boundingRadius`, so cubes outside `⌈(boundingRadius + cube_diagonal) / (2s)⌉ + 1` index units are *provably* empty (no centre or corner can reach the surface). The builder enumerates only the smaller active region — typically 1-2% of the full grid — and treats the rest as empty by convention. Boundary cubes inside the active region see "out-of-active" neighbours the same way they'd see true out-of-grid neighbours: as empty, fire the boundary hut outward.

This is the **bounding-sphere prune** from the previous version of this doc, done structurally instead of per-cube. We never call `cubeIsFilled` on the empty volume at all.

### 2. Single-pass interleaved scan — triangles emit live

Earlier versions had two phases: classify *all* cubes, then render boundary huts. That meant a long silent wait followed by a burst at the end. The streaming builder collapses them into one scan:

For each cube `(i, j, k)` in active-region order:
1. Classify it (Pass 1 above) unless the feature pass already marked it.
2. For each of the 6 neighbours **that has already been scan-processed**, decide the shared face: if exactly one of the pair is filled, emit a hut on the filled cube's face toward the empty side. Each face is handled exactly once — on the second cube of the pair.
3. Mark this cube scan-processed.

Triangles appear as soon as the scan crosses the first boundary cube. Each `.next()` of the iterator runs up to `batchSize` (default 5000) cubes OR `batchBudgetMs` (default 12 ms) of work, whichever comes first — so cheap empty cubes fly by in a single tick while expensive teapot-region cubes throttle naturally. The page pumps `.next()` at ~60 fps via `setInterval`, appends the returned `newTriangles` to its seen `Model`, and renders.

Cube↔dodec hinge guarantees adjacent boundary cubes' huts mate edge-to-edge by construction — there is no edge-joining step. Holes only ever come from misclassification (cube wrongly marked empty, neighbour also empty → hull jumps past it).

## Trade-offs that remain

- **Hull is "stepped," not smooth.** The cubic lattice produces a stair-step silhouette by construction. Refining `n` reduces the step size at the cost of more cubes. To smooth the surface further you'd need either a non-cubic lattice or post-hoc fairing — out of scope here.

- **One cube edge of jitter at the boundary.** The conservative classifier expands the filled region by up to `s` (cube edge) at boundaries — the bumps may sit slightly outside the surface in places. Acceptable for an enclosure; not acceptable for a tight fit.

- **Back-face culling can look like holes from the inside.** Each hut triangle is one-sided (`cullBackfaces = true`). Looking down the spout or through the handle, the *back* of the far side of the hull is invisible — the canvas shows through. This is a viewing artifact, not missing geometry. Turning off `cullBackfaces` per shape closes the look at a render cost.

- **n=−7 is the practical ceiling on a laptop.** At n=−7 the active region is ~`90³`-ish cubes; build still completes in seconds because most of the cost is in the (~few thousand) shell cubes near the surface. Going further would want a shared-corner cache (skip duplicate corner ray-casts between adjacent cubes) or a mesh spatial hash inside the BVH leaf — neither needed yet.

## Where it lives

The hull subsystem is **single-page** — everything lives next to its only consumer in `src/routes/explore/hull/`:

- `robotBuildBridge.coffee` — `buildVoxelHull(G, radialDistance, opts)` and `buildVoxelHullStreaming(...)`. Imports no mesh-specific code; receives `opts.meshVerts`, `opts.meshTris`, `opts.boundingRadius`, `opts.isInside` from the caller.
- `robotBuild.coffee`, `phiShells.coffee` — internal helpers used by the bridge.
- `meshes.coffee` — uniform shape registry. Each entry exposes `{ verts, tris, boundingRadius, radialDistance, isInside, seenModel, setScale, getScale }`. Currently registered: `teapot`, `torus`. New shapes are added by writing a generator and calling `makeBvhMesh` (the BVH-backed factory in this file).
- `teapotMesh.coffee`, `teapot.json`, `build-teapot-json.mjs` — teapot mesh data + BVH, normalized to bounding radius 1.0. `setTeapotScale(s)` mutates `teapotVerts` in place and invalidates the BVH so the same mesh data backs the live `TEAPOT_SCALE` knob.
- `teapotWfc.coffee`, `dodecWfc3D.coffee` — the *other* code path (n ≥ 0): 3D WFC on a single dodecahedron's surface. Imports `$lib/coffee/phiBase.coffee` etc. for shared math.
- `+page.svelte` — Svelte page. Owns the seen.js scene, level controls (`currentN` selects `scale = 0.35 · φⁿ⁺¹`), shape picker, visibility toggles, and pumps the streaming iterator at ~60 fps.

The lib (`$lib/coffee/*.coffee`) is **mesh-agnostic** by intent — `phiBase`, `sixPhiVector`, `geoPhi`, the `wfc/*` modules. Single-page subsystems should not live there; see `GPT/README.md` for the directory-placement rule.

## The principle (one more instance of the recurring lesson)

This is the third instance of `GPT/wfc-robinson.md`'s "**match the boundary to the lattice**" rule, in a new shape:

> *Don't try to construct a hull as a continuous surface. Construct it as the boundary of a discrete cellular volume, in a lattice whose unit cell already composes the geometry you want.*

The cube↔dodec hinge means the cubic lattice already composes golden geometry. The classifier is *the entire* shape-specific step. Same lesson as Cartesian-xy → `(e₀, e₇₂)`, rectangle → pentagon, surface-growth → volumetric cells: pick the representation that already contains the structure you want, and shape becomes a parameter rather than a construction job.
