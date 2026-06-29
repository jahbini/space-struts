# GPT knowledge base — space-struts

Notes for AI assistants (and humans) working on this repo. Read these before
making changes; they capture hard-won, verified knowledge about the project.

## What this project is

`space-struts` is the **live SvelteKit site** at https://spacestruts.com/. It
explores an exact golden-ratio geometry system ("PhiBase") and builds
dodecahedral / quasicrystal structures from golden triangles.

- **Author:** James A. Hinds (Jim) — jahbini@celarien.com / SpaceStruts /
  Celarien Research. He authors the underlying math.
- **Language:** CoffeeScript-first. Source is `.coffee` and Svelte components
  are often `<script lang="coffeescript">`. Build uses `svelte-preprocess` +
  `vite-plugin-coffee`. **Never convert source to JS.** Node can't run the
  `.coffee` ESM modules directly (they use the `$lib` alias), so to test
  headless, compile *copies* to throwaway JS in `/tmp` — say so explicitly.
- **No Python, no Xcode tooling.** C++, Node, Bash, CoffeeScript only.
- **The dev server is Jim's.** Do not start/restart `vite dev`; he runs it and
  watches HMR. Ask him to eyeball pages.

## Big caveat: dead ends

The repo has **many abandoned experiments**. File presence ≠ canonical. Before
trusting any file, confirm it's imported by the live chain.

### Directory-placement rule (Jim's, enforced as of 2026-06-29)

- **Multi-page use → `src/lib/coffee/`** (or `src/lib/`).
- **Single-page use → next to the page, in `src/routes/.../`.**

Don't promote single-page modules to `$lib` just because they "feel like a
library". The page's own directory is the right home until a second consumer
shows up.

### Known-canonical, multi-page (lives in `$lib`)

```
src/lib/coffee/phiBase.coffee       # the exact number system (P(p,n)/d)
src/lib/coffee/sixPhiVector.coffee  # six-basis vectors
src/lib/coffee/geoPhi.coffee        # the geometry engine (GeoPhi class)
src/lib/coffee/memo.coffee          # Memo cache used by GeoPhi
src/lib/coffee/assembly.coffee      # WFC Assembly (hull + tiles consumers)
src/lib/coffee/wfc/*.coffee         # angle palette, vertex words, Robinson templates
src/lib/seen.m.coffee               # Seen.js (SVG/canvas 3D engine)
src/lib/Floater.svelte              # thumbnail→fullscreen window component
```

`src/lib/coffee/sixPhiVector3.coffee` exists with **no consumers** — dead.

### Known-canonical, single-page (lives next to its page)

```
src/routes/explore/hull/             # the "Robot Build around a teapot/torus" page
  +page.svelte                       # the page; uses meshes.coffee + robotBuildBridge
  meshes.coffee                      # uniform mesh-registry interface (teapot, torus, ...)
  teapotMesh.coffee                  # teapot mesh data + BVH + setTeapotScale
  teapot.json                        # the embedded Newell teapot mesh
  build-teapot-json.mjs              # one-shot generator for teapot.json
  robotBuildBridge.coffee            # buildVoxelHull + buildVoxelHullStreaming (the hull builder)
  robotBuild.coffee                  # state helpers used by the bridge
  phiShells.coffee                   # phi-shell bands used by the bridge
  teapotWfc.coffee, dodecWfc3D.coffee # 3D dodec-surface WFC bridges (used at n ≥ 0)
src/routes/explore/tiles/            # the "Hypno Tiles" page (2D Robinson WFC)
src/routes/explore/puzzle/           # an earlier 2D Robinson WFC page
```

The parallel `src/lib/phiBase.js` / `sixPhi.js` were **stale duplicates and
were deleted**. Use the `$lib/coffee/*.coffee` versions.

## The files here

- [`phibase-and-geometry.md`](phibase-and-geometry.md) — the number system, the
  `GeoPhi` API, the icosahedral facts, and the `learn/` lesson series.
- [`seen.md`](seen.md) — how the Seen.js 3D engine is used here (the bits that
  bite you).
- [`floater-and-visuals.md`](floater-and-visuals.md) — the `Floater` component
  and the **approved lesson-visual pattern** (calc in sidebar + `seen` visual in
  the left column, toggled by a checkbox). Copy this pattern for any page with
  visual needs.
- [`wfc-robinson.md`](wfc-robinson.md) — the 2D Robinson-tile WFC fill at
  `/explore/puzzle`. Documents the **(e₀, e₇₂) non-orthogonal basis** for
  exact PhiBase 2D arithmetic, the heuristic stack, and the recurring
  "pick the right primitive" lesson.
- [`voxel-hull.md`](voxel-hull.md) — the **technique for wrapping an
  arbitrary 3D object in a golden-tile hull**. Cubic lattice, hut cells,
  classifier (centre+corners ray test, plus adaptive triangle rasterization
  for the feature pass). Streaming iterator pumps the build in
  ~16 ms ticks so the page stays responsive and triangles appear live.
  Multi-mesh via a uniform registry: teapot, torus, and any new shape
  that implements the interface.

## Conventions that matter

- **Comments have two audiences:** humans *and* LLM helpers. Comment the *why*,
  especially non-obvious geometry/algebra.
- **Exact over float.** PhiBase arithmetic is exact; lean into it. If exactness
  collapses float-noise duplicates (e.g. clique count dropping), that's a *win*,
  not a regression — verify geometry is unchanged, then report the merge.
