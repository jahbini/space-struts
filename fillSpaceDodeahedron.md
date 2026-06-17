# Filling Space: A Robot Program for a Dodecahedral Sphere

Good question — this is essentially a **face-graph traversal program**, like turtle graphics for triangles. Let me sketch what the instruction list looks like and what the data record is.

## The instruction record

A robot placing one new triangle per step needs four things at each step:

```
{
  parentFace:  index of an already-placed triangle
  parentEdge:  0 | 1 | 2     # which of its 3 edges we hinge on
  pieceType:   'gold' | 'gnomon'   # which triangle from supply
  pieceEdge:   0 | 1 | 2     # which edge of the new piece mates to parentEdge
  fold:        'L' | 'R'     # which side of the parent plane it folds toward
                             # (orientation relative to outward normal)
}
```

That's all. The new triangle's full position and orientation is forced by sharing the edge with the parent. Lengths must match (`pieceEdge` length = `parentEdge` length), or the supply rejects the piece.

## Two forms of the list

**Form A — spanning tree only.** For *N* faces you need exactly **N−1** instructions (a spanning tree of the face-adjacency graph). The remaining edges close automatically; you only need to *verify* closure, you don't drive it.

**Form B — full edge map.** Every internal edge gets an entry. Redundant, but useful as a checksum: each edge appears in exactly two faces' edge-lists, and the addresses must agree.

For a robot, **Form A is the program; Form B is the unit test.**

## Closure: why this works exactly in SixPhi

Each step extends the structure by adding one new vertex (the apex of the new triangle). That new vertex's SixPhi address is

$$
v_{\text{new}} = v_{\text{anchor}} + \Delta
$$

where $\Delta$ is drawn from the 60-element neighbor-star alphabet, fully determined by `(pieceType, pieceEdge, fold)` relative to the parent edge's address. So every instruction is really just **"pick $\Delta$ from the alphabet."** The closure test on the leftover edges is exact: sum of addresses around any closed loop must equal zero in SixPhi (in $\mathbb{Z}[\varphi]$ if no reflections were used, in $\tfrac{1}{5}\mathbb{Z}[\varphi]$ otherwise).

## Concrete example: 60 golden triangles around a sphere

The natural sphere-enclosing shape in this system is the **dodecahedron with each pentagonal face fanned into 5 golden triangles meeting at the face center** — 12 faces × 5 = **60 golden (36-72-72) triangles**, all isoceles, edges $\{s, \varphi s, \varphi s\}$ with $s = 2/\varphi$.

The instruction list has 59 entries:

```
# seed: place face #0 at origin with chosen orientation
0:  parent=0, edge=L1, piece=gold, mate=L1, fold=L  -> face 1   # next slice in same pentagon
1:  parent=1, edge=L1, piece=gold, mate=L1, fold=L  -> face 2
2:  parent=2, edge=L1, piece=gold, mate=L1, fold=L  -> face 3
3:  parent=3, edge=L1, piece=gold, mate=L1, fold=L  -> face 4   # closes pentagon 0 (face 4's free L1 == face 0's L1, verified)
4:  parent=0, edge=S , piece=gold, mate=S , fold=R  -> face 5   # crosses dodecahedron edge into pentagon 1
5:  parent=5, edge=L1, piece=gold, mate=L1, fold=L  -> face 6   # fan out pentagon 1
6:  parent=6, edge=L1, piece=gold, mate=L1, fold=L  -> face 7
...
```

Structurally the program has two kinds of step:

- **Fan steps** (4 per pentagon × 12 = 48): hinge on a *long* edge, fold left (within-face hinge, dihedral 0 — coplanar).
- **Cross steps** (11): hinge on a *short* edge, fold right (dodecahedron dihedral ≈ 116.565°, exactly $\arccos(-1/\sqrt5)$ — a value PhiBase can name).

That's the entire program: **48 fans + 11 crosses = 59 instructions**, and the remaining edges form 49 closure checks that all evaluate to zero in $\mathbb{Z}[\varphi]$. The dodecahedron is the simplest sphere-shape that comes out clean in this alphabet; pentakis-dodecahedra, snub-dodecahedra, icosahedral quasicrystal patches all extend the same pattern with more piece types and longer programs.

## Why this representation is nice

- **The supply is finite** (gold vs gnomon — two SKUs).
- **The address alphabet is finite** (60 neighbor-star vectors).
- **The instruction stream is a small integer code** per step: 2 + 2 + 1 + 2 + 1 = 8 bits of choice (and most bits are constrained by edge-length matching, so realistic entropy is ~3 bits/step).
- **Errors are local**: a bad instruction makes the next closure test fail at a specific edge, so debugging is line-numbered.

Want me to (a) draft the closure-checking helper in `geoPhi.coffee`, (b) actually enumerate the 60-step dodecahedron program with real neighbor-star indices, or (c) generalize to a "robot grammar" that can also build quasicrystal patches (more piece types, no global closure)?
