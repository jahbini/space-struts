<script lang="coffeescript" type="text/coffeescript">
import '$lib/seen.m.coffee'    # side-effect: window.seen
import { onMount } from 'svelte'
import { PhiBase } from '$lib/coffee/phiBase.coffee'
import { PhiPoint2D, getUnitDisp } from '$lib/coffee/wfc/phiPoint2D.coffee'
import { init as initAngles, getRobinson2DAngles, cosOf } from '$lib/coffee/wfc/anglePalette.coffee'
import { init as initWords, getClosedMultisets } from '$lib/coffee/wfc/vertexWords.coffee'
import { init as initRobinson, pieceKinds } from '$lib/coffee/wfc/robinson.coffee'
import { Assembly } from '$lib/coffee/wfc/assembly.coffee'

# State exposed to the template.
status       = 'loading'   # loading | ready | running | done | contradiction | maxSteps | error
errorMsg     = null
sceneInfo    = ''
edgeStats    = ''
assembly     = null

# Visibility toggles. fill = colored polygon interiors + T/G labels;
# edges = the dark strokes; verts = tetrahedron at every vertex.
showFill  = true
showEdges = true
showVerts = false

# Target = regular pentagon centred at the (a,b) origin, plus a tileScale
# that the Assembly threads through computeC, classifyDisplacement, and
# the sub-scale-gap guard.
#   apothem  = 4
#   tileScale = 1/φ = PhiBase(1, -1)   ⇒ short edge 1/φ, long edge 1
#       Sub-scale-gap threshold becomes (1/φ)² = 2−φ, so tiles can sit at
#       1/φ separation without triggering the gap rejection — the WFC has
#       ~φ² ≈ 2.6× more decisions per fill, all genuinely free choices.
target = {
  center:           PhiPoint2D.ZERO
  apothem2:         new PhiBase(0, 8)       # 2 × 4
  apothem2Overhang: new PhiBase(0, 10)      # 2 × 4 + 2
  tileScale:        new PhiBase(-1, 2)      # 1/φ² = 2 − φ
}
R_PB = new PhiBase(8, -8)        # apothem · 2/φ = 4 · 2/φ = 8(φ−1)

pentagonCorners = ->
  for k in [0, 2, 4, 6, 8]
    getUnitDisp(k).scale(R_PB).toCartesian()

SCALE = 50
svgW  = 640
svgH  = 560

# ---------- seen scene ----------
svgEl     = null
mdl       = null
mdlStatic = null   # pentagon outline + axes (built once)
mdlPieces = null   # placed triangles
mdlLabels = null   # T/G text shapes (only while pieces.length <= 40)
mdlVerts  = null   # tetrahedron markers (showVerts only)
scene     = null
ctx       = null
# Shared fill/stroke materials — one per Robinson kind, reused on every
# triangle. seen mutates the alpha on the shared color object during the
# fill toggle, so all tiles flip in one assignment rather than per-shape.
fillMatT  = null   # brown (T = golden triangle)
fillMatG  = null   # green (G = golden gnomon)
strokeMat = null
labelMat  = null
vertMat   = null
T_HEX     = '#d4a464'   # brown
G_HEX     = '#7ca870'   # green

# Cartesian centroid of one piece, already mapped to SVG screen coords
# (y flipped, SCALE applied). Used by labels.
pieceCentroidCart = (p) ->
  cx = 0; cy = 0
  for v in p.verts
    [x, y] = v.pos.toCartesian()
    cx += x
    cy += y
  [cx / 3 * SCALE, -cy / 3 * SCALE]

pieceToSeenShape = (p) ->
  pts = for v in p.verts
    [x, y] = v.pos.toCartesian()
    seen.P x * SCALE, -y * SCALE, 0
  path = seen.Shapes.path pts
  path.cullBackfaces = false
  mat = if p.kind == 'T' then fillMatT else fillMatG
  path.fill mat
  path.surfaces[0].fillMaterial = mat
  path.stroke strokeMat
  path.surfaces[0]['stroke-width'] = if showEdges then 0.8 else 0
  path

pieceLabelShape = (p) ->
  [cx, cy] = pieceCentroidCart(p)
  shape = seen.Shapes.text(p.kind, anchor: 'middle')
  shape.translate cx, cy, 0
  shape.fill labelMat
  shape

vertexMarkerShape = (vx, vy) ->
  g = seen.Shapes.tetrahedron()
  g.scale 2
  g.translate vx * SCALE, -vy * SCALE, 0
  g.fill vertMat
  g

buildStaticOverlays = ->
  # Pentagon outline — five corners closed back to the first.
  corners = pentagonCorners()
  pts = (seen.P(c[0] * SCALE, -c[1] * SCALE, 0) for c in corners)
  pts.push pts[0]      # close
  outline = seen.Shapes.path pts
  outline.cullBackfaces = false
  outlineFill = seen.Colors.hex('#000000')
  outlineFill.a = 0
  outline.fill new seen.Material outlineFill
  outline.surfaces[0].fillMaterial = new seen.Material outlineFill
  outline.stroke new seen.Material seen.Colors.hex('#999999')
  outline.surfaces[0]['stroke-width'] = 1
  outline.surfaces[0]['stroke-dasharray'] = '4 4'
  mdlStatic.add outline
  # Axes — horizontal and vertical centre lines.
  for [a, b] in [
    [seen.P(-svgW/2, 0, 0), seen.P(svgW/2, 0, 0)]
    [seen.P(0, -svgH/2, 0), seen.P(0, svgH/2, 0)]
  ]
    axis = seen.Shapes.path [a, b]
    axis.cullBackfaces = false
    axisFill = seen.Colors.hex('#000000')
    axisFill.a = 0
    axis.fill new seen.Material axisFill
    axis.surfaces[0].fillMaterial = new seen.Material axisFill
    axis.stroke new seen.Material seen.Colors.hex('#dddddd')
    axis.surfaces[0]['stroke-width'] = 1
    mdlStatic.add axis

# ---------- assembly ↔ scene wiring ----------
buildSummary = ->
  cosLines = ("#{a}°: cos = #{JSON.stringify cosOf(a)}" for a in getRobinson2DAngles())
  ms = getClosedMultisets()
  [
    "robinson kinds: #{pieceKinds().join(', ')}"
    "Robinson 2D angles: #{getRobinson2DAngles().join(', ')}"
    "closed vertex multisets (#{ms.length}):"
    ("  [#{m.join(', ')}]" for m in ms)...
    "cos table (num: {p, n, d}, den: int):"
    cosLines.map((s) -> "  #{s}")...
  ].join('\n')

freshAssembly = ->
  a = new Assembly(target)
  a.seed('T')
  a

snapshotEdgeStats = ->
  s = assembly.stats()
  recent = assembly.log[Math.max(0, assembly.log.length - 5)...].map((e) -> "#{e.op}:#{e.kind}#{if e.side then '/' + e.side else ''}").join(' → ')
  base = "pieces=#{s.pieceCount}  vertices=#{s.vertexCount}  edges=#{s.edgeCount}  open=#{s.openEdgeCount}  insideOpen=#{s.insideOpenCount}  closed=#{s.closedVertexCount}\nlast 5: #{recent}"
  d = assembly.diagnose()
  reasons = Object.entries(d.perReason).sort((a, b) -> b[1] - a[1]).map(([r, c]) -> "#{r}=#{c}").join(' ')
  reasonsLine = if reasons then "rejections: #{reasons}" else "rejections: (none)"
  deadLines = if d.deadEdges.length == 0
    "dead-open: none"
  else
    edges = d.deadEdges.map (de) ->
      r = Object.entries(de.reasons).sort((a, b) -> b[1] - a[1]).map(([k, v]) -> "#{k}=#{v}").join(',')
      "  @(#{de.mid[0]}, #{de.mid[1]}) #{de.kind}/dir#{de.dir} tried=#{de.tried}: #{r}"
    "dead-open (#{d.deadEdges.length}):\n#{edges.join('\n')}"
  "#{base}\n#{reasonsLine}\n#{deadLines}"

appendPieceShape = (p) ->
  return unless mdlPieces?
  mdlPieces.add pieceToSeenShape(p)
  if showFill and assembly.pieces.length <= 40
    mdlLabels.add pieceLabelShape(p)

clearLabelsIfOverflow = ->
  # Once the assembly crosses 40 pieces, the label rule says hide them.
  if mdlLabels.children.length > 0 and assembly.pieces.length > 40
    mdlLabels.children = []

rebuildVertexMarkers = ->
  return unless mdlVerts?
  mdlVerts.children = []
  for v in assembly.vertices
    [vx, vy] = v.pos.toCartesian()
    mdlVerts.add vertexMarkerShape(vx, vy)

syncFromAssembly = ->
  mdlPieces.children = []
  mdlLabels.children = []
  appendPieceShape p for p in assembly.pieces
  rebuildVertexMarkers() if showVerts
  ctx.render() if ctx?

# ---------- seen init ----------
initScene = ->
  unless window.seen?
    setTimeout initScene, 50
    return
  # Shared materials — one Material per Robinson kind, reused on every
  # triangle. The fill toggle mutates the color alpha on these shared
  # objects, so all tiles flip in O(1) instead of walking the children.
  tColor = seen.Colors.hex(T_HEX); tColor.a = 0xD8
  gColor = seen.Colors.hex(G_HEX); gColor.a = 0xD8
  fillMatT  = new seen.Material tColor
  fillMatG  = new seen.Material gColor
  strokeMat = new seen.Material seen.Colors.hex('#222222')
  labelMat  = new seen.Material seen.Colors.hex('#222222')
  vertMat   = new seen.Material seen.Colors.hex('#222222')
  mdl = seen.Models.default()
  mdl.cullBackfaces = false
  mdlStatic = new seen.Model()
  mdlPieces = new seen.Model()
  mdlLabels = new seen.Model()
  mdlVerts  = new seen.Model()
  mdl.add m for m in [mdlStatic, mdlPieces, mdlLabels, mdlVerts]
  scene = new seen.Scene
    model: mdl
    viewport: seen.Viewports.center(svgW, svgH)
    cullBackfaces: false
  scene.camera.translate 0, 0, -1000
  ZOOM = 3
  mdl.scale ZOOM
  ctx = seen.Context(svgEl, scene)
  buildStaticOverlays()
  syncFromAssembly() if assembly?

onMount ->
  try
    await Promise.all [initAngles(), initWords(), initRobinson()]
    assembly = freshAssembly()
    initScene()
    edgeStats = snapshotEdgeStats()
    sceneInfo = buildSummary()
    status = 'ready'
  catch err
    errorMsg = err.message ? String(err)
    status = 'error'
    console.error err

# ---------- run loops ----------
runWfc = ->
  status = 'running'
  edgeStats = snapshotEdgeStats()
  maxSteps = 800
  count = 0
  HUD_EVERY = 25
  tick = ->
    return unless status == 'running'
    if count >= maxSteps
      status = 'maxSteps'
      edgeStats = snapshotEdgeStats()
      return
    before = assembly.pieces.length
    result = assembly.step()
    appendPieceShape assembly.pieces[i] for i in [before...assembly.pieces.length]
    clearLabelsIfOverflow()
    rebuildVertexMarkers() if showVerts and assembly.pieces.length > before
    ctx.render() if ctx?
    if count % HUD_EVERY == 0
      edgeStats = snapshotEdgeStats()
    count += 1
    if result == 'progress'
      setTimeout tick, 0
    else
      edgeStats = snapshotEdgeStats()
      status = result
  setTimeout tick, 0

# Kept for parity with the original tiles page.
runWfcOld = ->
  status = 'running'
  edgeStats = snapshotEdgeStats()
  maxSteps = 800
  count = 0
  tick = ->
    return unless status == 'running'
    if count >= maxSteps
      status = 'maxSteps'
      return
    before = assembly.pieces.length
    result = assembly.step()
    appendPieceShape assembly.pieces[i] for i in [before...assembly.pieces.length]
    clearLabelsIfOverflow()
    rebuildVertexMarkers() if showVerts and assembly.pieces.length > before
    ctx.render() if ctx?
    edgeStats = snapshotEdgeStats()
    count += 1
    if result == 'progress'
      setTimeout tick, 0
    else
      status = result
  setTimeout tick, 0

stepOnce = ->
  return if status not in ['ready', 'running', 'maxSteps']
  before = assembly.pieces.length
  result = assembly.step()
  appendPieceShape assembly.pieces[i] for i in [before...assembly.pieces.length]
  clearLabelsIfOverflow()
  rebuildVertexMarkers() if showVerts and assembly.pieces.length > before
  ctx.render() if ctx?
  edgeStats = snapshotEdgeStats()
  status = result if result != 'progress'

resetScene = ->
  status = 'loading'
  assembly = freshAssembly()
  mdlVerts.children = [] if mdlVerts?
  syncFromAssembly()
  edgeStats = snapshotEdgeStats()
  status = 'ready'

# ---------- toggle plumbing ----------
toggleFill = ->
  return unless mdlPieces?
  alpha = if showFill then 0xD8 else 0x00
  # Two assignments flip every triangle — materials are shared.
  fillMatT.color.a = alpha
  fillMatG.color.a = alpha
  if showFill
    if assembly.pieces.length <= 40
      mdlLabels.children = []
      mdlLabels.add pieceLabelShape(p) for p in assembly.pieces
  else
    mdlLabels.children = []
  ctx.render() if ctx?

toggleEdges = ->
  return unless mdlPieces?
  w = if showEdges then 0.8 else 0
  for path in mdlPieces.children
    for surf in path.surfaces
      surf['stroke-width'] = w
  ctx.render() if ctx?

toggleVerts = ->
  return unless mdlVerts?
  if showVerts
    rebuildVertexMarkers()
  else
    mdlVerts.children = []
  ctx.render() if ctx?
</script>

<svelte:head><title>Robinson WFC · Tiles</title></svelte:head>

<div class="page">
  <h1>Robinson WFC Tiles</h1>
  <p class="lede">
    Exact-PhiBase positions in the (e₀, e₇₂) basis. Perimeter-first
    heuristic walks bottom → right → top → left around the target rectangle,
    then fills interior with min-entropy WFC. status: <code>{status}</code>.
  </p>

  {#if status === 'error'}
    <pre class="err">{errorMsg}</pre>
  {:else}
    <figure>
      <svg
        bind:this={svgEl}
        viewBox={`0 0 ${svgW} ${svgH}`}
        width={svgW}
        height={svgH}
        style="background:#f4f1ea; border-radius:6px;"
      ></svg>
    </figure>

    <div class="controls">
      <button on:click={runWfc} disabled={!['ready', 'maxSteps'].includes(status)}>▶ Run WFC</button>
      <button on:click={stepOnce} disabled={!['ready', 'maxSteps'].includes(status)}>Step</button>
      <button on:click={resetScene}>Reset</button>
      <label class="toggle"><input type="checkbox" bind:checked={showFill}  on:change={toggleFill}/> fill</label>
      <label class="toggle"><input type="checkbox" bind:checked={showEdges} on:change={toggleEdges}/> edges</label>
      <label class="toggle"><input type="checkbox" bind:checked={showVerts} on:change={toggleVerts}/> vertices</label>
    </div>
    <pre class="hud">{edgeStats}</pre>

    {#if sceneInfo}
      <details>
        <pre>{sceneInfo}</pre>
      </details>
    {/if}
  {/if}
</div>

<style>
  .page { max-width: 820px; margin: 1rem auto; padding: 0 1rem 6rem; font-family: system-ui, sans-serif; }
  h1 { font-size: 1.3rem; margin-bottom: 0.25rem; }
  .lede { color: #555; margin-top: 0; }
  figure { margin: 0.75rem 0; }
  svg { max-width: 100%; height: auto; display: block; }
  .controls { display: flex; gap: 0.5rem; align-items: center; flex-wrap: wrap; margin-top: 0.5rem; }
  button { padding: 0.4rem 0.9rem; cursor: pointer; }
  .toggle { display: inline-flex; gap: 0.25rem; align-items: center; font-size: 0.9rem; user-select: none; cursor: pointer; padding: 0.2rem 0.4rem; }
  .toggle input { margin: 0; }
  .hud { margin: 0.4rem 0 1in; color: #555; font-size: 0.85rem; white-space: pre-line; }
  code { background: #f0f0f0; padding: 0 0.3rem; border-radius: 3px; }
  pre { background: #f7f4ee; padding: 0.6rem; border-radius: 4px; font-size: 0.82rem; overflow-x: auto; }
  pre.err { background: #fdecea; color: #9a1d1d; }
  details { margin-top: 0.5rem; }
</style>
