# WFC over Robinson tiles — what we learned

A 2D Wave-Function-Collapse fill of Robinson tiles (golden triangle T + golden gnomon G) over a chosen target region. Lives in `src/lib/coffee/wfc/`; the interactive page is `/explore/puzzle`. Source-of-truth specs and tables in `static/wfc/*.json` (originally from `./fromClaude/`).

This file is for the *lessons* — implementation lives in the modules and the prompt in `static/wfc/`/`fromClaude/wfc-prompt.md`.

## The core representation choice

**For 2D Penrose / Robinson tile work in this codebase, use the (e₀, e₇₂) basis, not Cartesian xy.**

- Cartesian xy *cannot* be expressed exactly in `Z[φ]` under 36°-multiple rotation, because `sin(36°) ∉ Q[φ]` — the field needs a degree-4 extension `Q[φ, √(2 − φ)]`.
- Pick `e₀ = (1, 0)` and `e₇₂ = (cos 72°, sin 72°)` as a 2D basis. Every Robinson-tile vertex position is a 2-tuple `(a, b)` of `PhiBase` values meaning `a·e₀ + b·e₇₂`. **Exact** under all 36°-multiple rotations.

The 36° rotation matrix in this basis (verified algebraically; `det = 1`):

```
R₃₆ = | φ−1   1−φ |       ⇔   (a, b) ↦ ( (φ−1)(a−b),  (φ−1)a + b )
      | φ−1    1  |
```

Concretely it stays in `Z[φ]`:

- `R₃₆ e₀  = (φ−1, φ−1)`
- `R₃₆ e₇₂ = (1−φ,  1 )`

And `φ` and `φ⁻¹` show up as `PhiBase(1, 0)` and `PhiBase(1, -1)`.

Two precomputed tables in `phiPoint2D.coffee` carry the 20 unit + long displacement vectors:

```
UNIT_DISP[k]   # = R₃₆ᵏ · e₀,  length 1
LONG_DISP[k]   # = φ · UNIT_DISP[k],  length φ
```

so placing a new vertex is `parent.pos.add(UNIT_DISP[(edgeDir + angleAtA/36) % 10])`. No `Math.sin`, no `Math.cos`, no epsilons. Float only escapes via `PhiPoint2D.toCartesian()` and only at SVG render time.

## Squared-distance metric in the (e₀, e₇₂) basis

```
|p|² = a² + (φ−1)·ab + b²    # exact PhiBase
```

(from `2·cos(72°) = φ − 1`). Lets us write `phiBaseSign(p.sub(q).magSquared() − 1)` to test "is this distance strictly less than the short edge?" — exact, no float, no tolerance.

## Don't mix coordinate systems for legality

Until late in the day, the canvas was a Cartesian rectangle `{x, y, w, h}` and the perimeter heuristic kept comparing edge midpoints' Cartesian xy against it. That always degenerates into "tolerance" code. The fix: **define the canvas in the same basis as the positions.**

The first cut used the (a, b) bounding box itself:

```
target = { aMin, aMax, bMin, bMax }   # PhiBase values, in (e₀, e₇₂) basis
```

In Cartesian this is a *parallelogram* (tilted to the right because the basis isn't orthogonal). It worked, but it's a *2-fold* shape on a *5-fold* lattice — the boundary fights the lattice along the two non-aligned corners.

## The breakthrough: pentagonal boundary

The shape that *agrees* with the lattice is a **regular pentagon** centred on the seed. Five half-plane constraints, one per outward normal at 36°/108°/180°/252°/324° (the odd-k entries of `UNIT_DISP[]`). The pentagonal canvas matches the tiles' 5-fold symmetry, so the boundary stops fighting the fill — the WFC produces beautifully pentagonal patches and stalls only at the natural radial limit.

```
target = { center: PhiPoint2D, apothem2: PhiBase, apothem2Overhang: PhiBase }
```

(The `2` in `apothem2` is a *doubling*, not an index — see below.)

### Dot product, exact in Z[φ]

Half-plane tests need `p · d` for arbitrary directions. The Cartesian dot in our basis carries a `cos(72°) = (φ−1)/2`, which would leave us with denominators. **Double everything** and the comparison stays in Z[φ]:

```
2(p · q) = 2(a·a' + b·b') + (φ−1)·(a·b' + a'·b)
```

implemented as `PhiPoint2D::twoDot(other)`. Each pentagon side stores its *doubled apothem* threshold, and `phiGreater(rel.twoDot(d), apothem2)` is a single PhiBase sign test — exact, no float.

### Pentagon corners (SVG only)

For rendering, the 5 corners sit at `R · UNIT_DISP[2k]` for k=0..4, with circumradius `R = apothem · 2/φ = 2(φ−1)·apothem` — clean PhiBase. For `apothem = 4` you get `R = PhiBase(8, -8) = 8φ − 8 ≈ 4.944`. `toCartesian()` only at draw time.

## The heuristic stack we ended up with

`Assembly.step()` picks an edge + a placement using a lexicographic chain:

1. **Edge-tier**: open edges whose **midpoint** is strictly inside the canvas come first; outside-midpoint edges only get processed when the inside pool is exhausted. (Without this, the chain keeps marching outward.)
2. **Inside-vertex** (relaxed): each candidate placement's new C must be inside the canvas with a **1-edge overhang allowed**. Decoupling "where we process" (strict) from "where C may land" (relaxed) prevents the perimeter from stalling.
3. **No sub-scale gap**: reject any placement whose new C lies strictly closer than 1 to *any* existing vertex (squared-distance test in PhiBase). This avoids creating holes that only a φ⁻² tile could fill (the "small T region" Jim spotted in `sshot2.jpg`).
4. **Edge closure preference**: maximize how many existing open edges this placement closes (1 = parent, +1 each for B→C and C→A if they already exist as open edges). Closing 3 ⇒ 0 new edges; closing 2 ⇒ 1 new edge; closing 1 ⇒ 2 new edges. Strongly biases the fill toward closing local holes rather than sprawling.
5. **Min-entropy + random**: tie-break by fewest surviving placements at the chosen edge, then uniform random among them.

## Deferred (out of scope for v1)

- **Scale-step / Robinson deflation**. When a vertex word implies a 1/φ² tile would fit (e.g. three Gs converging with a residual T-shaped hole), descend a rung and place the smaller tile. Currently we just reject the placement that would create the gap (heuristic #3 above).
- **Strict Penrose cyclic vertex words**. `static/wfc/vertexWords.json` uses *multisets* (loose) for legality. The strict tilings need cyclic words (7 canonical types: Sun, Star, Ace, Deuce, Jack, Queen, King) — admit fewer placements, eliminate non-Penrose periodic patches.
- **Backtracking**. `step()` returns `'contradiction'` on a dead-end; no rewind.

## Diagnostic conventions

`Assembly.diagnose()` walks every open edge with the same enumeration as `legalPieces()` but accumulates *rejection reasons* per candidate (`wordA / wordB / wordC / satBC / satCA / tooClose / overlap / outsideCanvas / accepted`). The puzzle page prints a per-step rejection histogram and per-edge breakdowns of "dead" open edges (where every candidate was rejected). When the fill stalls, this is the first place to look — the dominant reason in the histogram tells you which heuristic is doing the work, and which to relax if you want more fill.

## tileScale — one PhiBase, four sites

The lattice unit is parameterised by a single `tileScale: PhiBase` on the Assembly (default `PhiBase(0, 1) = 1`). Threading it through four spots is enough to drop a φ-rung (`tileScale = PhiBase(1, -1) = 1/φ`) — no other changes:

1. **`classifyDisplacement(disp, tileScale)`** — compares against `UNIT_DISP[k].scale(tileScale)` and `LONG_DISP[k].scale(tileScale)` rather than the canonical tables.
2. **`buildSeed(kind, dir, tileScale)`** — multiplies each of the seed's displacements by `tileScale`.
3. **`computeC(A, dir, angle, lenShort, tileScale)`** — multiplies the placement displacement by `tileScale`.
4. **`strictlyTooCloseToVertex(cand, other, thresholdSq)`** — threshold is `tileScale²` instead of `1`. This is the *critical* one: at finer rungs, two vertices at separation `1/φⁿ` are legitimate neighbors, not a sub-scale-gap signal.

`makeEdge(v0, v1, scale, tileScale)` carries the parameter so callers (both `buildSeed` and `placePlacement`) can wire it through. There's a single `@tileScale` on the Assembly, sourced from `target.tileScale`.

Each rung down is `tileScale.mul(PhiBase(1, -1))`: `1 → 1/φ → 1/φ² → ...`. The canvas geometry (apothem, pentagon corners) is independent — it lives in the same Cartesian frame as the lattice, so smaller tiles just means more of them fit.

## Entropy vs. deflation

A practical compass for "smaller tiles":

- **Deflation** is deterministic. Each placed tile gets replaced by a fixed sub-tile pattern. The output's Kolmogorov complexity is bounded by the input's. **Zero new bits.** Useful for visualisation/zoom but doesn't ask the WFC to do any new work.
- **`tileScale` at the WFC layer** is generative. Every placement at the finer rung is still a fresh choice from a non-trivial superposition, so each one *adds* bits to the final tiling. `~φ² ≈ 2.6×` more decisions per fill, more total possible tilings.

Jim's principle: *we want more entropy, not less*. So when adding "smaller triangles," the architectural test is whether each new tile is a free choice (WFC at a finer rung) or a determined sub-piece (deflation). Pick the former for actual variety.

## Page polish

- **`Run WFC` animates** (one placement per `setTimeout(0)` tick) so the SVG paints between tiles. Cheap, no `requestAnimationFrame` needed. Loop bails on any non-`'progress'` `step()` result or when `status` is no longer `'running'` (so `Reset` mid-run halts cleanly).
- **Three visibility checkboxes**: fill (colored interiors + T/G labels), edges (strokes), vertices (dots). All independent. The wireframe view (fill off, edges on) is the clearest pattern reader; the "just vertices" view makes the 5-fold radial density immediate.

## Portable idiom — the /2-doubling trick

Half-integer cosines (`cos(72°) = (φ−1)/2`, `cos(36°) = φ/2`, `cos(108°) = -(φ−1)/2`, `cos(144°) = -φ/2`) threaten to leak rationals into `Z[φ]` whenever they appear as a coefficient. The standard fix:

**Store the doubled quantity and compare against doubled thresholds.**

In 2D this is `PhiPoint2D::twoDot(other)` giving `2(p · q) = 2(a·a' + b·b') + (φ−1)·(a·b' + a'·b)`, stored vs. `apothem2 = 2·apothem`.

For 3D the same pattern lands the moment angle tests at dodec dihedrals show up. Dihedral cosines for the regular dodec/icos involve `1/√5`, but their *doubled* versions stay in `Z[φ]`. Recommend reaching for `twoFoo` over `foo / 2` whenever a denominator threatens to appear — keep everything as Z[φ] integers and reason in integer comparisons.

## Pattern — picked the right primitive three times now (it's a principle)

Three unrelated tasks in this codebase have hit the same wall and had the same fix: **when something fights the lattice, ask what the lattice's natural shape is and use that instead.**

- *Teapot hull (3D)* — *surface* representation. Surface-growth via `goldenApexCandidates` kept hitting hole-closure problems until Jim suggested "tile it like Minecraft, with cubes." Switching to a **volumetric** representation (cube cells, golden-rhombohedron cells, hut cells) made the hull-construction trivial — see `GPT/floater-and-visuals.md`'s closing note about huts.
- *WFC (2D)* — *coordinates*. My Cartesian-xy attempt kept hitting tolerance/sign-of-zero problems until Jim said "you already have the canvas in PhiBase coordinates — use those." Switching to the **(e₀, e₇₂) basis** made vertex identity, edge-direction tagging, and canvas-inclusion all exact.
- *WFC (2D)* — *boundary shape*. A rectangle isn't a neutral container; it's an *active constraint that fights the 5-fold lattice*. The two NE/SW corners hosted every dead spot the perimeter heuristic ran into. Switching to a **regular pentagon** (5 half-plane PhiBase tests, normals at `UNIT_DISP[1, 3, 5, 7, 9]`) instantly let the lattice's 5-fold symmetry sit inside a 5-fold container. The fill became visibly self-similar and the heuristic dead-spots vanished.

Three instances elevates this from a coincidence to a checkable principle. Concrete diagnosis:

> *If you're adding epsilons to a geometry test, picking arbitrary x/y axes, or watching a "neutral" shape (rectangle, sphere) generate constraint dead spots in a φ-lattice context — **the representation is wrong**. Find the lattice's natural shape and use that.*

Applies equally to coordinates, primitive (surface vs volume), and boundary shape.

## Mixed-scale deflation — the easier half remains

`tileScale` handles **single-rung whole-build** scaling: every tile at the chosen φ-rung. The remaining work for **mixed-scale tiles in one build** (a small T filling a hole the big tiles couldn't) is smaller than it sounds:

- The `Edge` class already has a `scale: int` (φ-power tag) field, currently always 0. No new data model.
- `tryPlacement` would consult the scale of the seed edge to pick the matching scale for the new piece.
- Vertex word legality would need to be parameterised by the scale each angle came from (the closed multiset becomes per-scale).

Single-rung was the architectural step. Mixed-scale is a feature implementation that the existing infrastructure absorbs.
