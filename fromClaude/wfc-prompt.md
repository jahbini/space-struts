# Task: 2D Robinson-tile Wave Function Collapse prototype

Build a working prototype that fills a 2D rectangular canvas with Robinson triangles
(golden triangle + golden gnomon) using a Wave Function Collapse algorithm.
This is the first 2D step of a 3D SpaceStruts construction system. The 3D version
will come later — for now we are validating the WFC adjacency machinery in flat 2D
where defect = 0 at every interior vertex.

## Existing infrastructure (do not duplicate)

- `PhiBase` arithmetic in `$lib/coffee/phiBase.coffee` (or equivalent).
  PhiBase constructor convention: `new PhiBase(p, n) = p·φ + n`.
- `SixPhiVector` in `$lib/coffee/sixPhiVector.coffee`. Not directly needed for 2D
  but the same exact-arithmetic discipline applies.
- Everything in Z[φ] or Q[φ]; NO floating-point at the legality-check layer.
  Float is allowed only for the final SVG render coordinates.

## Geometry

Two Robinson piece types:
- `T` (acute golden triangle) — angles 36°/72°/72°, edges φ/φ/1
  (the two long edges flank the 36° apex; the short edge is opposite the apex).
- `G` (golden gnomon, obtuse) — angles 108°/36°/36°, edges 1/1/φ
  (the two short edges flank the 108° apex; the long edge is opposite the apex).

Each piece has 3 vertices and 3 edges. Use the PhiBase positions for vertex
coordinates exactly; convert to float only for SVG output. The unit scale is up to
you — pick whatever makes the math easiest; recommend edge `1` = PhiBase(0, 1).

## Data files (provided)

Three JSON files in `static/wfc/`:
- `anglePalette.json` — the L1 cosine table (angle → PhiBase rational).
- `vertexWords.json` — the L2 legal closed-vertex multisets for 2D
  (cyclic words summing to exactly 360°).
- `robinsonPieces.json` — the two piece types with their vertex angles and
  edge lengths.

Load these at module init. Do not hardcode.

## Core data structures

```coffee
class Vertex
  constructor: (@pos) ->          # pos: 2D point as [PhiBase, PhiBase]
    @word = []                    # cyclic angle sequence (CCW), degrees as integers
    @status = 'open'              # 'open' | 'closed'

class Edge
  constructor: (@v0, @v1, @scale) ->  # endpoint Vertex refs + φ-power (integer)
    @left = null                  # Piece on CCW side
    @right = null                 # Piece on CW side
  isOpen: -> not @left or not @right

class Piece
  constructor: (@kind, @verts, @edges) ->   # kind: 'T' | 'G'
                                # verts: [Vertex, Vertex, Vertex] in CCW order
                                # edges: [Edge, Edge, Edge] matching verts

class Assembly
  constructor: (@target) ->     # target: {x, y, width, height} rectangle in float
    @vertices = []
    @edges = []
    @pieces = []
    @openEdges = new Set()
```

## Legality predicate (the heart of WFC)

A candidate piece placement attaches a piece to an open edge `e` with endpoints
`v0`, `v1`. The candidate brings two new vertex angles — one at each endpoint —
plus a third new vertex on the opposite side.

The placement is LEGAL iff:

1. `v0.word + candidate.angleAt(v0)` is a prefix of some `vertexWords.json` entry
   (or completes one exactly).
2. Same for `v1`.
3. The piece does not overlap any existing piece (geometric test, exact in PhiBase).
4. No two open edges of the new piece coincide with two non-matching open edges
   already in the assembly.

When a vertex's word sum reaches exactly 360°, set `status='closed'` — no further
attachments at that vertex.

When a word sum would EXCEED 360°, reject the placement.

## WFC loop

```
seed: place one piece (T, oriented arbitrarily) near the canvas center
loop until isComplete():
  e = arg min over openEdges of |legalPieces(e)|
  if legalPieces(e) is empty:
    return CONTRADICTION  (no backtracking in this prototype — just report)
  pick = random.choice(legalPieces(e))   # uniform for now; weights later
  place pick at e
  update openEdges
```

Termination: `isComplete()` iff every open edge has its midpoint OUTSIDE the
target rectangle. Overhang is accepted — pieces that cross the rectangle boundary
are fine; we only require the rectangle's interior to be covered.

## Deliverables

1. `src/lib/coffee/wfc/anglePalette.coffee` — loads `anglePalette.json`,
   exports `cosOf(angleDeg)` returning the PhiBase rational.
2. `src/lib/coffee/wfc/vertexWords.coffee` — loads `vertexWords.json`,
   exports `isLegalPrefix(word)` and `isClosed(word)`.
3. `src/lib/coffee/wfc/robinson.coffee` — Vertex, Edge, Piece classes.
4. `src/lib/coffee/wfc/assembly.coffee` — Assembly class with WFC step loop.
5. `src/routes/wfc/+page.svelte` — interactive page: takes rectangle dims,
   runs the WFC, renders the result as SVG with T pieces in one color
   and G pieces in another. Single "Run" button; print piece count, vertex
   count, open-edge count, and CONTRADICTION status.

## Out of scope for this prototype

- Backtracking on contradiction (just report and stop)
- Strict Penrose matching rules (we use the looser multiset legality only)
- Weighted picks based on geometric intent
- Scale-step (φ-rung descent on 1/φ² signal) — all pieces same scale
- 3D anything

## Working style

- One file at a time, then ask for review before moving to the next.
- If a piece of `vertexWords.json` looks geometrically wrong during testing,
  flag it — the table is provisional.
- Direct execution; no confirmation prompts.
- Keep PhiBase arithmetic for legality; floats only at SVG render.
