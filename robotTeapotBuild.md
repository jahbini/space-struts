# Robot Build: φ-Quantized Hull Around the Utah Teapot

A spec for extending `src/routes/explore/playground/+page.svelte` with a
**Robot Build** mode: an animated robot glyph that grows a golden-triangle
shell around a Utah teapot at the origin. The hull is **φ-quantized** — every
vertex lands on a discrete radial shell `φ^k` for some integer `k`, chosen as
the smallest power of φ that strictly encloses the teapot along that direction.

Supersedes the earlier fixed-dodecahedron plan.

---

## 1. What you see

- Playground gains one new button: **`▶ Robot Build`**.
- Clicking it:
  1. Drops the Utah teapot mesh (embedded JSON, see §3) into the scene at the
     origin, muted material so the golden hull reads on top.
  2. Seeds a single golden triangle near the origin (entirely inside the
     teapot).
  3. Spawns a robot glyph — bright tetrahedron — on the seed triangle's first
     open edge.
  4. Every 200 ms: the robot pops one open edge from its frontier queue, asks
     `GeoPhi.goldenApexCandidates` for legal completing apices, snaps to the
     candidate that best matches the φ-shell target along that direction, and
     places the new triangle. The robot then hops to the next open edge.
  5. Build terminates when the frontier is empty (every edge closed against
     another triangle) or a safety budget (200 steps) is reached.
- Second click while running becomes **`■ Stop`** (cancels the timer, leaves
  partial structure visible).
- Drag still rotates the whole scene.

Existing playground UI is untouched.

---

## 2. File changes

| File | Change |
|---|---|
| `src/lib/data/teapot.json` *(new)* | Embedded Utah teapot mesh: `{verts: [[x,y,z],...], tris: [[i,j,k],...]}`. ~30 KB. |
| `src/lib/data/build-teapot-json.mjs` *(new)* | One-shot Node script that produces `teapot.json` (run once, committed alongside). Documents provenance. |
| `src/lib/coffee/teapotMesh.coffee` *(new)* | Loads `teapot.json`, exports `teapotSeenModel()` and `teapotRadialDistance(dir)` — the ray-from-origin → mesh distance used for φ-snapping. |
| `src/lib/coffee/robotBuild.coffee` *(new)* | Pure logic: frontier queue, φ-shell snapping, apex selection, state machine. No DOM, no Svelte. Importable headless for tests. |
| `src/routes/explore/playground/+page.svelte` | Add: imports, `mdl3` model for the build, `robotState` reactive, `startRobot()` / `stopRobot()` / `robotTick()`, the toggle button. Existing scene logic untouched. |

`mdl3` is parented to `mdl1`'s transform so drag rotates the build together
with the rest.

---

## 3. Teapot mesh ingestion (3a — embedded JSON)

- Run `build-teapot-json.mjs` once locally to generate `teapot.json`:
  - Source: three.js `TeapotGeometry` (BSD-3 license) at `segments=4`,
    bottom-on / lid-on. ~530 triangles, ~30 KB after trimming to 4-digit floats.
  - Center the teapot at origin and normalize so its bounding sphere has radius
    1 (so φ-shells are interpretable directly: `φ^0 = 1` sits at the bounding
    sphere, anything beyond is "out further than the teapot").
- Output schema:
  ```json
  { "verts": [[x,y,z], …], "tris": [[i,j,k], …], "boundingRadius": 1.0 }
  ```
- `teapotMesh.coffee` imports the JSON and exposes:
  - `teapotSeenModel(material)` → `seen.Model` built from
    `seen.Shapes.path([v0,v1,v2])` per tri.
  - `teapotRadialDistance(dirCart)` → float `r` such that the ray
    `t · dirCart` first hits the mesh at `t = r`. Implementation: Möller-Trumbore
    ray-triangle test against all tris, return min positive hit.

---

## 4. The φ-shell quantization

Precompute the radial shells once:

```coffee
PHI = (1 + Math.sqrt(5)) / 2
SHELLS = (PHI ** k for k in [-4..6])   # 0.146, 0.236, 0.382, 0.618, 1, φ, φ², …
```

**Snap rule (locked):** smallest `φ^k ≥ r_teapot(dir)`. Strict enclosure.

```coffee
phiShellFor = (dir) ->
  r = teapotRadialDistance(dir)
  return shell for shell in SHELLS when shell >= r
  return SHELLS[SHELLS.length - 1]   # safety cap
```

The structure's vertices sit at radial distance ≥ teapot surface everywhere.
The shell index `k` varies per direction: the spout pushes its local vertices
to larger `k`; the body sits on smaller `k`. The k-pattern across the hull is
a fingerprint of the teapot's silhouette.

Optional exact variant: compare `r²` (PhiBase) against `φ^(2k)` (also PhiBase)
to do the comparison without floats. Worth doing once we know the radius
comes back as PhiBase.

---

## 5. Frontier-driven growth (locked)

State:
```coffee
robotState =
  vertices: [<seed vertex 1>, <seed vertex 2>, <seed vertex 3>]
  triangles: [<seed>]
  frontier: [<edge 0>, <edge 1>, <edge 2>]   # the 3 seed edges
  byEdgeKey: {…}                              # edge → count of incident tris
  faceIndex: 1
  state: 'idle' | 'running' | 'done'
```

Each tick:

1. **Pop** an open edge from `frontier` (FIFO so growth is breadth-first,
   producing a roughly symmetric expansion).
2. **Query** `GeoPhi.goldenApexCandidates(p1, p2)` — returns
   `[{apex, cart, kind}…]`: every SixPhi point that completes a golden
   triangle or gnomon on this edge.
3. **Score** each candidate by (a) the candidate's distance from origin, (b)
   the target shell `phiShellFor(unit(cart))`, (c) the gap
   `|‖cart‖ − targetShell|`. Pick the smallest gap.
4. **Reject** candidates whose apex coincides with an already-placed vertex on
   the *wrong* side (would create a degenerate or overlapping triangle). The
   `byEdgeKey` map catches this in O(1).
5. **Place** the triangle: add the apex vertex, add the triangle to `mdl3`
   (transparent fill + golden-ratio palette stroke), bump `byEdgeKey` for the
   three incident edges.
6. **Update frontier**: for each of the triangle's three edges, if its
   `byEdgeKey` count is now 2 it closed against an existing triangle (drop
   from frontier); else add to frontier.
7. **Hop the robot** to the centroid of the new triangle.
8. `context1.render()`.

**Termination**:
- `frontier` empty → `state = 'done'`.
- `triangles.length ≥ 200` → safety cap, `state = 'done'`.

---

## 6. The seed

A single golden triangle small enough to sit strictly inside the teapot at the
origin. Take any golden triangle from `G.fiboTriangles` scaled down to
`shell = φ^-4 ≈ 0.146` so it's well inside the bounding sphere.

The three seed edges go into the frontier; growth proceeds outward in all
three directions simultaneously.

---

## 7. The robot glyph

`seen.Shapes.tetrahedron()`, scaled to ~`φ^-3` (about 1/5 the teapot radius),
saturated color (`#ff6a00`). Translated to the centroid of the most recently
placed triangle. v1 doesn't orient it — orientation along the face normal is a
stretch goal.

---

## 8. Animation state machine

```
state = 'idle' | 'running' | 'done'

startRobot():
  stopRobot()
  mdl3.children = []
  addTeapot(mdl3)              # mesh stays mounted across the run
  seedStructure(robotState)    # 1 triangle, 3 frontier edges
  drawAll(robotState, mdl3)    # render seed + robot
  robotState.state = 'running'
  robotState.timerId = setInterval(robotTick, 200)

robotTick():
  if frontier empty or triangles ≥ 200:
    stopRobot('done'); return
  step = frontierStep(robotState)
  if !step:                    # no legal candidate (shouldn't happen often)
    stopRobot('done'); return
  applyStep(robotState, step)
  drawStep(robotState, mdl3, step)
  context1.render()

stopRobot(reason='idle'):
  if robotState.timerId: clearInterval(robotState.timerId)
  robotState.timerId = null
  robotState.state = reason
```

Cleanup on `onDestroy` so navigation doesn't leak the timer.

---

## 9. Integration points in `+page.svelte`

- `onMount`: after `setSvgSize true`, create `mdl3 = new seen.Model()`,
  `mdl1.add mdl3`, initialize `robotState = {state: 'idle', ...}`.
- Button: one new `<a class="button" on:click={toggleRobot}>{label}</a>` in
  the existing button row. `label` reactive on `robotState.state`.
- `toggleRobot`: `if running then stopRobot() else startRobot()`.
- Existing `mdl1` (polyhedra/faces) and `mdl2` (segments/cliques) remain.
  Robot Build is additive.

---

## 10. Phased work order

1. **Spec sign-off (this doc).**
2. **Teapot ingestion.** Land `build-teapot-json.mjs`, run it, commit
   `teapot.json`, write `teapotMesh.coffee` with `teapotSeenModel()` and
   `teapotRadialDistance(dir)`. Headless smoke test: dump bounding box and a
   few radial distances.
3. **φ-shell helper.** `SHELLS` table and `phiShellFor(dir)`. Trivial; one
   test that confirms strict enclosure on a few sampled directions.
4. **`robotBuild.coffee` headless.** Frontier queue + step function + scoring.
   Run *without rendering*: assert that 200 steps grow the structure
   monotonically outward and terminate (frontier empties) on a sphere stand-in.
5. **Static integration.** Add the button, wire `startRobot()` to place
   **all triangles at once** + teapot. Confirms scene renders, drag works, no
   regression. Catches the integration bugs before the animation layer.
6. **Animation.** Replace all-at-once with 200 ms tick loop, add the robot
   glyph, add `onDestroy` cleanup.
7. **Polish (optional).** Robot face-normal orientation, per-shell color (so
   k-pattern is visible), HUD with current step / frontier size.

Steps 2–4 ship as one PR (data + pure logic, no UI). Steps 5–6 are a second
PR with the playground edit.

---

## 11. Open / refined design questions

- **Edge length in SixPhi vs target shell.** Golden-triangle steps move you by
  edge length 2 or 2/φ in Cartesian. To grow from shell `φ^k` to shell
  `φ^(k+1)`, the required step is `φ^(k+1) − φ^k = φ^(k−1)` (golden identity).
  Some shells will be reachable in one step, others in two. `goldenApexCandidates`
  handles this automatically (it just returns what's reachable); the scoring
  picks the best match. Worth confirming with a smoke test.
- **What if no candidate is within tolerance of the target shell?** Pick the
  best available and continue — the hull will have a few "bumpy" faces where
  the φ-grid and teapot silhouette mismatch. Those are diagnostic.
- **Seed direction matters.** Three seed edges point in three icosahedral
  directions. Place the seed so its edges roughly straddle the teapot's main
  asymmetries (spout / handle / lid).
- **Per-shell color.** Optional polish (`#7e CCAA` shifted by `k`) so the
  rendered hull visibly encodes which directions push the spout vs the body.

---

## 12. Out of scope (deliberate)

- Closure verification across `⅕Z[φ]` (reflections-in-the-mix regime). v1
  growth uses only translation + apex completion, staying in `Z[φ]`.
- Pause / scrub / step UI (auto-play locked from the earlier question).
- The 60-golden-triangle decomposition of a fixed dodecahedron — superseded by
  this adaptive build.
- Exact PhiBase ray-mesh distance. v1 uses float ray-tri intersection; exact
  comparison `r² vs φ^(2k)` is a later optimization once the hull is visible.
