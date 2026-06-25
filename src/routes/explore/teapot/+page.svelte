<script lang="coffeescript" type="text/coffeescript">
import '$lib/seen.m.coffee'                    # side-effect: window.seen
import { onMount, onDestroy } from 'svelte'
import { PhiBase } from '$lib/coffee/phiBase.coffee'
import { GeoPhi } from '$lib/coffee/geoPhi.coffee'
import { teapotSeenModel, teapotRadialDistance } from '$lib/coffee/teapotMesh.coffee'
import { createBridge, pickDodecahedronSeeds, buildVoxelHull } from '$lib/coffee/robotBuildBridge.coffee'
import { buildWfcDodecSurface, extractDodecPentagons, wfcFillPentagon } from '$lib/coffee/teapotWfc.coffee'
import { buildSingleDodec3D } from '$lib/coffee/dodecWfc3D.coffee'
import { init as initAngles } from '$lib/coffee/wfc/anglePalette.coffee'
import { init as initWords } from '$lib/coffee/wfc/vertexWords.coffee'
import { init as initRobinson } from '$lib/coffee/wfc/robinson.coffee'

console.log 'teapot: script loaded'

CANVAS_SIZE  = 520
MODEL_SCALE  = 220        # 1 unit (teapot bounding sphere) -> 220 px in scene
TICK_MS      = 200        # animation step duration
TRIS_PER_FACE = 3         # pickDodecahedronSeeds returns 3 tris per pentagon
PHI          = (1 + Math.sqrt(5)) / 2

# Twelve evenly-spaced hues around the wheel, one per dodecahedron face.
# HSL h = i*30deg, fixed S/L for readability over the dark background.
hslToHex = (h, s, l)->
  c = (1 - Math.abs(2*l - 1)) * s
  x = c * (1 - Math.abs(((h / 60) % 2) - 1))
  m = l - c/2
  [r, g, b] = (
    if h < 60   then [c, x, 0]
    else if h < 120 then [x, c, 0]
    else if h < 180 then [0, c, x]
    else if h < 240 then [0, x, c]
    else if h < 300 then [x, 0, c]
    else                  [c, 0, x]
  )
  hex = (n)-> Math.round((n + m) * 255).toString(16).padStart(2, '0')
  "##{hex(r)}#{hex(g)}#{hex(b)}"

FACE_COLORS = ( hslToHex(i * 30, 0.65, 0.55) for i in [0...12] )

# ---------- adjacency build order ----------
# Given an array of triangles (each [ia,ib,ic] vertex-index triples), return
# an ordering such that every triangle after the first shares at least one
# edge with a triangle already placed. (BFS over the triangle-adjacency
# graph, starting from index 0.)
edgeKeyAB = (a, b) -> if a < b then "#{a}-#{b}" else "#{b}-#{a}"

buildAdjacencyOrder = (triangles) ->
  return [] if triangles.length == 0
  edgesOf = (tri) -> [
    edgeKeyAB(tri[0], tri[1])
    edgeKeyAB(tri[1], tri[2])
    edgeKeyAB(tri[2], tri[0])
  ]
  edgeToTris = {}
  for tri, i in triangles
    for e in edgesOf(tri)
      edgeToTris[e] ?= []
      edgeToTris[e].push i
  order = [0]
  placed = new Set([0])
  # BFS frontier: triangles that share an edge with something already placed
  queue = []
  enqueueNeighbors = (idx) ->
    for e in edgesOf(triangles[idx])
      for ti in (edgeToTris[e] ? [])
        continue if placed.has(ti)
        # de-dup: don't push the same tri twice
        queue.push(ti) unless ti in queue
  enqueueNeighbors(0)
  while order.length < triangles.length
    if queue.length == 0
      # Disconnected component (shouldn't happen on a closed mesh, but be
      # safe): pick the lowest unplaced index as a new seed.
      next = null
      for i in [0...triangles.length]
        if !placed.has(i)
          next = i
          break
      break unless next?
      order.push next
      placed.add next
      enqueueNeighbors(next)
      continue
    next = queue.shift()
    continue if placed.has(next)
    order.push next
    placed.add next
    enqueueNeighbors(next)
  order

# scene
scene  = null
ctx    = null
mdl    = null              # root model (carries the drag transform)
mdlTeapot = null
mdlBuild  = null           # accumulates triangles one per tick
mdlRobot  = null           # holds the robot glyph (replaced each tick)
xform  = null

# geometry / state machine
gPhi   = null
bridge = null
state  = null              # robotBuild state
allTris = []               # triangles to reveal, in build (adjacency) order
triFaces = []              # face index aligned with allTris (for coloring)
tickIdx = 0
timerId = null

# template-bound
status    = 'idle'
triCount  = 0
vertCount = 0
currentN  = 0             # phi-shell level. 0 = canonical Robinson size; -1, -2 ... = smaller tiles
wfcReady  = false         # has the WFC palette/words/templates finished loading?
showTeapot  = true        # toggle the teapot mesh visibility
transparent = false       # toggle ~10% alpha on the WFC tiles

# Map currentN to a Robinson-tile scale for WFC mode. n=0: tileScale 1
# (canonical Robinson size — each pentagon gets a single big T). n=-1:
# tileScale 1/φ. n=-2: 1/φ². Each rung gives ~φ² more decisions per face.
tileScaleForN = (n) ->
  # Start from 1 and multiply by (φ−1) for each rung down.
  pb = new PhiBase(0, 1)
  step = new PhiBase(1, -1)   # 1/φ
  for _ in [0...Math.abs(n)]
    pb = pb.mul(step)
  pb

# ---------- scene helpers ----------
addTeapotTo = (parent)->
  mat = new seen.Material seen.Colors.hex('#888888')
  mat.a = 0x50
  tm = teapotSeenModel seen, mat
  tm.scale MODEL_SCALE
  parent.add tm
  tm

# Orient (a, b, c) so the triangle's outward normal points AWAY from the
# origin. createTriangle sorts vertex names, so the raw winding order is
# arbitrary; without this re-orientation, half the triangles would be
# culled when cullBackfaces is on.
orientOutward = (a, b, c)->
  # face normal via cross product
  ux = b[0]-a[0]; uy = b[1]-a[1]; uz = b[2]-a[2]
  vx = c[0]-a[0]; vy = c[1]-a[1]; vz = c[2]-a[2]
  nx = uy*vz - uz*vy
  ny = uz*vx - ux*vz
  nz = ux*vy - uy*vx
  # face centroid
  cx = (a[0]+b[0]+c[0])/3
  cy = (a[1]+b[1]+c[1])/3
  cz = (a[2]+b[2]+c[2])/3
  # if normal points toward the origin (cx,cy,cz)·n < 0, flip winding
  if (cx*nx + cy*ny + cz*nz) < 0
    [a, c, b]
  else
    [a, b, c]

triangleSeenPath = ([ia, ib, ic], verts, faceIdx = 0, preWound = false)->
  # preWound: caller already set CCW outward winding (used by the voxel hull,
  # where the cube cell center isn't the origin and origin-based
  # orientOutward gives the wrong answer).
  [a, b, c] = if preWound then [verts[ia], verts[ib], verts[ic]] else orientOutward verts[ia], verts[ib], verts[ic]
  pa = seen.P a[0]*MODEL_SCALE, a[1]*MODEL_SCALE, a[2]*MODEL_SCALE
  pb = seen.P b[0]*MODEL_SCALE, b[1]*MODEL_SCALE, b[2]*MODEL_SCALE
  pc = seen.P c[0]*MODEL_SCALE, c[1]*MODEL_SCALE, c[2]*MODEL_SCALE
  path = seen.Shapes.path [pa, pb, pc]
  path.cullBackfaces = true
  # Uniform white. Alpha tracks the `transparent` toggle: ~10% when set,
  # ~88% otherwise. Alpha lives on the Color object, NOT the Material.
  fillColor = seen.Colors.hex('#ffffff')
  fillColor.a = if transparent then 0x1a else 0xE0
  mat = new seen.Material fillColor
  path.fill mat
  path.surfaces[0].fillMaterial = mat
  path.stroke new seen.Material seen.Colors.hex('#1a1a1a')
  path.surfaces[0]["stroke-width"] = 1
  path

triangleCentroid = ([ia, ib, ic], verts)->
  [a, b, c] = [verts[ia], verts[ib], verts[ic]]
  [
    ((a[0] + b[0] + c[0]) / 3) * MODEL_SCALE
    ((a[1] + b[1] + c[1]) / 3) * MODEL_SCALE
    ((a[2] + b[2] + c[2]) / 3) * MODEL_SCALE
  ]

robotGlyphAt = ([cx, cy, cz])->
  g = seen.Shapes.tetrahedron()
  g.scale MODEL_SCALE / 20
  g.translate cx, cy, cz
  mat = new seen.Material seen.Colors.hex('#ff6a00')   # bright orange
  g.fill mat
  g

# ---------- animation driver ----------
# Build the seed structure for the current phi-shell level. n=0 is the
# regular dodecahedron at r=√3; n<0 is the band-filtered irregular hull
# whose vertices sit in (phi^n, phi^(n+1)) above the teapot surface.
# When showWfc is on, each pentagonal face gets the 2D Robinson-WFC fill.
# Convert the dodecWfc3D output (array of { verts: [[x,y,z]×3], kind, faceIdx })
# into the state shape the existing renderer wants ({state: {triangles, vertices},
# origFaces}). Vertices are deduped by Cartesian-key — shared face boundary
# verts collapse into one index per 3D position.
dodec3DTilesToState = (tiles) ->
  verts = []
  triangles = []
  faceIdxs = []
  vertMap = new Map()
  vertKey = (v) -> "#{v[0].toFixed(5)},#{v[1].toFixed(5)},#{v[2].toFixed(5)}"
  indexFor = (v) ->
    k = vertKey(v)
    if vertMap.has(k)
      vertMap.get(k)
    else
      idx = verts.length
      verts.push v.slice()
      vertMap.set(k, idx)
      idx
  for tile in tiles
    triangles.push [indexFor(tile.verts[0]), indexFor(tile.verts[1]), indexFor(tile.verts[2])]
    faceIdxs.push tile.faceIdx
  { state: { triangles, vertices: verts }, origFaces: faceIdxs }

buildSeedsForN = (n)->
  if n >= 0
    # 3D WFC on a single dodecahedron. Phase 1: per-face independent
    # fills, boundary mismatches visible at dodec edges. Phase 2 will
    # add edge-vertex propagation so the fills connect cleanly.
    return { state: { triangles: [], vertices: [] }, origFaces: [] } unless wfcReady
    tileScale = tileScaleForN n
    tiles = buildSingleDodec3D gPhi, tileScale, 200
    return dodec3DTilesToState(tiles)
  else
    # Voxel hull made of Hut cells — the connected manifold around the teapot.
    scale = 0.35 * Math.pow(PHI, n + 1)
    range = Math.ceil(2.5 / scale)
    state = buildVoxelHull gPhi, teapotRadialDistance, { scale, range }
    origFaces = (Math.floor(i / 6) % 12 for i in [0...state.triangles.length])
    { state, origFaces }

prepareBuild = ->
  console.log "teapot: prepareBuild n=#{currentN}"
  return false unless bridge?
  try
    result = buildSeedsForN currentN
  catch err
    console.error 'teapot: buildSeedsForN threw:', err
    return false
  state = result.state
  console.log "teapot: build -> tris=#{state.triangles.length} verts=#{state.vertices.length}"
  return false if state.triangles.length == 0
  origTris  = state.triangles[..]
  origFaces = result.origFaces
  order = buildAdjacencyOrder(origTris)
  allTris  = (origTris[i]  for i in order)
  triFaces = (origFaces[i] for i in order)
  tickIdx = 0
  triCount = 0
  vertCount = state.vertices.length
  mdlBuild.children = []
  mdlRobot.children = []
  true

tick = ->
  if tickIdx >= allTris.length
    stopAnimation 'done'
    return
  tri = allTris[tickIdx]
  faceIdx = triFaces[tickIdx] ? 0
  mdlBuild.add triangleSeenPath(tri, state.vertices, faceIdx, currentN < 0)
  mdlRobot.children = []
  mdlRobot.add robotGlyphAt(triangleCentroid(tri, state.vertices))
  tickIdx += 1
  triCount = tickIdx
  status = (if tickIdx >= allTris.length then 'done' else 'running')
  mdl.transform xform if xform
  ctx.render()

startAnimation = ->
  return unless bridge?
  stopAnimation 'idle'
  ok = prepareBuild()
  unless ok
    console.warn 'teapot: no dodecahedron seeds found'
    return
  status = 'running'
  mdl.transform xform if xform
  ctx.render()
  timerId = setInterval tick, TICK_MS

stopAnimation = (newStatus = 'idle') ->
  if timerId?
    clearInterval timerId
    timerId = null
  status = newStatus unless status == 'done'

clearScene = ->
  stopAnimation 'idle'
  mdlBuild.children = [] if mdlBuild?
  mdlRobot.children = [] if mdlRobot?
  state = null
  allTris = []
  tickIdx = 0
  triCount = 0
  vertCount = 0
  status = 'idle'
  mdl.transform xform if xform
  ctx.render()

toggleAnimation = ->
  console.log "teapot: toggleAnimation (status=#{status})"
  if status == 'running' then stopAnimation('idle') else startAnimation()

setLevel = (n)->
  return if n == currentN
  currentN = n
  stopAnimation 'idle'
  clearScene()
  startAnimation()

tighter = -> setLevel(currentN - 1)
looser  = -> setLevel(currentN + 1)

# Teapot visibility: just clear or re-add the seen mesh; no rebuild needed.
toggleTeapot = ->
  if showTeapot
    addTeapotTo mdlTeapot
  else
    mdlTeapot.children = []
  mdl.transform xform if xform
  ctx.render() if ctx?

# Transparency: mutate the alpha on every existing path's fill material.
# Avoids a WFC re-run for a render-only knob.
toggleTransparency = ->
  alpha = if transparent then 0x1a else 0xE0
  return unless mdlBuild?
  for path in mdlBuild.children
    for surf in path.surfaces
      mat = surf.fillMaterial
      if mat? and mat.color?
        mat.color.a = alpha
  ctx.render() if ctx?

# ---------- mount ----------
canvasEl = null

initWfc = ->
  try
    await Promise.all [initAngles(), initWords(), initRobinson()]
    wfcReady = true
    console.log 'teapot: wfc ready'
  catch err
    console.error 'teapot: wfc init failed:', err

initScene = ->
  unless window.seen?
    setTimeout initScene, 50
    return
  gPhi = new GeoPhi()
  bridge = createBridge gPhi, teapotRadialDistance
  initWfc()       # async — sets wfcReady once palette/words/templates loaded
  mdl = seen.Models.default()
  mdl.cullBackfaces = true
  mdlTeapot = new seen.Model()
  mdlTeapot.cullBackfaces = false   # teapot mesh winding is arbitrary; keep see-through
  mdlBuild = new seen.Model()
  mdlBuild.cullBackfaces = true     # rely on per-triangle orientation + culling
  mdlRobot = new seen.Model()
  mdlRobot.cullBackfaces = false
  mdl.add mdlTeapot
  mdl.add mdlBuild
  mdl.add mdlRobot
  scene = new seen.Scene
    model: mdl
    viewport: seen.Viewports.center(CANVAS_SIZE, CANVAS_SIZE)
    cullBackfaces: true
  scene.camera.translate 0, 0, -600
  ctx = seen.Context canvasEl, scene
  drag = new seen.Drag canvasEl, inertia: true
  drag.on 'drag.rotate', (e) ->
    xform = seen.Quaternion.xyToTransform e.offsetRelative...
    mdl.transform xform
    ctx.render()
  addTeapotTo mdlTeapot
  ctx.render()

onMount initScene
onDestroy ->
  if timerId?
    clearInterval timerId
    timerId = null
</script>

<svelte:head><title>Robot Build · Teapot</title></svelte:head>

<div class="page">
  <h1>Robot Build around the Utah Teapot</h1>
  <p class="lede">
    A regular dodecahedron of golden triangles built one face at a time around
    a Utah teapot. The bright tetrahedron is the robot — it hops to each new
    triangle as it places it. Drag the scene to rotate.
  </p>

  <figure>
    <canvas
      bind:this={canvasEl}
      width={CANVAS_SIZE}
      height={CANVAS_SIZE}
      style="background:#1a1a1a; border-radius:6px;"
    ></canvas>
  </figure>

  <div class="controls">
    <button on:click={toggleAnimation}>
      {#if status === 'running'}■ Stop{:else}▶ Run Build{/if}
    </button>
    <button on:click={clearScene}>Clear</button>
    <label class="toggle" title="Show the Utah teapot mesh inside the dodecahedron">
      <input type="checkbox" bind:checked={showTeapot} on:change={toggleTeapot}/>
      teapot
    </label>
    <label class="toggle" title="Render the WFC tiles at ~10% alpha (see-through)">
      <input type="checkbox" bind:checked={transparent} on:change={toggleTransparency}/>
      transparent
    </label>
  </div>
  <div class="controls">
    <span class="level">
      level n = <code>{currentN}</code>
      <button on:click={tighter} title="tighter — smaller WFC tiles">−</button>
      <button on:click={looser}  title="looser — larger WFC tiles">+</button>
    </span>
    <span class="hud">
      status: <code>{status}</code>
      &nbsp;·&nbsp; triangles: <code>{triCount}</code>
      &nbsp;·&nbsp; vertices: <code>{vertCount}</code>
    </span>
  </div>
</div>

<style>
  .page { max-width: 720px; margin: 1rem auto; padding: 0 1rem 6rem; }
  .toggle { display: inline-flex; gap: 0.25rem; align-items: center; font-size: 0.9rem; user-select: none; cursor: pointer; padding: 0.2rem 0.4rem; }
  .toggle input { margin: 0; }
  h1 { font-size: 1.3rem; margin-bottom: 0.25rem; }
  .lede { color: #555; margin-top: 0; }
  figure { margin: 0.5rem 0; }
  canvas { max-width: 100%; height: auto; display: block; }
  .controls {
    display: flex;
    gap: 0.75rem;
    align-items: center;
    flex-wrap: wrap;
    margin-top: 0.5rem;
    margin-bottom: 1in;            /* keep clear of the page footer */
  }
  button { padding: 0.4rem 0.9rem; cursor: pointer; }
  .level { display: inline-flex; gap: 0.3rem; align-items: center; }
  .level button { padding: 0.2rem 0.6rem; font-weight: bold; }
  .hud { color: #555; font-size: 0.9rem; }
  code { background: #f0f0f0; padding: 0 0.3rem; border-radius: 3px; }
</style>
