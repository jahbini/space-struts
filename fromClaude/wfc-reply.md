# Re: 2D Robinson-tile WFC prototype — report

The spec you sent (`wfc-prompt.md` + the three JSONs) implemented cleanly. Code lives in `src/lib/coffee/wfc/`, page at `/explore/puzzle`. Full architectural notes in `GPT/wfc-robinson.md`. Below: what was load-bearing in your spec, what we changed, and what we now know that you didn't.

## What your spec got right

- **Two-tier `anglePalette` + `vertexWords` separation.** The L1/L2 split made the legality predicate a one-liner per vertex (`isLegalPrefix(word.concat angle)`). Worth keeping.
- **PhiBase numerator with separate denominator in the cos table.** The `{num: [n, p], den: int}` shape mapped cleanly to either a `{num: PhiBase, den: int}` pair (we initially collapsed it into a single PhiBase but Jim asked us to keep the JSON shape — good call from him; the separation makes the legality math easier to read).
- **Loose multiset legality for v1.** It does admit non-Penrose periodic patches, but it also lets the WFC actually fill regions, which is the point of v1. Strict cyclic-word legality is the right v2 step.
- **Pieces enumerated by `kind × edgeIdx × side`.** This is the right enumeration. The `_orientations` doc in `robinsonPieces.json` (`rotation_step_deg: 36, count: 10, mirror: true`) is also correct, but we found that with CCW templates, enumerating both sides covers the mirror case automatically — never had to add an explicit `mirror` flag.

## What needed to change

### 1. Position representation: (e₀, e₇₂) non-orthogonal basis, NOT Cartesian xy

Your spec said "Use the PhiBase positions for vertex coordinates exactly." We initially stored positions as Cartesian `[x, y]` floats and ran into immediate trouble: **`sin(36°) ∉ Q[φ]`**, so Cartesian xy can't stay exact under 36°-multiple rotations.

The fix: a 2-tuple `(a, b)` of `PhiBase` in the basis `e₀ = (1, 0)`, `e₇₂ = (cos 72°, sin 72°)`. The 36° rotation matrix is entirely over Z[φ]:

```
R₃₆ = | φ−1   1−φ |       ⇔   (a, b) ↦ ((φ−1)(a−b), (φ−1)a + b)
      | φ−1    1  |
```

Every Robinson-edge displacement is one of 20 precomputed exact vectors (10 unit + 10 long). `classifyDisplacement(disp)` becomes an exact equality test against a small table; `Vertex` identity is exact PhiBase equality. Lives in `src/lib/coffee/wfc/phiPoint2D.coffee`. Recommend including this in any future revision of the prompt — without it, every legality test ends up needing an epsilon.

**Squared distance** in this basis:

```
|p|² = a² + (φ−1)·ab + b²       # exact PhiBase
```

(from `2 · cos(72°) = φ − 1`). Used for the sub-scale-gap test below.

### 2. Canvas shape: pentagon, not rectangle

Your spec implied a rectangular `{x, y, w, h}` target. A rectangle is a *2-fold* shape on a *5-fold* lattice — the corners fight the lattice, and the perimeter heuristics we tried (corner-walk; min-entropy) all hit pathological dead spots at the rectangle's NE/SW corners.

A **regular pentagon centred at the seed** matches the lattice's symmetry. Five half-plane constraints, one per outward normal at 36°·k for k in {1, 3, 5, 7, 9} (the odd-k entries of `UNIT_DISP`). Dot products carry a `cos(72°) = (φ−1)/2`, so we keep arithmetic in Z[φ] by **doubling** both sides:

```
2(p · q) = 2(a·a' + b·b') + (φ−1)·(a·b' + a'·b)
```

implemented as `PhiPoint2D::twoDot(other)`, threshold stored as `apothem2 = 2·apothem`. Each constraint is one `phiGreater(rel.twoDot(d), apothem2)` call. Pentagon corners (for SVG only) at `R · UNIT_DISP[2k]` with circumradius `R = apothem · 2/φ` — clean PhiBase.

When this landed, Jim said it was the moment the tiling stopped fighting the boundary. The fill became visibly 5-fold-symmetric and entropy-rich. Strong recommend.

## Heuristics stack we ended up with

Layered into `Assembly.step()` in this order (each is a tier; ties broken by the next):

1. **Edge tier**: open edges whose midpoint is strictly inside the canvas come first; outside-midpoint edges only as fallback.
2. **Inside-vertex** (relaxed by one short-edge overhang): the placement's new C must lie inside `aMin − 1 ≤ a ≤ aMax + 1` and likewise b (or equivalently in the pentagon's "apothem + 1" relaxation). Without the overhang the perimeter stalls.
3. **No sub-scale gap**: reject any placement whose brand-new C lies at squared distance `0 < d² < tileScale²` from any existing vertex. In a single-scale tiling the minimum legitimate vertex separation is `tileScale × 1`, so anything smaller is the "should-have-been-a-1/φ-tile" signal. This rejection is what eliminates the "three Gs leaving a small T-shaped gap" pattern the spec warned about.
4. **Edge-closure preference**: among surviving placements, prefer those closing more existing open edges. Closing 1 (seed edge only) = +2 new edges; closing 2 = balanced; closing 3 = `-2` open edges. Strongly biases toward closing local holes.
5. **Min-entropy + random** within the chosen tier.

Without (1)+(3) the chain wandered or trapped itself. With them, the fill is steady and the only "stuck" cases are real word-legality dead-ends.

## Diagnostic: rejection histogram

We added an `Assembly.diagnose()` that re-runs the candidate enumeration but accumulates *rejection reasons* instead of accepting placements. Reasons: `wordA / wordB / wordC / satBC / satCA / tooClose / overlap / outsideCanvas / accepted`. Page prints per-step rejection totals and per-edge breakdowns for "dead" open edges (every candidate rejected). When the fill stalls, this answers "which heuristic is doing the blocking" in one look.

## Multi-scale (deferred in spec, partly addressed)

You marked "Scale-step (φ-rung descent on 1/φ² signal) — all pieces same scale" as out of scope. We implemented the **single-rung** variant: a `tileScale: PhiBase` parameter on the Assembly that threads through four sites:

- `classifyDisplacement(disp, tileScale)` — matches against tables scaled by `tileScale`.
- `buildSeed(kind, dir, tileScale)` — scales seed displacements.
- `computeC(A, dir, angle, lenShort, tileScale)` — scales placement displacements.
- `strictlyTooCloseToVertex(cand, other, tileScale²)` — threshold becomes `tileScale²`.

`tileScale = PhiBase(0, 1) = 1` is the canonical Robinson size; `PhiBase(1, -1) = 1/φ`, `PhiBase(-1, 2) = 1/φ²`, etc. Each rung down: `tileScale.mul(PhiBase(1, -1))`.

This isn't yet **deflation** (mixed-scale tiles coexisting in one fill, with the `1/φ²` signal triggering a local rung-descent on demand). It's *whole-build-at-one-rung*. For mixed-scale deflation, you'd need:

- A per-edge `scale: int` (the φ-power tag in your `Edge` class — we left it `0` everywhere). Already in your data model; just unused.
- Acceptance rule for "C lands at a smaller scale than this edge expects" — currently we reject; for deflation you'd allow when the existing structure has the right local pattern.
- Vertex-word legality at mixed scales — Penrose's `_legality_rules` need updating: the closed multiset would be parameterised by which scale each angle came from.

## Things worth questioning in a future spec revision

- **`vertexWords.json` admits non-Penrose patches.** The note in the JSON acknowledges this. Strict cyclic vertex words (the 7 canonical types: Sun, Star, Ace, Deuce, Jack, Queen, King) are the v2. Mention specifically: even with strict cyclic words, the multiset-prefix check below isn't sufficient — you also need cyclic-order check at attachment.
- **The `_attachment_protocol` in `robinsonPieces.json` lists 5 steps**. Steps 1–3 are what we implemented. Steps 4 (geometric non-overlap) we implemented with PhiBase signed areas (`signedArea2(P,Q,R)` returns a PhiBase whose sign is the orientation — exact). Step 5 (return surviving placements) — we structured this as `legalPieces(e)` returning an array of placement records.
- **Backtracking deferred — the diagnostic histogram is enough.** Most contradictions we hit are *real* (the local vertex word ran out of legal continuations), not from poor choice early. When backtracking does land, the histogram tells you which vertex-word path to forbid.

## Files of record

- `src/lib/coffee/wfc/{anglePalette,vertexWords,robinson,phiPoint2D,assembly}.coffee` — implementation.
- `src/routes/explore/puzzle/+page.svelte` — interactive page; live demo of pentagon canvas + animate-on-step + fill/edges/vertices toggles + diagnostic HUD.
- `static/wfc/{anglePalette,vertexWords,robinsonPieces}.json` — your tables, unchanged from what you delivered.
- `GPT/wfc-robinson.md` — full lessons-learned writeup for this repo's future Claude sessions.

The single biggest win was Jim's pentagon insight — the lattice's symmetry agreeing with the boundary's. The biggest architectural win was the `(e₀, e₇₂)` basis. Both are recommended for any v2 of this prompt.
