# Three PhiBase turtles

Three turtle implementations live in this repo. They target different
lattices and produce different figures. Pick the one that matches the
geometry you want to draw.

| Directory | Turtle | Lattice | Min turn | File ext |
|---|---|---|---|---|
| `figures/turtle/phiTurtle.coffee` | Legacy coffee | 2D Z\[ω\] | 36° | `.txt` |
| `tcl-haf/` | HafBase (TCL) | 2D Z\[ω\] | 36° | `.haf` |
| `tcl/` | Icosahedral (TCL) | 3D Q(φ)³ / 6-slot SixPhi | 72° (with a 36° trick, see G) | `.tcl` |

The two 2D turtles produce equivalent geometry (any figure buildable in one
is buildable in the other); pick by preference. The 3D turtle is for
dodecahedron/icosahedron figures where the icosahedral group I acts.

## Running

```bash
coffee figures/turtle/phiTurtle.coffee <walk.txt>       # writes walk.svg
tclsh  tcl-haf/run.tcl [--svg <out>] <walk>              # HafBase
tclsh  tcl/run.tcl     [--svg <out>] <walk>              # icosahedral
```

`make figures` builds every `*.txt` / `*.haf` / `*.tcl` in `figures/turtle/`
through the right pipeline and finishes with Inkscape → PDF.
`make verify` runs the TCL acceptance walks and reports CLOSED / OPEN /
invariant violations.

## Common ground

All three turtles share the following. Only the differences are noted in
the per-turtle sections below.

### State
- Position — exact lattice point (never floating-point).
- Heading — a direction on the lattice.
- Pen — down (draws segments) or up (moves silently).
- Marks — named positions saved by `mark <name>`, restored by `goto <name>`.
- Stack — `gsave` pushes turtle pose, `grestore` pops. Marks and the
  accumulated drawing are global (`gsave/grestore` does not undo strokes).

### Motion
- `short` — one short unit along the heading (length 1).
- `long`  — one long unit along the heading (length φ).
- `back`  — one short unit against the heading. Heading unchanged.
- `pendown` / `penup` — toggles drawing.

### Blocks and macros
- `repeat n { … }` — run the block n times.
- The TCL turtles also accept coffee-style `repeat n [ … ]` — brackets are
  rewritten to braces at load.
- `name = { body }` — defines a proc named `name` (via a custom `unknown`
  handler). No parameters. Late binding: redefining a name propagates to
  callers.

### Safety
Both TCL turtles run walks inside a `-safe` sub-interpreter. `exec`,
`open`, `file`, `source`, and other I/O commands are hidden. The only
master aliases exposed are `puts` (trace output) and `write_svg`
(path + text only, used by the `svg` command).

### Report
Every run ends with a report: trace of commands, final position/heading,
and CLOSED-or-OPEN vs the start position. TCL turtles also print the
final floor for the icosahedral case.

---

## HafBase turtle (`tcl-haf/`)

2D turtle on the 36° lattice. Every heading is one of ten integers 0..9
(units of 36° counterclockwise). Position is a pair of PhiBase values
`(a, b)` in the (e₀, e₇₂) basis, so every reachable point is an exact
Z\[ω\] lattice element. Verified at load: R₃₆¹⁰ is the identity of the
lattice.

### Vocabulary in addition to the common set

```
left  [k]      turn k · 36° counterclockwise (k defaults to 1)
right [k]      turn k · 36° clockwise
home           reset position to origin, heading to 0
```

### Rendering

```
label          request an address label at the current vertex
above          place subsequent labels above the point (default)
below          place subsequent labels below the point
scalephi n     multiply rendered lengths (and label size, arrow, etc.) by φⁿ
xonly          show only the first PhiBase in each label
svg <path>     emit an SVG image to <path>  (writes via the master alias)
```

The `--svg <out>` command-line flag auto-invokes `svg <out>` at end of walk,
so the walk file itself does not need an explicit `svg` call.

### Acceptance walks

`tcl-haf/walks/{pentagon,gnomon,triangle}.txt` — each closes exactly on
the lattice. The golden triangle (36-72-72) is the one that cannot be
walked in the icosahedral turtle.

---

## Icosahedral turtle (`tcl/`)

3D turtle on the dodecahedron. State lives in a "SixPhi" 6-tuple: slot i
is the exact PhiBase dot product with the i-th face normal in
`basisNormals3Phi` (A, B, C, D, E, F). Every turn is a signed
permutation of the six slots, taken from `tables.tcl` (generated).

### Ground truth (from `tools/genTables.coffee`)

- Six face axes A B C D E F, matching geoPhi's basisNormals3Phi.
- 60-element rotation group I: 1 identity + 24 face 5-folds + 20 vertex
  3-folds + 15 edge 2-folds. Every 60×60 product stays in the group.
- 10 legal vertex triples per §2 of the design spec:
  `ABC ABD ACE ADF AEF BCF BDE BEF CDE CDF`.
- Chirality: dodecahedron1 vertices dotted with basis normals yield only
  `{±φ², ±1/φ}` with exactly three φ² slots; dodecahedron2 (mirror
  cyclic pattern) fails the same check.

### Vocabulary in addition to the common set

**World-axis 5-fold turns:**
```
A k     turn about world axis A by k · 72°  (k in {±1, ±2}; k=0 is identity)
B k     ... likewise for B .. F
```

**Vertex 3-fold turns (10 legal triples only):**
```
ACE k   turn about the ACE vertex axis by k · 120°  (k in {±1})
ABC k   ... likewise for the other 9 legal triples
```

**2-fold edge flips (15):**
```
AB      2-fold flip whose two axis-fixed slots are A and B
AC, AD, ... EF   (all 15 pairs)
```

**Floor and G:**
```
G       (no args) — returns the signed floor axis as a string, e.g. "A+", "C-"
G k     turn k · 36° about the (signed) floor axis
```

`G k` semantics (per the Fable 5 spec patch):
- Even k: apply the group face-rotation about the floor by k/2 face-steps.
- Odd k: shift k to (k−5) which is even, apply that face rotation, then
  negate the heading slot-wise. Valid because the ten in-plane heading
  directions on the perp-to-floor plane satisfy `dir(j+5) = −dir(j)`.
- Floor is not changed by G (its axis is fixed under R about itself).

The 3D turtle cannot form arbitrary 36° rotations of the whole space —
those aren't in the icosahedral group. `G k` gives you 36° effects on
the heading only, valid on any single face plane.

**Floor**

Every rotation updates the floor as well as the heading:
- Face rotation about the floor axis leaves the floor slot fixed.
- Other rotations move the floor to a different signed axis.
- The invariant `heading · floor = 0` must hold after every turn.
- `checkfloor off` disables the invariant assertion (default: on).
- `home` resets floor to `+A`.

### Rendering
```
viewaxis iso   isometric projection along (1,1,1)/√3  (default)
viewaxis A     face-on view of face A+
svg <path>     emit SVG projected through cartesian3Phi + viewaxis
```

`--svg <out>` on the command line auto-invokes `svg <out>` at end.

### Acceptance walks

`tcl/walks/`:
- `pentagon.txt` — §6.1 pentagon closes on face A+.
- `stellation.txt` — §6.4 pentagram closes with A ±144° turns.
- `corner-g.txt` — §6.2 three pentagons around the ACE vertex via G; floor
  returns to A+ at the end.
- `floor-invariant.txt` — §6.3 mixed random walk; every turn keeps the
  invariant.
- `gnomon.txt`, `gnomon-solo.txt` — §6.5 gnomon stencil closes; macros
  and `gsave/grestore` behave.
- `station.txt` — §6.6 `base1` macro lands at the same fixed point
  regardless of prior state.
- `golden-triangle.txt` — 36-72-72 triangle closes via the odd-k G trick.
- `smoke.txt`, `mechanics.txt` — pen/mark/goto/gsave sanity walks.

---

## Legacy coffee turtle (`figures/turtle/phiTurtle.coffee`)

Same 2D lattice as the HafBase turtle, older implementation. Vocabulary is
essentially the same. Still owns figures that were built before the TCL
port (`growing.txt`, `home.txt`, `reflection-example.txt`, `robinson.txt`).
Migrate a walk to HafBase by renaming `.txt` → `.haf`; the Makefile will
route it through `tcl-haf/run.tcl` on the next build.

---

## Makefile summary

```
make figures      # build all *.txt / *.haf / *.tcl → SVG → PDF in figures/turtle/
make verify       # run all TCL acceptance walks and grep CLOSED / OPEN / violated / error
make main.pdf     # LaTeX book build (depends on figures)
make cleanfigs    # remove generated SVGs and PDFs
make clean        # remove LaTeX aux files and main.pdf
```

Environment overrides: `INKSCAPE=…`, `COFFEE=…`, `TCLSH=…` if the default
paths on this machine ever move.
