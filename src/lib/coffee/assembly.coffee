# assembly.coffee
#
# L4 of the WFC stack: the Assembly that runs the Wave-Function-Collapse
# loop over Robinson tiles, with a perimeter-first heuristic.
#
# All vertex identity, edge identity, and overlap tests are EXACT — they
# use PhiPoint2D arithmetic over Z[φ]. The only float arithmetic is:
#   (1) SVG rendering coordinates (via PhiPoint2D.toCartesian), and
#   (2) Heuristic ordering of open edges by Cartesian midpoint (sorts
#       only; never affects legality), and
#   (3) The spatial bucketing for overlap/proximity acceleration (cell
#       indices are floor(x / cellSize); the buckets only narrow the
#       candidate set — every actual overlap or too-close test still
#       uses exact PhiBase arithmetic, so legality is unaffected).
#
# Perimeter heuristic:
#   The assembly starts from a single seed piece and walks around the
#   outside of the canvas in 4 phases: bottom → right → top → left. In
#   each phase we prefer open edges whose midpoints lie OUTSIDE the
#   canvas on the corresponding side, advancing the chain in the phase's
#   direction. After the perimeter is closed (no more eligible open edges
#   outside the canvas), the loop drops into the interior phase, which
#   uses the standard min-entropy selection over interior open edges.
#
# Acceleration (uniform spatial grid).
#   `tryPlacement` was originally O(N) per call: the "too close" scan
#   (line ~249) walks every vertex and `overlapsExisting` walks every
#   piece, both for every candidate. Multiplied by `legalPieces` over
#   every open edge per `step()` — and again per `stats()` and again
#   per `diagnose()` for the HUD — total work was O(N^2.5) for an N-
#   piece fill, which manifests as the page slowing to ~0.7 s per tile
#   at 1,100 edges.
#
#   The fix is a uniform spatial grid keyed by Cartesian cell. Each
#   placed piece is registered in the cells its AABB touches; each
#   vertex is registered in its cell. `overlapsExisting` only tests
#   pieces in cells the candidate's AABB intersects; the too-close
#   scan only tests vertices in the candidate's cell and its 8
#   neighbours. Per-query cost drops from O(N) to O(1) amortised; the
#   full fill goes from O(N^2.5) to O(N · √N).
#
#   The buckets are pure acceleration: the candidate set they produce
#   is then filtered by the *same* exact PhiBase tests as before, so
#   legality and exactness are preserved. If a piece's AABB and the
#   candidate's AABB overlap, they share at least one cell, so the
#   query is sound (no false negatives).

import { PhiBase } from '$lib/coffee/phiBase.coffee'
import { PhiPoint2D, getUnitDisp, getLongDisp, classifyDisplacement, signedArea2 } from './phiPoint2D.coffee'

# Pentagon outward-normal directions: 5 unit vectors at 36°, 108°, 180°,
# 252°, 324° (the odd-k entries of UNIT_DISP). Each defines one half-plane
# constraint. Computed once at module load.
PENTAGON_NORMALS = (getUnitDisp(k) for k in [1, 3, 5, 7, 9])
import { Vertex, Edge, Piece, getTemplate, pieceKinds, buildSeed, makeEdge } from './robinson.coffee'
import { isLegalPrefix, isClosed } from './vertexWords.coffee'

# Sign of a PhiBase. For integer p, n (or small Q[φ] values) the float
# evaluation is exact-enough — `phi` is irrational so p·φ + n = 0 only
# when p = n = 0, and the float gap to the nearest representable nonzero
# Z[φ] element exceeds 1e-12 for our small coefficients.
phiBaseSign = (pb) ->
  v = pb.toFloat()
  return 1 if v > 1e-12
  return -1 if v < -1e-12
  0

# PhiBase strict-less-than. Returns true iff p < q exactly.
phiLess = (p, q) -> phiBaseSign(p.sub(q)) < 0
# PhiBase strict-greater-than.
phiGreater = (p, q) -> phiBaseSign(p.sub(q)) > 0

# PhiBase value `1` (= 0·φ + 1). Used as the sub-scale-gap squared-distance
# threshold: in a single-scale Robinson tiling the minimum distance between
# two distinct vertices is exactly 1 (the short edge length), so any d² < 1
# but > 0 is a sub-scale-gap signal.
PB_ONE = new PhiBase(0, 1)

# Exact PhiBase test for "two PhiPoint2D positions are strictly closer than
# one tileScale's short edge but not coincident". `thresholdSq` is
# tileScale² — the squared minimum legitimate vertex separation in the
# current build's lattice unit.
strictlyTooCloseToVertex = (cand, other, thresholdSq) ->
  dSq = cand.sub(other.pos).magSquared()
  return false if phiBaseSign(dSq) == 0
  phiLess(dSq, thresholdSq)

# Strict-interior point-in-triangle. ABC in CCW or CW order doesn't matter
# — we just check that all three signed-area signs agree and are nonzero.
pointStrictlyInTriangle = (P, A, B, C) ->
  s1 = phiBaseSign(signedArea2(A, B, P))
  s2 = phiBaseSign(signedArea2(B, C, P))
  s3 = phiBaseSign(signedArea2(C, A, P))
  return false if s1 == 0 or s2 == 0 or s3 == 0
  s1 == s2 and s2 == s3

# Proper segment crossing: returns true iff segments (p1,p2) and (q1,q2)
# intersect strictly inside both — endpoints touching/coinciding do NOT
# count.
segmentsProperlyCross = (p1, p2, q1, q2) ->
  return false if p1.equals(q1) or p1.equals(q2) or p2.equals(q1) or p2.equals(q2)
  d1 = phiBaseSign(signedArea2(q1, q2, p1))
  d2 = phiBaseSign(signedArea2(q1, q2, p2))
  d3 = phiBaseSign(signedArea2(p1, p2, q1))
  d4 = phiBaseSign(signedArea2(p1, p2, q2))
  return false if d1 == 0 or d2 == 0 or d3 == 0 or d4 == 0
  d1 != d2 and d3 != d4

# Compute C = A + (scaled displacement at the right angle and length).
# `tileScale` is a PhiBase: at 1 we use the canonical unit/long; at 1/φ we
# use the next rung down (smaller tiles).
computeC = (A, edgeDir, angleAtA, lenACShort, tileScale) ->
  dirAC = ((edgeDir + Math.round(angleAtA / 36)) % 10 + 10) % 10
  base = if lenACShort then getUnitDisp(dirAC) else getLongDisp(dirAC)
  A.pos.add(base.scale(tileScale))

# Spatial-grid cell key from a Cartesian (x, y).  The grid is a pure
# acceleration structure; cell membership decisions use float arithmetic,
# but the geometric tests run on the resulting (small) candidate set are
# exact PhiBase.  Cell size is set in the Assembly constructor based on
# tileScale; the helper takes it as an argument to stay stateless.
spatialCellKey = (x, y, cellSize) ->
  "#{Math.floor(x / cellSize)},#{Math.floor(y / cellSize)}"

# --- Assembly ------------------------------------------------------------
export class Assembly
  # target: a regular pentagon centred in the (e₀, e₇₂) basis. Shape:
  #   {
  #     center:           PhiPoint2D    # centre of the pentagon
  #     apothem2:         PhiBase       # 2 × strict apothem
  #     apothem2Overhang: PhiBase       # 2 × relaxed apothem (= apothem + 1)
  #   }
  # A point is inside iff (p − center)·d ≤ apothem for every PENTAGON_NORMALS
  # direction d. Doubled comparison (`twoDot` ≤ `apothem2`) keeps every
  # arithmetic step in Z[φ] — no Cartesian conversion at the legality layer.
  constructor: (@target) ->
    @vertices = []
    @edges = []
    @pieces = []
    @openEdges = new Set()
    @vertexByKey = new Map()             # PhiPoint2D key → Vertex (exact dedup)
    @edgeByKey = new Map()               # "v0Key|v1Key" sorted → Edge
    @log = []
    # tileScale: lattice unit for this build (PhiBase). Default 1 keeps the
    # canonical Robinson short/long edges; set to PhiBase(1, -1) = 1/φ for
    # the next rung down (smaller tiles, more decisions per fill).
    @tileScale = @target.tileScale ? PB_ONE
    @tileScaleSq = @tileScale.mul(@tileScale)

    # Spatial grid for overlap + too-close acceleration.  Cell size is
    # chosen so a candidate's AABB touches at most a 2×2 cell block
    # (cellSize ≥ largest piece dimension = tileScale × 1) and so the
    # 3×3 vertex-cell neighbourhood covers the too-close radius
    # (cellSize ≥ tileScale).  Using max(tileScale, 1) handles both
    # the canonical case and the smaller-tile sub-scale levels.
    @spatialCellSize = Math.max(@tileScale.toFloat(), 1.0)
    @cellPieces      = new Map()         # "i,j" → Set of piece indices
    @cellVerts       = new Map()         # "i,j" → Set of vertex indices

  # ---- vertex / edge identity (exact) ----
  findVertex: (pos) ->
    @vertexByKey.get(pos.key()) ? null

  addOrFindVertex: (pos) ->
    k = pos.key()
    existing = @vertexByKey.get(k)
    return existing if existing?
    v = new Vertex(pos)
    @vertices.push v
    @vertexByKey.set k, v
    @_registerVertexIdx(@vertices.length - 1)
    v

  edgeKeyFor: (v0, v1) ->
    k0 = v0.pos.key()
    k1 = v1.pos.key()
    if k0 < k1 then "#{k0}|#{k1}" else "#{k1}|#{k0}"

  findEdge: (v0, v1) ->
    @edgeByKey.get(@edgeKeyFor(v0, v1)) ? null

  registerEdge: (edge) ->
    @edgeByKey.set @edgeKeyFor(edge.v0, edge.v1), edge

  # ---- spatial-index registration ----
  # Drop a vertex's array index into its Cartesian-cell bucket.  Called
  # whenever a new vertex is added (seed + addOrFindVertex).
  _registerVertexIdx: (vIdx) ->
    v = @vertices[vIdx]
    [x, y] = v.pos.toCartesian()
    key = spatialCellKey(x, y, @spatialCellSize)
    set = @cellVerts.get(key)
    unless set?
      set = new Set()
      @cellVerts.set(key, set)
    set.add(vIdx)
    return

  # Compute all spatial-cell keys touched by a piece's AABB.
  _pieceCellKeys: (piece) ->
    carts = (v.pos.toCartesian() for v in piece.verts)
    xMin = carts[0][0]; xMax = carts[0][0]
    yMin = carts[0][1]; yMax = carts[0][1]
    for [x, y] in carts[1..]
      xMin = x if x < xMin
      xMax = x if x > xMax
      yMin = y if y < yMin
      yMax = y if y > yMax
    cs = @spatialCellSize
    iMin = Math.floor(xMin / cs); iMax = Math.floor(xMax / cs)
    jMin = Math.floor(yMin / cs); jMax = Math.floor(yMax / cs)
    out = []
    for i in [iMin..iMax]
      for j in [jMin..jMax]
        out.push "#{i},#{j}"
    out

  # Drop a piece's array index into every cell its AABB touches.
  _registerPieceIdx: (pieceIdx) ->
    piece = @pieces[pieceIdx]
    for key in @_pieceCellKeys(piece)
      set = @cellPieces.get(key)
      unless set?
        set = new Set()
        @cellPieces.set(key, set)
      set.add(pieceIdx)
    return

  # ---- seeding ----
  # Place the seed piece at the pentagon's centre. The seed sits inside the
  # pentagon by construction (center is the most-interior point), and its
  # three open edges all have legal placements whose new vertex stays
  # inside.
  seed: (kind = 'T') ->
    p = buildSeed(kind, 0, @tileScale)
    offset = @target.center
    for v in p.verts
      v.pos = v.pos.add(offset)
    for v in p.verts
      @vertices.push v
      @vertexByKey.set v.pos.key(), v
      @_registerVertexIdx(@vertices.length - 1)
    for e in p.edges
      @edges.push e
      @registerEdge e
      @openEdges.add e
    @pieces.push p
    @_registerPieceIdx(@pieces.length - 1)
    @log.push { op: 'seed', kind, pieceIdx: @pieces.length - 1 }
    p

  # Pentagon inside test, parameterised by the doubled apothem threshold.
  # Used twice: once with the strict threshold (midpoint selection tier)
  # and once with the relaxed threshold (new-vertex legality with overhang).
  isInsidePentagon: (pos, thresholdTwo) ->
    rel = pos.sub(@target.center)
    for d in PENTAGON_NORMALS
      return false if phiGreater(rel.twoDot(d), thresholdTwo)
    true

  # Relaxed (one short-edge overhang) — applied to new vertices of legal
  # placements. A tile may poke one edge past the pentagon side.
  isVertexInCanvas: (pos) ->
    @isInsidePentagon(pos, @target.apothem2Overhang)

  # Strict pentagon — applied to open-edge midpoints for selection tiering.
  isPointStrictlyInsideCanvas: (pos) ->
    @isInsidePentagon(pos, @target.apothem2)

  # ---- legality enumeration ----
  # All legal placements for an open edge e. Each placement is a record
  # consumable by placePlacement(); it records every PhiPoint2D needed.
  legalPieces: (e) ->
    return [] unless e.isOpen()
    out = []
    for kind in pieceKinds()
      template = getTemplate(kind)
      for i in [0...3]
        # Skip if edge length kind doesn't match this template edge.
        templateLen = template.edgeLengths[i]
        templateKind = if templateLen[0] == 1 and templateLen[1] == 0 then 'short' else 'long'
        continue unless templateKind == e.kind
        for side in ['left', 'right']
          continue if side == 'left'  and e.left?
          continue if side == 'right' and e.right?
          placement = @tryPlacement(e, kind, i, side, template)
          out.push placement if placement?
    out

  # tryPlacement returns the placement record on success, or null on
  # rejection. If `rejections` is a non-null array, the SPECIFIC rejection
  # reason (string) is pushed onto it before returning null. This lets the
  # diagnose() method tabulate why each candidate was thrown out without
  # changing the function's primary signature.
  tryPlacement: (e, kind, edgeIdx, side, template, rejections = null) ->
    reject = (reason) ->
      rejections?.push(reason)
      null
    aIdx = edgeIdx
    bIdx = (edgeIdx + 1) % 3
    cIdx = (edgeIdx + 2) % 3
    # Side decides which vertex of e plays the role of A (the angle-bearer
    # for vertexAngles[aIdx]).
    [A, B] = if side == 'left' then [e.v0, e.v1] else [e.v1, e.v0]
    dirAB = if side == 'left' then e.dir else (e.dir + 5) % 10
    angleAtA = template.vertexAngles[aIdx]
    angleAtB = template.vertexAngles[bIdx]
    angleAtC = template.vertexAngles[cIdx]
    # C edge in the template runs C → A (edges[cIdx]); length matches
    # whatever the template says.
    lenCA = template.edgeLengths[cIdx]
    lenACShort = lenCA[0] == 1 and lenCA[1] == 0
    cPos = computeC(A, dirAB, angleAtA, lenACShort, @tileScale)
    # Vertex-word legality at A and B (always present).
    return reject('wordA') unless isLegalPrefix(A.word.concat angleAtA)
    return reject('wordB') unless isLegalPrefix(B.word.concat angleAtB)
    # If C coincides with an existing vertex, its word legality is also a
    # gate, and we must check we won't over-saturate any existing edges
    # going to C.
    existingC = @findVertex(cPos)
    closesBC = null
    closesCA = null
    if existingC?
      return reject('wordC') unless isLegalPrefix(existingC.word.concat angleAtC)
      eBC = @findEdge(B, existingC)
      if eBC?
        # Existing B→C edge: must still be open (count=1), else we'd push
        # it to 3 incident pieces and break the 2-manifold property.
        return reject('satBC') unless eBC.isOpen()
        closesBC = eBC
      eCA = @findEdge(existingC, A)
      if eCA?
        return reject('satCA') unless eCA.isOpen()
        closesCA = eCA
    else
      # Brand-new vertex: reject if it sits strictly closer than the short
      # edge to any existing vertex.  Localised via the vertex spatial
      # index — only the cell containing cPos and its 8 neighbours can
      # hold a vertex inside the too-close radius (which is ≤ tileScale ≤
      # spatialCellSize by construction).
      [cx, cy] = cPos.toCartesian()
      cs = @spatialCellSize
      ci = Math.floor(cx / cs)
      cj = Math.floor(cy / cs)
      for di in [-1..1]
        for dj in [-1..1]
          cellSet = @cellVerts.get("#{ci + di},#{cj + dj}")
          continue unless cellSet?
          for vIdx from cellSet
            v = @vertices[vIdx]
            return reject('tooClose') if strictlyTooCloseToVertex(cPos, v, @tileScaleSq)
    # Geometric overlap with any already-placed piece.
    return reject('overlap') if @overlapsExisting(A.pos, B.pos, cPos)
    {
      kind, edgeIdx, side, A, B, cPos, existingC,
      angleAtA, angleAtB, angleAtC,
      seedEdge: e,
      closesBC: closesBC      # null or existing open Edge (will be closed)
      closesCA: closesCA      # null or existing open Edge
    }

  # True if the candidate triangle overlaps any already-placed piece
  # (shared boundary doesn't count).
  #
  # Localised via the piece spatial index: a piece can overlap the
  # candidate only if its AABB shares at least one cell with the
  # candidate's AABB.  We collect distinct piece indices from the cells
  # the candidate touches and run the exact PhiBase tests only on that
  # set — no full @pieces sweep.
  overlapsExisting: (pa, pb, pc) ->
    [pax, pay] = pa.toCartesian()
    [pbx, pby] = pb.toCartesian()
    [pcx, pcy] = pc.toCartesian()
    xMin = Math.min(pax, pbx, pcx); xMax = Math.max(pax, pbx, pcx)
    yMin = Math.min(pay, pby, pcy); yMax = Math.max(pay, pby, pcy)
    cs = @spatialCellSize
    iMin = Math.floor(xMin / cs); iMax = Math.floor(xMax / cs)
    jMin = Math.floor(yMin / cs); jMax = Math.floor(yMax / cs)
    tested = new Set()
    for i in [iMin..iMax]
      for j in [jMin..jMax]
        cellSet = @cellPieces.get("#{i},#{j}")
        continue unless cellSet?
        cellSet.forEach (idx) -> tested.add(idx)
    for pieceIdx from tested
      piece = @pieces[pieceIdx]
      [qa, qb, qc] = (v.pos for v in piece.verts)
      # Any vertex strictly inside the other triangle.
      return true if pointStrictlyInTriangle(pa, qa, qb, qc)
      return true if pointStrictlyInTriangle(pb, qa, qb, qc)
      return true if pointStrictlyInTriangle(pc, qa, qb, qc)
      return true if pointStrictlyInTriangle(qa, pa, pb, pc)
      return true if pointStrictlyInTriangle(qb, pa, pb, pc)
      return true if pointStrictlyInTriangle(qc, pa, pb, pc)
      # Any proper edge crossing.
      candEdges = [[pa, pb], [pb, pc], [pc, pa]]
      pieceEdges = [[qa, qb], [qb, qc], [qc, qa]]
      for [s1, s2] in candEdges
        for [t1, t2] in pieceEdges
          return true if segmentsProperlyCross(s1, s2, t1, t2)
    false

  # ---- placement ----
  placePlacement: (placement) ->
    { kind, edgeIdx, side, A, B, cPos, existingC,
      angleAtA, angleAtB, angleAtC, seedEdge } = placement
    C = existingC ? @addOrFindVertex(cPos)
    A.word.push angleAtA
    B.word.push angleAtB
    C.word.push angleAtC
    @updateStatus(A)
    @updateStatus(B)
    @updateStatus(C)
    verts = [null, null, null]
    verts[edgeIdx] = A
    verts[(edgeIdx + 1) % 3] = B
    verts[(edgeIdx + 2) % 3] = C
    edges = [null, null, null]
    for i in [0...3]
      u = verts[i]
      v = verts[(i + 1) % 3]
      existingE = @findEdge(u, v)
      if existingE?
        edges[i] = existingE
      else
        ne = makeEdge(u, v, 0, @tileScale)
        @edges.push ne
        @registerEdge ne
        edges[i] = ne
    piece = new Piece(kind, verts, edges)
    for ed in edges
      if ed.left == piece or ed.right == piece
        # shouldn't happen; defensive
        continue
      if ed.left?
        ed.right = piece
        @openEdges.delete ed
      else if ed.right?
        ed.left = piece
        @openEdges.delete ed
      else
        ed.left = piece
        @openEdges.add ed
    @pieces.push piece
    @_registerPieceIdx(@pieces.length - 1)
    @log.push { op: 'place', kind, side, pieceIdx: @pieces.length - 1 }
    piece

  updateStatus: (v) ->
    s = 0
    s += a for a in v.word
    v.status = if s == 360 and isClosed(v.word) then 'closed' else 'open'

  # ---- termination ----
  isComplete: ->
    for e from @openEdges
      m = e.midpoint()
      if @midInsideTarget(m)
        return false
    true

  # m is a PhiPoint2D. Inside iff aMin ≤ m.a ≤ aMax AND bMin ≤ m.b ≤ bMax,
  # with all comparisons exact via PhiBase signs.
  midInsideTarget: (m) ->
    not phiLess(m.a, @target.aMin) and not phiGreater(m.a, @target.aMax) and
    not phiLess(m.b, @target.bMin) and not phiGreater(m.b, @target.bMax)

  # ---- perimeter heuristic ----
  # All eligibility checks are exact PhiBase sign tests. m is a PhiPoint2D.
  eligibleEdges: ->
    result = []
    for e from @openEdges
      m = e.midpoint()
      ok = switch @phase
        when 'bottom'   then phiLess(m.b, @target.bMin)         # b below canvas
        when 'right'    then phiGreater(m.a, @target.aMax)      # a right of canvas
        when 'top'      then phiGreater(m.b, @target.bMax)      # b above canvas
        when 'left'     then phiLess(m.a, @target.aMin)         # a left of canvas
        when 'interior' then @midInsideTarget(m)
        else false
      result.push { edge: e, mid: m } if ok
    result

  advancePhase: ->
    @phase = switch @phase
      when 'bottom' then 'right'
      when 'right'  then 'top'
      when 'top'    then 'left'
      when 'left'   then 'interior'
      else 'interior'

  # Choose a leading edge for the current phase. Eligibility is exact
  # PhiBase. Ordering converts to float — that's a sorting heuristic, not
  # a legality decision, so float is fine for ranking.
  selectNextEdge: ->
    while @phase != 'interior'
      pool = @eligibleEdges()
      if pool.length == 0
        @advancePhase()
        continue
      pPhase = @phase
      tgt = @target
      # All-past-corner trigger: chain has walked the full side. Use exact
      # PhiBase comparison.
      allPastCorner = pool.every (entry) ->
        switch pPhase
          when 'bottom' then phiGreater(entry.mid.a, tgt.aMax)
          when 'right'  then phiGreater(entry.mid.b, tgt.bMax)
          when 'top'    then phiLess(entry.mid.a, tgt.aMin)
          when 'left'   then phiLess(entry.mid.b, tgt.bMin)
          else false
      if allPastCorner
        @advancePhase()
        continue
      # Score uses float toFloat() — sorting only, never legality.
      aMinF = tgt.aMin.toFloat()
      aMaxF = tgt.aMax.toFloat()
      bMinF = tgt.bMin.toFloat()
      bMaxF = tgt.bMax.toFloat()
      score = (m) ->
        af = m.a.toFloat()
        bf = m.b.toFloat()
        switch pPhase
          when 'bottom'
            -10 * Math.abs(bf - bMinF) + Math.min(af, aMaxF) - 10 * Math.max(0, af - aMaxF)
          when 'right'
            -10 * Math.abs(af - aMaxF) + Math.min(bf, bMaxF) - 10 * Math.max(0, bf - bMaxF)
          when 'top'
            -10 * Math.abs(bf - bMaxF) - Math.max(af, aMinF) - 10 * Math.max(0, aMinF - af)
          when 'left'
            -10 * Math.abs(af - aMinF) - Math.max(bf, bMinF) - 10 * Math.max(0, bMinF - bf)
          else 0
      pool.sort (x, y) -> score(y.mid) - score(x.mid)
      return pool[0].edge
    # interior: min-entropy among interior open edges.
    pool = @eligibleEdges()
    return null if pool.length == 0
    best = null
    bestN = Infinity
    for { edge } in pool
      legals = @legalPieces(edge)
      if legals.length < bestN
        bestN = legals.length
        best = edge
      break if bestN == 0
    best

  # Number of EXISTING open edges this placement would close. The seed
  # edge counts as one (always). Any of the two C-incident edges that
  # already exist as open edges count too. A placement closing all 3
  # creates ZERO new edges; closing 2 creates 1; closing 1 creates 2.
  edgeClosureCount: (p) ->
    n = 1
    n += 1 if p.closesBC?
    n += 1 if p.closesCA?
    n

  # ---- WFC loop ----
  # Three heuristics combined, lexicographically:
  #   (1) Edge tier — open edges whose MIDPOINT lies strictly inside the
  #       canvas are processed first. Only when no inside-midpoint edge has
  #       a viable placement do we consider outside-midpoint edges.
  #   (2) Inside-vertex filter — the new C must lie inside the relaxed
  #       canvas (one short-edge overhang allowed). Exact PhiBase test.
  #   (3) Edge-closure preference — among surviving placements at the
  #       chosen tier, prefer those closing more existing open edges.
  #       Closing 3 is best (no new edges), then 2, then 1.
  # Tie-break by min-entropy (fewest candidates = most constrained), then
  # random within the survivors.
  step: ->
    # Collect candidates separated into two priority tiers by edge midpoint.
    insideBest  = { edge: null, legals: null, closure: -1, n: Infinity }
    outsideBest = { edge: null, legals: null, closure: -1, n: Infinity }
    consider = (bucket, e, topLegals, maxClosure) ->
      better =
        maxClosure > bucket.closure or
        (maxClosure == bucket.closure and topLegals.length < bucket.n)
      if better
        bucket.edge    = e
        bucket.legals  = topLegals
        bucket.closure = maxClosure
        bucket.n       = topLegals.length
    for e from @openEdges
      legals = @legalPieces(e)
      insideLegals = (p for p in legals when @isVertexInCanvas(p.cPos))
      continue if insideLegals.length == 0
      maxClosure = 0
      for p in insideLegals
        c = @edgeClosureCount(p)
        maxClosure = c if c > maxClosure
      topLegals = (p for p in insideLegals when @edgeClosureCount(p) == maxClosure)
      bucket = if @isPointStrictlyInsideCanvas(e.midpoint()) then insideBest else outsideBest
      consider bucket, e, topLegals, maxClosure
    # Inside-midpoint edges first; outside is fallback.
    best = if insideBest.edge? then insideBest else outsideBest
    return 'done' unless best.edge?
    pick = best.legals[Math.floor(Math.random() * best.legals.length)]
    @placePlacement pick
    'progress'

  run: (maxSteps = 500) ->
    for _ in [0...maxSteps]
      result = @step()
      return result if result != 'progress'
    'maxSteps'

  stats: ->
    insideOpen = 0
    for e from @openEdges
      legals = @legalPieces(e)
      insideOpen += 1 if (p for p in legals when @isVertexInCanvas(p.cPos)).length > 0
    pieceCount: @pieces.length
    vertexCount: @vertices.length
    edgeCount: @edges.length
    openEdgeCount: @openEdges.size
    insideOpenCount: insideOpen
    closedVertexCount: (v for v in @vertices when v.status == 'closed').length

  # Diagnostic: for every open edge inside (or touching) the canvas, walk
  # the same kind × edgeIdx × side enumeration as legalPieces, accumulating
  # rejection reasons. Output the per-reason totals and a per-edge
  # breakdown limited to edges where everything was rejected (== bottleneck).
  diagnose: ->
    perReason = {}
    bumpReason = (r) -> perReason[r] = (perReason[r] ? 0) + 1
    deadEdges = []   # open edges with zero accepted placements
    for e from @openEdges
      tried = 0
      accepted = 0
      acceptedOutside = 0
      edgeReasons = {}
      for kind in pieceKinds()
        template = getTemplate(kind)
        for i in [0...3]
          templateLen = template.edgeLengths[i]
          templateKind = if templateLen[0] == 1 and templateLen[1] == 0 then 'short' else 'long'
          continue unless templateKind == e.kind
          for side in ['left', 'right']
            continue if side == 'left' and e.left?
            continue if side == 'right' and e.right?
            tried += 1
            rejections = []
            placement = @tryPlacement(e, kind, i, side, template, rejections)
            if placement?
              if @isVertexInCanvas(placement.cPos)
                accepted += 1
                bumpReason 'accepted'
                edgeReasons.accepted = (edgeReasons.accepted ? 0) + 1
              else
                acceptedOutside += 1
                bumpReason 'outsideCanvas'
                edgeReasons.outsideCanvas = (edgeReasons.outsideCanvas ? 0) + 1
            else
              r = rejections[0] ? 'unknown'
              bumpReason r
              edgeReasons[r] = (edgeReasons[r] ? 0) + 1
      if accepted == 0 and tried > 0
        m = e.midpoint().toCartesian()
        deadEdges.push
          mid: [Math.round(m[0]*100)/100, Math.round(m[1]*100)/100]
          kind: e.kind
          dir: e.dir
          tried: tried
          reasons: edgeReasons
    { perReason, deadEdges }
