<script lang="coffeescript" type="text/coffeescript">
import '$lib/seen.m.coffee'                    # side-effect: window.seen
import { onMount, onDestroy } from 'svelte'
import { PhiBase } from '$lib/coffee/phiBase.coffee'
import { GeoPhi } from '$lib/coffee/geoPhi.coffee'
import { getMesh, meshNames } from './meshes.coffee'
import { createBridge, buildVoxelHullStreaming } from './robotBuildBridge.coffee'
import { buildWfcDodecSurface, extractDodecPentagons, wfcFillPentagon } from './teapotWfc.coffee'
import { buildSingleDodec3D } from './dodecWfc3D.coffee'
import { init as initAngles } from '$lib/coffee/wfc/anglePalette.coffee'
import { init as initWords } from '$lib/coffee/wfc/vertexWords.coffee'
import { init as initRobinson } from '$lib/coffee/wfc/robinson.coffee'

console.log 'teapot: script loaded'

CANVAS_SIZE  = 520
MODEL_SCALE  = 220        # 1 unit (mesh bounding sphere) -> 220 px in scene
TEAPOT_SCALE = 1.5        # resize the mesh in mesh-units; hull wraps the bigger perimeter

# Pick the active mesh by name (see ./meshes.coffee).
currentMeshName = 'teapot'
currentMesh = getMesh currentMeshName
currentMesh.setScale TEAPOT_SCALE
TICK_MS      = 16         # ~60fps. Single tick rate for every build path.
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
currentN  = -4            # phi-shell level. 0 = canonical Robinson size; -1, -2 ... = smaller tiles
wfcReady  = false         # has the WFC palette/words/templates finished loading?
showShape   = true        # toggle the source mesh's visibility
showHull    = true        # toggle the placed hull triangles' visibility
buildNotice = ''          # one-line warning/elapsed-time message shown above controls

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
  tm = currentMesh.seenModel seen, mat
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
  # Uniform white. Alpha tracks the `showHull` toggle: 0 (invisible) when
  # off, ~88% when on. Alpha lives on the Color object, NOT the Material.
  fillColor = seen.Colors.hex('#ffffff')
  fillColor.a = if showHull then 0xE0 else 0x1a
  mat = new seen.Material fillColor
  path.fill mat
  path.surfaces[0].fillMaterial = mat
  path.stroke new seen.Material seen.Colors.hex('#808080')
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
    # Voxel hull builds are now done streaming in prepareBuild — see
    # buildVoxelHullStreaming there. This branch just exists so the
    # WFC-only helper above stays valid; it shouldn't be reached.
    { state: { triangles: [], vertices: [] }, origFaces: [] }

# streaming-iterator state for the voxel hull path. iter is non-null when
# the build is being pumped one batch at a time per tick; classifyDone
# flips true the first time the iterator moves out of the classify phase
# so the build notice can switch from "classifying…" to live counts.
iter = null
streamT0 = 0
streamFaceCounter = 0

prepareBuild = ->
  console.log "teapot: prepareBuild n=#{currentN}"
  return false unless bridge?
  mdlBuild.children = []
  mdlRobot.children = []
  iter = null
  state = null
  allTris = []
  tickIdx = 0
  triCount = 0
  vertCount = 0
  # WFC path (n >= 0) — synchronous compute, paced reveal at frame rate.
  if currentN >= 0
    try
      result = buildSeedsForN(currentN)
    catch err
      console.error 'teapot: buildSeedsForN threw:', err
      return false
    state = result.state
    return false if state.triangles.length == 0
    allTris  = state.triangles[..]
    triFaces = result.origFaces
    vertCount = state.vertices.length
    return true
  # Voxel hull (n < 0) — always streamed.
  scale = 0.35 * Math.pow(PHI, currentN + 1)
  range = Math.ceil(2.5 * TEAPOT_SCALE / scale)
  iter = buildVoxelHullStreaming gPhi, currentMesh.radialDistance,
    scale: scale, range: range
    batchSize: 250
    boundingRadius: currentMesh.boundingRadius
    meshVerts: currentMesh.verts, meshTris: currentMesh.tris
    isInside: currentMesh.isInside
  state = iter.state
  streamT0 = performance.now()
  streamFaceCounter = 0
  true

# Cached/WFC tick: append triangles from the precomputed allTris array.
tickCached = ->
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

# Streaming tick: pump the iterator one batch, append any triangles it
# emitted, update HUD. Triangles can appear from the very first batch
# (cubes near the grid boundary or near force-filled feature cubes emit
# huts on the second scan visit of the pair).
tickStreaming = ->
  return unless iter?
  step = iter.next()
  if step.newTriangles.length > 0
    verts = state.vertices
    for tri in step.newTriangles
      faceIdx = (Math.floor(streamFaceCounter / 6) % 12)
      mdlBuild.add triangleSeenPath(tri, verts, faceIdx, true)
      streamFaceCounter += 1
    lastTri = step.newTriangles[step.newTriangles.length - 1]
    mdlRobot.children = []
    mdlRobot.add robotGlyphAt(triangleCentroid(lastTri, verts))
    triCount = streamFaceCounter
    vertCount = verts.length
  buildNotice = "Scanning cubes — #{step.progress.idx} / #{step.progress.total} · #{triCount} triangles"
  mdl.transform xform if xform
  ctx.render()
  if step.done
    dt = ((performance.now() - streamT0) / 1000).toFixed(1)
    buildNotice = "Built #{state.triangles.length} triangles in #{dt} s."
    iter = null
    stopAnimation 'done'

tick = ->
  if iter?
    tickStreaming()
  else
    tickCached()

startAnimation = ->
  return unless bridge?
  stopAnimation 'idle'
  ok = prepareBuild()
  unless ok
    console.warn 'teapot: build setup failed'
    return
  buildNotice = '' unless iter?
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

setMesh = (name) ->
  # NOTE: bind:value on the <select> has already mutated currentMeshName
  # to the new option by the time on:change fires here. Comparing against
  # the currently-loaded mesh (currentMesh.name) is the actual no-op check.
  return if currentMesh? and name == currentMesh.name
  currentMeshName = name
  currentMesh = getMesh(name)
  currentMesh.setScale TEAPOT_SCALE
  # Swap the visible mesh model and reset everything downstream.
  if mdlTeapot?
    mdlTeapot.children = []
    addTeapotTo mdlTeapot if showShape
  bridge = createBridge gPhi, currentMesh.radialDistance if gPhi?
  # Hull from the previous mesh is meaningless; just clear the scene.
  clearScene()

toggleAnimation = ->
  console.log "teapot: toggleAnimation (status=#{status})"
  if status == 'running' then stopAnimation('idle') else startAnimation()

setLevel = (n)->
  return if n == currentN
  currentN = n
  # Don't auto-build. Level changes are cheap; the voxel-hull compute
  # at low n locks up the page for many seconds, so wait for an
  # explicit "Run Build" click instead.
  stopAnimation 'idle'
  clearScene()

tighter = -> setLevel(currentN - 1)
looser  = -> setLevel(currentN + 1)


# Source-shape visibility: just clear or re-add the seen mesh; no rebuild needed.
toggleShape = ->
  if showShape
    addTeapotTo mdlTeapot
  else
    mdlTeapot.children = []
  mdl.transform xform if xform
  ctx.render() if ctx?

# Hull visibility: mutate alpha on every existing hut triangle's fill
# material so the toggle is render-only — no rebuild needed.
toggleHull = ->
  alpha = if showHull then 0xE0 else 0x1a
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
  bridge = createBridge gPhi, currentMesh.radialDistance
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
  # Two camera positions, switched by the `inside` checkbox:
  #   outside (default): camera at z=-600, looks at origin → normal exterior view.
  #   inside: camera at the origin (z=0), looks outward along -z → user can
  #     rotate via drag to see the hull from inside the teapot.
  OUTSIDE_Z = -600
  scene.camera.translate 0, 0, OUTSIDE_Z
  ctx = seen.Context canvasEl, scene
  drag = new seen.Drag canvasEl, inertia: true
  drag.on 'drag.rotate', (e) ->
    xform = seen.Quaternion.xyToTransform e.offsetRelative...
    mdl.transform xform
    ctx.render()
  # Wheel zoom: uniform scale on the model. Lets the user magnify
  # the scene to inspect fine features (e.g. the handle's hole at n ≤ -4).
  # Clamped so a runaway wheel can't collapse the model to a point.
  zoom = 1
  canvasEl.addEventListener 'wheel', (e) ->
    e.preventDefault()
    factor = if e.deltaY < 0 then 1.1 else 1/1.1
    next = zoom * factor
    return if next < 0.1 or next > 20
    zoom = next
    mdl.scale factor
    ctx.render()
  , { passive: false }
  addTeapotTo mdlTeapot
  ctx.render()

onMount initScene
onDestroy ->
  if timerId?
    clearInterval timerId
    timerId = null
</script>

<svelte:head><title>Robot Build · Hull</title></svelte:head>

<div class="page">
  <h1>Robot Build around a Teapot or Torus</h1>
  <p class="lede">
    A hull of golden-triangle huts built one piece at a time around the
    chosen shape — a Utah teapot or a torus. The bright tetrahedron is
    the robot — it hops to each new triangle as it places it. Drag the
    scene to rotate.
  </p>

  <figure>
    <canvas
      bind:this={canvasEl}
      width={CANVAS_SIZE}
      height={CANVAS_SIZE}
      style="background:green; border-radius:6px;"
    ></canvas>
  </figure>

  {#if buildNotice}
    <p class="notice">{buildNotice}</p>
  {/if}
  <div class="controls">
    <button on:click={toggleAnimation}>
      {#if status === 'running'}■ Stop{:else}▶ Run Build{/if}
    </button>
    <button on:click={clearScene}>Clear</button>
    <span class="visibility">
      Visibility:
      <label class="toggle" title="Show or hide the source mesh.">
        <input type="checkbox" bind:checked={showShape} on:change={toggleShape}/>
        shape
      </label>
      <label class="toggle" title="Show or hide the placed hull triangles.">
        <input type="checkbox" bind:checked={showHull} on:change={toggleHull}/>
        hull
      </label>
    </span>
    <label class="toggle" title="Pick the mesh whose hull is being built.">
      shape
      <select bind:value={currentMeshName} on:change={(e) => setMesh(e.target.value)}>
        {#each meshNames() as m}
          <option value={m}>{m}</option>
        {/each}
      </select>
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
    margin-top: 0.3rem;
    margin-bottom: 0.3rem;
  }
  .controls:last-of-type {
    margin-bottom: 1in;            /* keep clear of the page footer */
  }
  .notice {
    margin: 0.4rem 0 0.3rem;
    padding: 0.4rem 0.6rem;
    background: #fff5d6;
    border-left: 3px solid #d4a464;
    border-radius: 3px;
    font-size: 0.88rem;
    color: #5a4a20;
  }
  button { padding: 0.4rem 0.9rem; cursor: pointer; }
  .level { display: inline-flex; gap: 0.3rem; align-items: center; }
  .level button { padding: 0.2rem 0.6rem; font-weight: bold; }
  .hud { color: #555; font-size: 0.9rem; }
  code { background: #f0f0f0; padding: 0 0.3rem; border-radius: 3px; }
</style>
