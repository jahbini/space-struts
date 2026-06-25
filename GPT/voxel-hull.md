# Voxel hull around an arbitrary 3D object — two parts and a classifier

A reusable technique for wrapping any 3D object in a golden-tile hull. The geometry primitives are fixed (two Robinson tile types and a hut module); the only object-specific work is a cell classifier on a regular cubic lattice.

This is the technique that wrapped the Utah teapot at `/explore/teapot`. The same code works for any meshed object whose surface you can query — just swap the classifier's per-cube test.

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

## The classifier — four rules, in priority order

Object-specific. Tested for the teapot mesh; generalises to any surface that supports the same queries.

A cube `(i, j, k)` is **filled** iff any of:

1. **Center inside.** Ray from origin through `cubeCenter(i,j,k)` hits the teapot mesh beyond the center's distance. The fast bulk-classifier for body interior.
2. **Any corner inside.** Same test on each of the 8 cube corners. Catches features whose *volume* overlaps the cube even when the cube center has slipped just outside the surface — and dually, catches cubes whose neighbours we'd otherwise render through, since the dual case is also picked up.
3. **Contains a teapot mesh vertex.** The cube `(round(x/2s), round(y/2s), round(z/2s))` for each of the mesh's surface vertices. Catches **thin features** smaller than a cube diagonal — spout tip, handle arch, lid stem.
4. **Contains a triangle centroid.** Same lookup for each of the mesh's triangle centroids. Catches features that span between vertices without any vertex landing inside a particular cube.

The first two are about the cube's geometry; the last two are about the mesh's geometry. Both lenses are needed. With all four rules the hull catches every feature representable in the surface mesh.

## What's load-bearing about this design

- **Only the classifier is shape-specific.** Drop the teapot, plug in a different meshed object's `verts`, `tris`, and `radialDistance` function — same code wraps it.
- **The hull is closed by construction.** No edge gluing, no patch-stitching. Whichever cube faces have a filled neighbour stay interior; whichever have an empty neighbour render a hut. The dodec↔cube hinge guarantees the boundary tiles compose.
- **Every tile is an exact T or G** (in PhiBase). No deformation. No interpolation. Rendering is the only place float touches anything.
- **A construction robot doesn't need to know the shape.** Hand it a stock of T and G sticks (two SKUs) and the same lattice; the only signal it needs is the per-cube classifier output. That's a deeply compact instruction stream for a physical robot's hull-around-an-object task — "with only two parts," as Jim put it.

## Trade-offs and known knobs

- **Classifier cost grows as the cube grid refines.** At `n = -4` (cube edge ≈ 0.083), the grid is `~63³ ≈ 250k` cubes, each running 9 ray-mesh tests of ~992 triangles — `~2.2 billion` triangle-ray intersections to classify the volume.

  Optimization knobs available, in increasing implementation cost:

  1. **Bounding-sphere prune.** Skip the ray cast entirely for any cube whose center sits more than `(teapot_bounding_radius + cube_diagonal)` from origin. Cuts work proportionally to the empty volume.
  2. **Mesh spatial hash.** Bucket the teapot triangles into voxels at lookup time; ray cast then tests only triangles in adjacent buckets. Up-front cost; pays back as cube count grows.
  3. **Shared-corner cache.** Adjacent cubes share corners; current code retests each. A `cornerKey → bool` cache does each unique corner once.

  None of these are needed at `n ≤ −3`. Past `n = −4` the classifier will dominate; choose a knob by which is closest to your bottleneck (corner reuse helps when grid is dense; bounding-sphere prune helps when the empty volume is large; spatial hash helps when ray costs dominate).

- **Hull is "stepped," not smooth.** The cubic lattice produces a stair-step silhouette by construction. Refining `n` reduces the step size at the cost of more cubes. To smooth the surface further you'd need either a non-cubic lattice or post-hoc fairing — out of scope here.

- **One cube edge of jitter at the boundary.** The conservative classifier expands the filled region by up to `s` (cube edge) at boundaries — the bumps may sit slightly outside the surface in places. Acceptable for an enclosure; not acceptable for a tight fit.

## Where it lives

- `src/lib/coffee/robotBuildBridge.coffee` — `buildVoxelHull(G, teapotRadialDistance, opts)`. The classifier (`cubeIsFilled`, the feature pass) and hut renderer are both there.
- `src/lib/coffee/teapotMesh.coffee` — exposes `teapotVerts`, `teapotTris`, `teapotRadialDistance(d)`. The feature pass imports `teapotVerts` and `teapotTris` directly.
- `src/routes/explore/teapot/+page.svelte` — wraps the build with the seen.js scene + level controls (`currentN` selects `scale = 0.35 · φⁿ⁺¹`).

## The principle (one more instance of the recurring lesson)

This is the third instance of `GPT/wfc-robinson.md`'s "**match the boundary to the lattice**" rule, in a new shape:

> *Don't try to construct a hull as a continuous surface. Construct it as the boundary of a discrete cellular volume, in a lattice whose unit cell already composes the geometry you want.*

The cube↔dodec hinge means the cubic lattice already composes golden geometry. The classifier is *the entire* shape-specific step. Same lesson as Cartesian-xy → `(e₀, e₇₂)`, rectangle → pentagon, surface-growth → volumetric cells: pick the representation that already contains the structure you want, and shape becomes a parameter rather than a construction job.
