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
pieces       = []          # snapshot of placed Piece objects
verts        = []          # snapshot of vertex Cartesian positions
edgeStats    = ''
assembly     = null

# Visibility toggles. fill = colored polygon interiors + T/G labels;
# edges = the dark strokes; verts = dots at every vertex.
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

# Convert a piece into SVG attributes.
pieceToSvg = (p) ->
  pts = ""
  for v in p.verts
    [x, y] = v.pos.toCartesian()
    px = x * SCALE
    py = -y * SCALE                       # flip y for SVG screen coords
    pts += "#{px.toFixed(2)},#{py.toFixed(2)} "
  fill = if p.kind == 'T' then '#d4a464' else '#7baad4'
  { points: pts.trim(), fill: fill, kind: p.kind }

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

snapshotPieces = -> assembly.pieces.slice()

snapshotVerts = -> (v.pos.toCartesian() for v in assembly.vertices)

snapshotEdgeStats = ->
  s = assembly.stats()
  recent = assembly.log[Math.max(0, assembly.log.length - 5)...].map((e) -> "#{e.op}:#{e.kind}#{if e.side then '/' + e.side else ''}").join(' → ')
  base = "pieces=#{s.pieceCount}  vertices=#{s.vertexCount}  edges=#{s.edgeCount}  open=#{s.openEdgeCount}  insideOpen=#{s.insideOpenCount}  closed=#{s.closedVertexCount}\nlast 5: #{recent}"
  # Rejection diagnostic — per-reason totals across all open edges, plus
  # any "dead" open edges where every candidate was rejected.
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

onMount ->
  try
    await Promise.all [initAngles(), initWords(), initRobinson()]
    assembly = freshAssembly()
    pieces = snapshotPieces()
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
  pieces = snapshotPieces()
  verts = snapshotVerts()
  edgeStats = snapshotEdgeStats()
  maxSteps = 800
  count = 0
  tick = ->
    return unless status == 'running'
    if count >= maxSteps
      status = 'maxSteps'
      return
    result = assembly.step()
    pieces = snapshotPieces()
    verts = snapshotVerts()
    edgeStats = snapshotEdgeStats()
    count += 1
    if result == 'progress'
      setTimeout tick, 0
    else
      status = result
  setTimeout tick, 0

stepOnce = ->
  return if status not in ['ready', 'running', 'maxSteps']
  result = assembly.step()
  pieces = snapshotPieces()
  verts = snapshotVerts()
  edgeStats = snapshotEdgeStats()
  status = result if result != 'progress'

resetScene = ->
  status = 'loading'
  assembly = freshAssembly()
  pieces = snapshotPieces()
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
        {#each pieces as p}
          {@const s = pieceToSvg(p)}
          <polygon
            points={s.points}
            fill={showFill ? s.fill : 'none'}
            stroke={showEdges ? '#222' : 'none'}
            stroke-width={showEdges ? 0.8 : 0}
            opacity={showFill ? 0.85 : 1}
          />
          {#if showFill && pieces.length <= 40}
            {@const c = cartCentroid(p)}
            <text
              x={c[0].toFixed(2)}
              y={c[1].toFixed(2)}
              text-anchor="middle"
              dominant-baseline="central"
              font-size="11"
              font-family="serif"
              fill="#222"
            >{s.kind}</text>
          {/if}
        {/each}
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
      <label class="toggle"><input type="checkbox" bind:checked={showFill}/> fill</label>
      <label class="toggle"><input type="checkbox" bind:checked={showEdges}/> edges</label>
      <label class="toggle"><input type="checkbox" bind:checked={showVerts}/> vertices</label>
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
