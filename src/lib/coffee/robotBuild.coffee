# robotBuild.coffee
#
# Pure state machine for the robot. No DOM, no seen, no GeoPhi imports.
# The caller injects a `candidateProvider(edge, state) -> [apex, ...]` and a
# `scorer(apex, edge, state) -> number` (lower is better). This keeps the
# module testable headless and lets the real playground swap in
# GeoPhi.goldenApexCandidates + a phi-shell-distance scorer at runtime.
#
# Apex coordinates are plain Cartesian `[x, y, z]` arrays throughout. SixPhi
# round-tripping is the caller's responsibility (the playground does that
# on the way in via GeoPhi.createPhiPoint).

DEDUP_EPS = 1e-4
MAX_STEPS_DEFAULT = 200

export edgeKey = (a, b) -> if a < b then "#{a}-#{b}" else "#{b}-#{a}"

# Linear search vertex dedup. With <~500 vertices and ~3 lookups per step the
# cost is negligible; trade simplicity for asymptotics here.
export findVertex = (vertices, [x, y, z]) ->
  for v, i in vertices
    return i if Math.abs(v[0]-x) < DEDUP_EPS and Math.abs(v[1]-y) < DEDUP_EPS and Math.abs(v[2]-z) < DEDUP_EPS
  -1

# Add a single triangle (three Cartesian verts) to an existing state with full
# dedup and frontier/edgeCount bookkeeping. Returns { triIdx, newVerts: [{
# idx, cart }, ...] } so the caller (the bridge) can keep its sixPhiByVertex
# array aligned. Used by multi-seed initializers; ordinary growth still goes
# through frontierStep.
export addTriangleToState = (state, [v0, v1, v2]) ->
  newVerts = []
  vIdxs = for v in [v0, v1, v2]
    idx = findVertex(state.vertices, v)
    if idx == -1
      state.vertices.push v
      idx = state.vertices.length - 1
      newVerts.push { idx, cart: v }
    idx
  triIdx = state.triangles.length
  state.triangles.push vIdxs
  for [u, w] in [[vIdxs[0], vIdxs[1]], [vIdxs[1], vIdxs[2]], [vIdxs[2], vIdxs[0]]]
    k = edgeKey(u, w)
    state.edgeCount[k] = (state.edgeCount[k] ? 0) + 1
    if state.edgeCount[k] < 2
      state.frontier.push { a: u, b: w, parentTri: triIdx }
  { triIdx, newVerts }

export createEmptyState = ->
  vertices: []
  triangles: []
  frontier: []
  edgeCount: {}
  step: 0
  status: 'idle'
  maxSteps: MAX_STEPS_DEFAULT
  history: []   # one entry per applied step: { edge, apex, triIdx }

# seedTriangle: [[x,y,z], [x,y,z], [x,y,z]] — convenience for the single-seed case.
export createState = (seedTriangle) ->
  state = createEmptyState()
  addTriangleToState(state, seedTriangle) if seedTriangle?
  state

# Internal: place an apex by extending `edge` and update bookkeeping.
applyStep = (state, edge, apex) ->
  vIdx = findVertex(state.vertices, apex)
  if vIdx == -1
    state.vertices.push apex
    vIdx = state.vertices.length - 1
  triIdx = state.triangles.length
  state.triangles.push [edge.a, edge.b, vIdx]
  for [u, v] in [[edge.a, edge.b], [edge.b, vIdx], [vIdx, edge.a]]
    k = edgeKey(u, v)
    state.edgeCount[k] = (state.edgeCount[k] ? 0) + 1
    # Only push to frontier if still open (count < 2).
    if state.edgeCount[k] < 2
      state.frontier.push { a: u, b: v, parentTri: triIdx }
  state.step += 1
  state.history.push { edge, apex, triIdx, vIdx }
  triIdx

export isOpen = (state, edge) ->
  (state.edgeCount[edgeKey(edge.a, edge.b)] ? 0) < 2

# Pop edges from the frontier, skipping any that closed since they were pushed.
nextOpenEdge = (state) ->
  while state.frontier.length > 0
    edge = state.frontier.shift()
    return edge if isOpen(state, edge)
  null

# One step: pop an open edge, ask for apex candidates, score, place the best.
# Returns the placement record, or null if the build is done.
export frontierStep = (state, candidateProvider, scorer) ->
  if state.step >= state.maxSteps
    state.status = 'done'
    return null
  edge = nextOpenEdge(state)
  unless edge?
    state.status = 'done'
    return null
  candidates = candidateProvider(edge, state) ? []
  if candidates.length == 0
    # No legal apex — drop this edge and try the next one. (The edge will
    # remain in edgeCount with count=1; if a later step closes it from the
    # other side, fine; otherwise it's a permanent hole in the hull.)
    return frontierStep(state, candidateProvider, scorer)
  best = null
  bestScore = Infinity
  for cand in candidates
    s = scorer(cand, edge, state)
    if s < bestScore
      bestScore = s
      best = cand
  return frontierStep(state, candidateProvider, scorer) unless best?
  triIdx = applyStep(state, edge, best)
  { edge, apex: best, score: bestScore, triIdx }

# Convenience: run until done.
export runToCompletion = (state, candidateProvider, scorer) ->
  state.status = 'running'
  while state.status == 'running' or state.status == 'idle'
    step = frontierStep(state, candidateProvider, scorer)
    break unless step?
  state

# Diagnostics
export openEdges = (state) ->
  k for k, c of state.edgeCount when c < 2

export closedEdges = (state) ->
  k for k, c of state.edgeCount when c == 2

export maxRadius = (state) ->
  best = 0
  for [x, y, z] in state.vertices
    r2 = x*x + y*y + z*z
    best = r2 if r2 > best
  Math.sqrt(best)
