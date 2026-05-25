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
trusting any file, confirm it's imported by the live chain. Known-canonical:

```
src/lib/coffee/phiBase.coffee      # the exact number system (P(p,n)/d)
src/lib/coffee/sixPhiVector.coffee # six-basis vectors
src/lib/coffee/geoPhi.coffee       # the geometry engine (GeoPhi class)
src/lib/coffee/memo.coffee         # Memo cache used by GeoPhi
src/lib/seen.m.coffee              # Seen.js (SVG/canvas 3D engine)
src/lib/Floater.svelte             # thumbnail→fullscreen window component
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

## Conventions that matter

- **Comments have two audiences:** humans *and* LLM helpers. Comment the *why*,
  especially non-obvious geometry/algebra.
- **Exact over float.** PhiBase arithmetic is exact; lean into it. If exactness
  collapses float-noise duplicates (e.g. clique count dropping), that's a *win*,
  not a regression — verify geometry is unchanged, then report the merge.
