<script lang="coffeescript" type="text/coffeescript">
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
verts        = []          # snapshot of vertex Cartesian positions (only used when showVerts is on)
edgeStats    = ''
assembly     = null
renderAvgMs  = 0           # running mean of step→paint wall time
renderCount  = 0
# Imperative SVG group for placed pieces. Bound to a <g> in the template;
# each placement appends ONE <polygon> child, so SVG work per tick is O(1)
# in the number of already-placed pieces.
piecesGroup  = null
pieceCount   = 0           # how many polygons currently in piecesGroup (for HUD + label gate)
SVG_NS       = 'http://www.w3.org/2000/svg'

# Visibility toggles. fill = colored polygon interiors + T/G labels;
# edges = the dark strokes; verts = dots at every vertex.
showFill  = true
showEdges = true
showVerts = false
showDiagnostics = false   # diagnose() + insideOpen are O(openEdges × candidates × N); off by default

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

# Build the points string for one piece.
pointsFor = (p) ->
  pts = ""
  for v in p.verts
    [x, y] = v.pos.toCartesian()
    px = x * SCALE
    py = -y * SCALE                       # flip y for SVG screen coords
    pts += "#{px.toFixed(2)},#{py.toFixed(2)} "
  pts.trim()

fillFor = (kind) -> if kind == 'T' then '#d4a464' else '#7baad4'

# Append one <polygon> for a freshly placed piece. The element's identity
# stays put — no array re-iteration, no reactive re-eval per existing piece.
appendPiecePolygon = (p) ->
  return unless piecesGroup?
  poly = document.createElementNS(SVG_NS, 'polygon')
  poly.setAttribute 'points', pointsFor(p)
  poly.setAttribute 'fill', (if showFill then fillFor(p.kind) else 'none')
  poly.setAttribute 'stroke', (if showEdges then '#222' else 'none')
  poly.setAttribute 'stroke-width', (if showEdges then '0.8' else '0')
  poly.setAttribute 'opacity', (if showFill then '0.85' else '1')
  poly.dataset.kind = p.kind
  piecesGroup.appendChild poly

clearPiecesGroup = ->
  return unless piecesGroup?
  while piecesGroup.firstChild
    piecesGroup.removeChild piecesGroup.firstChild

# Re-apply fill/edge attributes to existing polygons when a toggle flips.
# Walks the current children once — no array snapshot, no reactive churn.
restylePiecePolygons = ->
  return unless piecesGroup?
  for poly in piecesGroup.children
    kind = poly.dataset.kind
    poly.setAttribute 'fill', (if showFill then fillFor(kind) else 'none')
    poly.setAttribute 'stroke', (if showEdges then '#222' else 'none')
    poly.setAttribute 'stroke-width', (if showEdges then '0.8' else '0')
    poly.setAttribute 'opacity', (if showFill then '0.85' else '1')


cartCentroid = (p) ->
  cx = 0; cy = 0
  for v in p.verts
    [x, y] = v.pos.toCartesian()
    cx += x
    cy += y
  [cx / 3 * SCALE, -cy / 3 * SCALE]

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

# Small reactive snapshot for the T/G text labels — only used while the
# build is small enough to label clearly. Stays empty past 40 pieces.
labelPieces = []
syncLabelPieces = ->
  labelPieces = if assembly.pieces.length <= 40 then assembly.pieces.slice() else []

snapshotVerts = -> (v.pos.toCartesian() for v in assembly.vertices)

# Push every piece currently in the assembly into the SVG group. Used after
# fresh assembly / reset / mount, when the seed has already placed pieces.
seedSvgFromAssembly = ->
  clearPiecesGroup()
  for p in assembly.pieces
    appendPiecePolygon p
  pieceCount = assembly.pieces.length

snapshotEdgeStats = ->
  recent = assembly.log[Math.max(0, assembly.log.length - 5)...].map((e) -> "#{e.op}:#{e.kind}#{if e.side then '/' + e.side else ''}").join(' → ')
  avg = if renderCount > 0 then "  avgRender=#{renderAvgMs.toFixed(1)}ms (n=#{renderCount})" else ''
  # Cheap counts — no legalPieces enumeration.
  pCount      = assembly.pieces.length
  vertexCount = assembly.vertices.length
  edgeCount   = assembly.edges.length
  openCount   = assembly.openEdges.size
  closedVerts = (v for v in assembly.vertices when v.status == 'closed').length
  baseLeft = "pieces=#{pCount}  vertices=#{vertexCount}  edges=#{edgeCount}  open=#{openCount}  closed=#{closedVerts}"
  base = "#{baseLeft}#{avg}\nlast 5: #{recent}"
  return base unless showDiagnostics
  # Heavy path — only when explicitly requested. stats() recomputes
  # insideOpen via legalPieces; diagnose() walks every candidate per
  # open edge. Together they triple the per-tick cost.
  s = assembly.stats()
  d = assembly.diagnose()
  insideLine = "insideOpen=#{s.insideOpenCount}"
  reasons = Object.entries(d.perReason).sort((a, b) -> b[1] - a[1]).map(([r, c]) -> "#{r}=#{c}").join(' ')
  reasonsLine = if reasons then "rejections: #{reasons}" else "rejections: (none)"
  deadLines = if d.deadEdges.length == 0
    "dead-open: none"
  else
    edges = d.deadEdges.map (de) ->
      r = Object.entries(de.reasons).sort((a, b) -> b[1] - a[1]).map(([k, v]) -> "#{k}=#{v}").join(',')
      "  @(#{de.mid[0]}, #{de.mid[1]}) #{de.kind}/dir#{de.dir} tried=#{de.tried}: #{r}"
    "dead-open (#{d.deadEdges.length}):\n#{edges.join('\n')}"
  "#{base}\n#{insideLine}\n#{reasonsLine}\n#{deadLines}"

onMount ->
  try
    await Promise.all [initAngles(), initWords(), initRobinson()]
    assembly = freshAssembly()
    seedSvgFromAssembly()
    syncLabelPieces()
    verts = snapshotVerts()
    edgeStats = snapshotEdgeStats()
    sceneInfo = buildSummary()
    status = 'ready'
  catch err
    errorMsg = err.message ? String(err)
    status = 'error'
    console.error err

runWfc = ->
  # Iterative: one step per animation frame so the SVG paints between
  # placements. Yields to the browser via setTimeout(0).
  status = 'running'
  edgeStats = snapshotEdgeStats()
  maxSteps = 800
  count = 0
  tick = ->
    return unless status == 'running'
    if count >= maxSteps
      status = 'maxSteps'
      return
    t0 = performance.now()
    before = assembly.pieces.length
    result = assembly.step()
    # Append exactly the polygons added by this step (usually 1).
    for i in [before...assembly.pieces.length]
      appendPiecePolygon assembly.pieces[i]
    pieceCount = assembly.pieces.length
    syncLabelPieces() if assembly.pieces.length <= 41   # cross the threshold once
    verts = snapshotVerts() if showVerts
    edgeStats = snapshotEdgeStats()
    # rAF fires after Svelte's microtask flush + browser paint, giving a
    # wall-time estimate that includes the DOM update.
    requestAnimationFrame ->
      dt = performance.now() - t0
      renderCount += 1
      renderAvgMs = renderAvgMs + (dt - renderAvgMs) / renderCount
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
  for i in [before...assembly.pieces.length]
    appendPiecePolygon assembly.pieces[i]
  pieceCount = assembly.pieces.length
  syncLabelPieces() if assembly.pieces.length <= 41
  verts = snapshotVerts() if showVerts
  edgeStats = snapshotEdgeStats()
  status = result if result != 'progress'

resetScene = ->
  status = 'loading'
  renderAvgMs = 0
  renderCount = 0
  assembly = freshAssembly()
  seedSvgFromAssembly()
  syncLabelPieces()
  verts = snapshotVerts()
  edgeStats = snapshotEdgeStats()
  status = 'ready'
</script>

<svelte:head><title>Robinson WFC · Puzzle</title></svelte:head>

<div class="page">
  <h1>Robinson WFC Puzzle</h1>
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
        viewBox={`${-svgW/2} ${-svgH/2} ${svgW} ${svgH}`}
        width={svgW}
        height={svgH}
        style="background:#f4f1ea; border-radius:6px;"
      >
        <!-- target pentagon outline -->
        <polygon
          points={pentagonCorners().map(c => `${(c[0] * SCALE).toFixed(2)},${(-c[1] * SCALE).toFixed(2)}`).join(' ')}
          fill="none"
          stroke="#999"
          stroke-width="1"
          stroke-dasharray="4 4"
        />
        <!-- axes -->
        <line x1="{-svgW/2}" y1="0" x2="{svgW/2}" y2="0" stroke="#dddddd" />
        <line x1="0" y1="{-svgH/2}" x2="0" y2="{svgH/2}" stroke="#dddddd" />
        <!-- Pieces group — populated imperatively, one <polygon> per
             placement. Bypasses each-block re-iteration entirely. -->
        <g bind:this={piecesGroup}></g>
        {#if showFill && labelPieces.length > 0 && labelPieces.length <= 40}
          {#each labelPieces as p}
            {@const c = cartCentroid(p)}
            <text
              x={c[0].toFixed(2)}
              y={c[1].toFixed(2)}
              text-anchor="middle"
              dominant-baseline="central"
              font-size="11"
              font-family="serif"
              fill="#222"
            >{p.kind}</text>
          {/each}
        {/if}
        {#if showVerts}
          {#each verts as [vx, vy]}
            <circle
              cx={(vx * SCALE).toFixed(2)}
              cy={(-vy * SCALE).toFixed(2)}
              r="2"
              fill="#222"
            />
          {/each}
        {/if}
      </svg>
    </figure>

    <div class="controls">
      <button on:click={runWfc} disabled={!['ready', 'maxSteps'].includes(status)}>▶ Run WFC</button>
      <button on:click={stepOnce} disabled={!['ready', 'maxSteps'].includes(status)}>Step</button>
      <button on:click={resetScene}>Reset</button>
      <label class="toggle"><input type="checkbox" bind:checked={showFill}  on:change={restylePiecePolygons}/> fill</label>
      <label class="toggle"><input type="checkbox" bind:checked={showEdges} on:change={restylePiecePolygons}/> edges</label>
      <label class="toggle"><input type="checkbox" bind:checked={showVerts} on:change={() => verts = snapshotVerts()}/> vertices</label>
      <label class="toggle" title="Run stats() + diagnose() each step — triples per-tick cost"><input type="checkbox" bind:checked={showDiagnostics} on:change={() => edgeStats = snapshotEdgeStats()}/> diagnostics</label>
    </div>
    <pre class="hud">{edgeStats}</pre>

    {#if sceneInfo}
      <details>
        <summary>palette / vertex words sanity</summary>
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
