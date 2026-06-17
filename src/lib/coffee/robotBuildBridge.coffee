# robotBuildBridge.coffee
#
# Bridges the SixPhi world (GeoPhi.goldenApexCandidates) to the Cartesian
# robotBuild state machine. The bridge owns a parallel `sixPhiByVertex` array:
# each vertex index in robotBuild has a SixPhiVector here, so when the next
# frontier step needs apex candidates we can call goldenApexCandidates with
# the right SixPhi inputs.
#
# Coordinates inside robotBuild are floats in the same units as the teapot
# mesh (bounding radius = 1). SixPhiVector cartesian conversion (via
# sixPhiToCartesianDisplay) returns floats in those same units — no extra
# rescaling needed.

import * as rb from './robotBuild.coffee'
import { shellEnclosing, PHI } from './phiShells.coffee'
import { SixPhiVector } from './sixPhiVector.coffee'
import { GeoPhi } from './geoPhi.coffee'

# Convert a SixPhiVector to a Cartesian float triple.
sixPhiToCart = (v) -> v.sixPhiToCartesianDisplay()

# String key for a Cartesian float triple, used to look the SixPhi back up
# after a new vertex lands in robotBuild.
cartKey = ([x, y, z]) -> "#{x.toFixed(6)},#{y.toFixed(6)},#{z.toFixed(6)}"

# Build a candidate provider and a scorer bound to a particular GeoPhi
# instance + radial-distance function.
#
# opts.bandLo / opts.bandHi: when set, candidates must land in the band
#   bandLo < (|apex| - r_teapot(direction)) < bandHi. Used for the n<0 hulls
#   where every vertex sits in a thin shell above the teapot surface.
export createBridge = (G, teapotRadialDistance, opts = {}) ->
  bandLo = opts.bandLo ? null
  bandHi = opts.bandHi ? null
  bandActive = bandLo? and bandHi?
  bandCenter = if bandActive then (bandLo + bandHi) / 2 else 0
  # sixPhiByVertex[i] = SixPhiVector for the i-th robotBuild vertex.
  sixPhiByVertex = []

  # Cache of (cartKey -> SixPhiVector) for candidates emitted on the most
  # recent provider call. Consulted after each step to record the SixPhi of
  # newly-placed vertices.
  pendingSixPhi = new Map()

  # Sample a chord (a,b) at 5 interior points; return true if any sample has
  # radius less than r_teapot in its own direction (edge cuts the teapot).
  edgeIntrudesTeapot = (a, b) ->
    for t in [0.1, 0.3, 0.5, 0.7, 0.9]
      mx = a[0]*(1-t) + b[0]*t
      my = a[1]*(1-t) + b[1]*t
      mz = a[2]*(1-t) + b[2]*t
      rM = Math.hypot(mx, my, mz)
      continue if rM < 1e-6
      dir = [mx/rM, my/rM, mz/rM]
      rT = teapotRadialDistance(dir)
      return true if rT? and rM < rT - 1e-3
    false

  # ---- candidateProvider ---------------------------------------------------
  candidateProvider = (edge, state) ->
    p1 = sixPhiByVertex[edge.a]
    p2 = sixPhiByVertex[edge.b]
    return [] unless p1? and p2?
    parentA = state.vertices[edge.a]
    parentB = state.vertices[edge.b]
    out = []
    pendingSixPhi.clear()
    for c in G.goldenApexCandidates(p1, p2)
      cart = [c.cart.x.toFloat(), c.cart.y.toFloat(), c.cart.z.toFloat()]
      # Band filter: apex's distance from teapot surface must lie strictly
      # inside (bandLo, bandHi). Used by the n<0 hull builds.
      if bandActive
        r = Math.hypot(cart[0], cart[1], cart[2])
        continue if r < 1e-9
        dir = [cart[0]/r, cart[1]/r, cart[2]/r]
        rT = teapotRadialDistance(dir) ? 1.0
        dist = r - rT
        continue unless dist > bandLo and dist < bandHi
      # Reject if either new edge (parentA-apex, parentB-apex) cuts through
      # the teapot interior.
      continue if edgeIntrudesTeapot(parentA, cart)
      continue if edgeIntrudesTeapot(parentB, cart)
      # Manifold guard: if the apex coincides with an already-placed vertex,
      # the new triangle reuses edges (apex-a) and (apex-b). Reject if either
      # of those edges is already saturated (count >= 2), otherwise frontier
      # closure would push it to 3 and we'd get triangle overlap.
      apexIdx = rb.findVertex(state.vertices, cart)
      if apexIdx >= 0
        ke1 = rb.edgeKey(apexIdx, edge.a)
        ke2 = rb.edgeKey(apexIdx, edge.b)
        continue if (state.edgeCount[ke1] ? 0) >= 2
        continue if (state.edgeCount[ke2] ? 0) >= 2
      pendingSixPhi.set(cartKey(cart), c.apex)
      out.push cart
    out

  # ---- scorer --------------------------------------------------------------
  # The candidate provider has already filtered out anything whose edges cut
  # the teapot. The scorer's job is to keep the hull on a consistent shell so
  # the build doesn't ping-pong between very different radii (which is what
  # creates long chords that *do* cut through despite the filter).
  #
  # Strategy: hard penalty for being below the local strict-enclosure shell
  # floor, then minimize |r_apex - r_parent_avg| so each step keeps roughly
  # the same radius as the edge it grew from.
  INWARD_PENALTY = 1e6
  scorer = (cart, edge, state) ->
    r = Math.hypot(cart[0], cart[1], cart[2])
    return Infinity if r < 1e-9
    dir = [cart[0]/r, cart[1]/r, cart[2]/r]
    rTeapot = teapotRadialDistance(dir) ? 1.0
    if bandActive
      dist = r - rTeapot
      # The provider already rejects out-of-band candidates, so here we just
      # prefer the centre of the band.
      return Math.abs(dist - bandCenter)
    floor = shellEnclosing(rTeapot).r
    if r < floor - 1e-3
      return INWARD_PENALTY + (floor - r)
    pa = state.vertices[edge.a]
    pb = state.vertices[edge.b]
    rPar = (Math.hypot(pa[0], pa[1], pa[2]) + Math.hypot(pb[0], pb[1], pb[2])) / 2
    Math.abs(r - rPar)

  # ---- seed ----------------------------------------------------------------
  # Take a SixPhi triangle (three SixPhiVector verts) as the seed. Initializes
  # robotBuild state AND sixPhiByVertex consistently.
  seed = (sixPhiTriangle) ->
    cart = sixPhiTriangle.map sixPhiToCart
    state = rb.createState(cart)
    sixPhiByVertex.length = 0
    for v in sixPhiTriangle
      sixPhiByVertex.push v
    state

  # Multi-seed: pre-place an arbitrary list of SixPhi triangles into a single
  # state. Vertices are deduped so a closed mesh (e.g. the 36 fans of the
  # dodecahedron) ends up with the right edge sharing — every shared edge
  # closes (count=2), the frontier is empty, and the robot has nothing left to
  # do. That's exactly the "static shell encloses the teapot" case.
  #
  # Manifold filter: when `opts.manifold` is true (the default), reject any
  # candidate triangle that would push one of its edges past edgeCount=2.
  # That's required for the n<0 band hulls, where `collectBandTriangles`
  # enumerates EVERY in-band golden tile and thus includes overlapping
  # triangulations (3+ tiles sharing one edge). Without the filter the
  # render is a triangle-soup; with it we keep at most 2 tiles per edge and
  # get a clean 2-manifold.
  seedMany = (sixPhiTriangles, opts = {}) ->
    manifold = opts.manifold ? true
    state = rb.createEmptyState()
    sixPhiByVertex.length = 0
    pendingByCart = new Map()      # cartKey -> SixPhiVector for any new vert this round
    for tri in sixPhiTriangles
      cart = tri.map sixPhiToCart
      if manifold
        # Predict the indices this triangle WOULD get (without mutating state).
        nextIdx = state.vertices.length
        nextNew = 0
        keyToPredicted = new Map()
        predicted = for v in cart
          existing = rb.findVertex(state.vertices, v)
          if existing >= 0
            existing
          else
            k = cartKey(v)
            if keyToPredicted.has(k)
              keyToPredicted.get(k)
            else
              idx = nextIdx + nextNew
              keyToPredicted.set(k, idx)
              nextNew += 1
              idx
        eK = [
          rb.edgeKey(predicted[0], predicted[1])
          rb.edgeKey(predicted[1], predicted[2])
          rb.edgeKey(predicted[2], predicted[0])
        ]
        skip = false
        for k in eK
          if (state.edgeCount[k] ? 0) >= 2
            skip = true
            break
        continue if skip
      { newVerts } = rb.addTriangleToState(state, cart)
      for { idx } in newVerts
        target = state.vertices[idx]
        match = null
        for v, i in tri
          c = sixPhiToCart(v)
          if Math.abs(c[0]-target[0]) < 1e-4 and Math.abs(c[1]-target[1]) < 1e-4 and Math.abs(c[2]-target[2]) < 1e-4
            match = v
            break
        sixPhiByVertex[idx] = match
    state

  # ---- step / run helpers --------------------------------------------------
  # Wrap frontierStep so that after each placement we record the new vertex's
  # SixPhi (looked up via cartKey from `pendingSixPhi`).
  stepOnce = (state) ->
    beforeN = state.vertices.length
    step = rb.frontierStep(state, candidateProvider, scorer)
    if step? and state.vertices.length > beforeN
      newCart = state.vertices[state.vertices.length - 1]
      sp = pendingSixPhi.get(cartKey(newCart))
      sixPhiByVertex.push sp ? null
    step

  runToCompletion = (state) ->
    state.status = 'running'
    loop
      step = stepOnce(state)
      break unless step?
    state.status = 'done' if state.status == 'running'
    state

  { seed, seedMany, stepOnce, runToCompletion, candidateProvider, scorer, sixPhiByVertex }

# Return a clean 36-triangle decomposition of a single regular dodecahedron
# at radius √3 ≈ φ¹. Strictly encloses the unit-bounding-sphere teapot.
#
# `createFiboTriangles` emits 14 triangles per pentagon face in a fixed
# (i, j) order: i in 0..6, j in 2..3. The within-face indices [0, 4, 9]
# correspond to triangles {(v0,v1,v2), (v2,v3,v4), (v0,v2,v4)}, which tile
# the pentagon — two boundary ears plus the central diagonal triangle.
# Face indices "0".."11" are the originals; "12".."23" are the mirror-0
# reflections (a second dodecahedron, dropped here for a cleaner look).
export pickDodecahedronSeeds = (G, opts = {}) ->
  targetRadius = opts.targetRadius ? Math.sqrt(3)
  eps = opts.eps ? 0.01
  pickedWithin = opts.pickedWithin ? [0, 4, 9]
  out = []
  for entry, idx in G.fiboTriangles
    rec = entry?.value ? entry
    continue unless rec?.path?
    # Original dodecahedron only.
    continue unless Number(rec.face) < 12
    # Clean triangulation: only the 3 within-face indices that tile.
    continue unless (idx % 14) in pickedWithin
    verts = (GeoPhi.createPhiPoint(name) for name in rec.path)
    continue if verts.some (v) -> !v?
    carts = verts.map sixPhiToCart
    rs = carts.map ([x,y,z]) -> Math.hypot(x,y,z)
    continue unless rs.every (r) -> Math.abs(r - targetRadius) < eps
    out.push verts
  out

# For the n<0 hulls, find a seed golden triangle whose three vertices all
# lie in the band (bandLo, bandHi) above the teapot surface.
#
# Strategy: start from the n=0 dodecahedron's edges, collect every
# goldenApexCandidate that lies in band, then iteratively grow the band-
# vertex set by querying goldenApexCandidates among in-band pairs at
# golden edge lengths (short s = 2/φ, long L = 2). Once we have a few dozen
# band vertices, scan for any three that form a golden triangle and return
# them.
PHI_CONST = (1 + Math.sqrt(5)) / 2
SHORT_LEN = 2 / PHI_CONST
LONG_LEN  = 2

export pickBandSeedTriangle = (G, teapotRadialDistance, bandLo, bandHi, maxIters = 4) ->
  # 1) Run a temporary n=0 build to harvest edges + their SixPhi vertices.
  seeds = pickDodecahedronSeeds(G)
  tmpBridge = createBridge(G, teapotRadialDistance)
  state = tmpBridge.seedMany(seeds)
  baseSixPhi = tmpBridge.sixPhiByVertex.slice()

  distFromSurface = (cart) ->
    r = Math.hypot(cart[0], cart[1], cart[2])
    return null if r < 1e-9
    dir = [cart[0]/r, cart[1]/r, cart[2]/r]
    rT = teapotRadialDistance(dir)
    return null unless rT?
    { r, dist: r - rT }

  inBand = (cart) ->
    dd = distFromSurface(cart)
    return false unless dd?
    dd.dist > bandLo and dd.dist < bandHi

  band = new Map()
  addBand = (cart, sixPhi) ->
    return if Math.hypot(cart[0], cart[1], cart[2]) < 1e-9
    return unless inBand(cart)
    k = cartKey(cart)
    return if band.has(k)
    band.set k, { cart, sixPhi }

  # 1a) seed candidates from n=0 edges
  edgesSeen = new Set()
  for tri in state.triangles
    for e in [0..2]
      a = tri[e]; b = tri[(e+1) % 3]
      k = if a < b then "#{a}-#{b}" else "#{b}-#{a}"
      continue if edgesSeen.has(k)
      edgesSeen.add k
      p1 = baseSixPhi[a]
      p2 = baseSixPhi[b]
      continue unless p1? and p2?
      for c in G.goldenApexCandidates(p1, p2)
        cart = [c.cart.x.toFloat(), c.cart.y.toFloat(), c.cart.z.toFloat()]
        addBand cart, c.apex

  # 1b) iterate: query goldenApexCandidates on pairs of band verts at golden lengths
  for iter in [0...maxIters]
    before = band.size
    cur = Array.from(band.values())
    for i in [0...cur.length]
      for j in [(i+1)...cur.length]
        a = cur[i]; b = cur[j]
        dx = a.cart[0]-b.cart[0]; dy = a.cart[1]-b.cart[1]; dz = a.cart[2]-b.cart[2]
        L = Math.hypot(dx, dy, dz)
        continue unless Math.abs(L - SHORT_LEN) < 0.01 or Math.abs(L - LONG_LEN) < 0.01
        for c in G.goldenApexCandidates(a.sixPhi, b.sixPhi)
          cart = [c.cart.x.toFloat(), c.cart.y.toFloat(), c.cart.z.toFloat()]
          addBand cart, c.apex
    break if band.size == before

  return null if band.size < 3

  # 2) Find any golden triangle with all 3 vertices in band.
  bandList = Array.from(band.values())
  for i in [0...bandList.length]
    for j in [(i+1)...bandList.length]
      a = bandList[i]; b = bandList[j]
      dx = a.cart[0]-b.cart[0]; dy = a.cart[1]-b.cart[1]; dz = a.cart[2]-b.cart[2]
      L = Math.hypot(dx, dy, dz)
      continue unless Math.abs(L - SHORT_LEN) < 0.01 or Math.abs(L - LONG_LEN) < 0.01
      for c in G.goldenApexCandidates(a.sixPhi, b.sixPhi)
        cart = [c.cart.x.toFloat(), c.cart.y.toFloat(), c.cart.z.toFloat()]
        k = cartKey(cart)
        continue unless band.has(k)
        return [a.sixPhi, b.sixPhi, band.get(k).sixPhi]
  null

# Multi-seed variant: enumerate EVERY golden triangle whose three vertices
# all lie in the band. Returns a list of [SixPhiVector, SixPhiVector,
# SixPhiVector] suitable for seedMany. This forms the supply for the n<0
# hull build — frontier growth then just stitches them together (most edges
# already shared) and the resulting state.triangles is the irregular hull
# covering the teapot.
# Robinson deflation (level 1) of the n=0 dodecahedron. For each pentagonal
# face we draw the 5 diagonals; their intersections produce the inner-pentagon
# corners (5 per face, all at r=1.434 — the n=-1 sub-shell). The face's area
# then divides into 11 sub-regions: 5 acute golden triangles (star points,
# apex at each outer vertex), 5 golden gnomons (along each outer edge, third
# corner at an inner pentagon vertex), and 1 inner pentagon (triangulated as
# 3 golden tiles using the same [0,4,9] pattern as the n=0 hull). 13 tiles
# per face × 12 faces = 156 total. Every tile is a golden Robinson tile;
# adjacent faces share their outer dodec edge cleanly (each contributes one
# gnomon on that edge → exactly 2 tiles per shared edge, manifold by
# construction).
computeDeflationLevel1 = (G) ->
  out = []
  for faceIdx in [0...12]
    names = G.Faces[faceIdx].split('-')
    V = (GeoPhi.createPhiPoint(n) for n in names)
    Vcart = (v.sixPhiToCartesianDisplay() for v in V)
    # Inner pentagon corners: I[i] sits on the diagonal V_i → V_{i+2} at
    # fraction 1/phi from V_i. All five end up coplanar with the face and at
    # radial distance ≈ 1.434 from the origin.
    I = []
    for i in [0...5]
      vi = Vcart[i]
      vi2 = Vcart[(i+2) % 5]
      I.push [
        vi[0] + (1/PHI_CONST) * (vi2[0] - vi[0])
        vi[1] + (1/PHI_CONST) * (vi2[1] - vi[1])
        vi[2] + (1/PHI_CONST) * (vi2[2] - vi[2])
      ]
    # Star points: for each outer vertex V_i, find its two nearest inner
    # pentagon corners — that's the base of the acute golden triangle.
    dist = (a, b) -> Math.hypot(a[0]-b[0], a[1]-b[1], a[2]-b[2])
    twoClosest = (v) ->
      ds = ({j: j, d: dist(v, I[j])} for j in [0...5])
      ds.sort (a, b) -> a.d - b.d
      [ds[0].j, ds[1].j]
    for i in [0...5]
      [j1, j2] = twoClosest(Vcart[i])
      out.push [Vcart[i], I[j1], I[j2]]
    # Gnomons: one per outer pentagon edge. Third corner = the inner corner
    # closest to both V_i and V_{i+1}.
    closestToBoth = (a, b) ->
      best = 0
      bestS = Infinity
      for j in [0...5]
        s = dist(a, I[j]) + dist(b, I[j])
        if s < bestS
          bestS = s
          best = j
      best
    for i in [0...5]
      v0 = Vcart[i]
      v1 = Vcart[(i+1) % 5]
      j = closestToBoth(v0, v1)
      out.push [v0, v1, I[j]]
    # Inner pentagon triangulation, same [0,4,9] pattern as n=0.
    out.push [I[0], I[1], I[2]]
    out.push [I[2], I[3], I[4]]
    out.push [I[0], I[2], I[4]]
  out

export buildDeflationLevel1 = (G) ->
  cartTris = computeDeflationLevel1(G)
  state = rb.createEmptyState()
  for tri in cartTris
    rb.addTriangleToState(state, tri)
  state

# Voxel hull made of "Hut" (Roof) cells.
#
# Tile 3D space with axis-aligned cubes. Each cube face carries a hut:
# 4 base corners (= cube vertices), 2 ridge vertices above the face at
# perpendicular distance (cubeHalfEdge / phi), ridge runs along a specific
# axis depending on which face (top/bottom: x, left/right: y, front/back: z).
# Six huts on one cube, bumps outward = regular dodecahedron; bumps inward
# = cube. All edges are either L=cubeEdge or s=L/phi, all faces are golden
# triangles (4 short slants + 1 short ridge + 4 long base = 9 edges total
# per hut, 6 outward-visible triangles: 2 trapezoid sides + 2 triangle ends,
# trapezoids split as 2 tris each).
#
# Voxelization: cube cell is filled iff its center sits inside the teapot.
# Boundary face (filled neighboring empty) gets a hut rendered from the
# filled side, sticking out into the empty side. The 4 base corners stay
# interior to the cube and are not drawn.
export buildVoxelHull = (G, teapotRadialDistance, opts = {}) ->
  s = opts.scale ? 0.3         # cube half-edge length
  range = opts.range ? 5

  isInside = (pos) ->
    r = Math.hypot(pos[0], pos[1], pos[2])
    return true if r < 1e-9
    rT = teapotRadialDistance([pos[0]/r, pos[1]/r, pos[2]/r])
    return false unless rT?
    r < rT

  cubeCenter = (i, j, k) -> [i * 2 * s, j * 2 * s, k * 2 * s]

  occ = {}
  keyFn = (i, j, k) -> "#{i},#{j},#{k}"
  for i in [-range..range]
    for j in [-range..range]
      for k in [-range..range]
        occ[keyFn(i, j, k)] = isInside(cubeCenter(i, j, k))
  isOcc = (i, j, k) -> occ[keyFn(i, j, k)] ? false

  state = rb.createEmptyState()

  # Render a hut for one face of a cube. `axis` is the face-normal axis
  # (0=x, 1=y, 2=z). `dir` is ±1 (which side of the cube). Ridge runs along
  # axis (axis+1) mod 3 by the cube↔dodec construction. Triangles are wound
  # so their outward normals point away from the cube center.
  renderHut = (cx, cy, cz, axis, dir) ->
    ridgeAxis = (axis + 1) % 3
    sideAxis  = (axis + 2) % 3
    unit = (a) -> v = [0, 0, 0]; v[a] = 1; v
    aU = unit(axis)
    rU = unit(ridgeAxis)
    tU = unit(sideAxis)
    add3 = (a, b, c) -> [a[0]+b[0]+c[0], a[1]+b[1]+c[1], a[2]+b[2]+c[2]]
    sca = (v, k) -> [v[0]*k, v[1]*k, v[2]*k]
    baseCenter = add3([cx, cy, cz], sca(aU, dir * s), [0, 0, 0])
    # 4 base corners (cube face corners)
    bMM = add3(baseCenter, sca(rU, -s), sca(tU, -s))
    bPM = add3(baseCenter, sca(rU, +s), sca(tU, -s))
    bPP = add3(baseCenter, sca(rU, +s), sca(tU, +s))
    bMP = add3(baseCenter, sca(rU, -s), sca(tU, +s))
    # 2 ridge vertices, above baseCenter by s/phi along axis (outward),
    # offset by ±s/phi along ridgeAxis.
    ridgeCenter = add3(baseCenter, sca(aU, dir * s / PHI_CONST), [0, 0, 0])
    rA = add3(ridgeCenter, sca(rU, -s / PHI_CONST), [0, 0, 0])
    rB = add3(ridgeCenter, sca(rU, +s / PHI_CONST), [0, 0, 0])
    # 6 outward-facing triangles. Winding chosen so the normal computed by
    # (b - a) × (c - a) points outward from the cube center. The page's
    # orientOutward (based on direction from origin) is wrong for cells off
    # the origin, so we set the winding here and ask the page to skip its
    # re-orientation for the voxel hull.
    if dir > 0
      rb.addTriangleToState(state, [bMM, bPM, rB])
      rb.addTriangleToState(state, [bMM, rB, rA])
      rb.addTriangleToState(state, [bPM, bPP, rB])
      rb.addTriangleToState(state, [bMP, rA, rB])
      rb.addTriangleToState(state, [bMP, rB, bPP])
      rb.addTriangleToState(state, [bMM, rA, bMP])
    else
      rb.addTriangleToState(state, [bMM, rB, bPM])
      rb.addTriangleToState(state, [bMM, rA, rB])
      rb.addTriangleToState(state, [bPM, rB, bPP])
      rb.addTriangleToState(state, [bMP, rB, rA])
      rb.addTriangleToState(state, [bMP, bPP, rB])
      rb.addTriangleToState(state, [bMM, bMP, rA])

  for i in [-range..range]
    for j in [-range..range]
      for k in [-range..range]
        continue unless isOcc(i, j, k)
        [cx, cy, cz] = cubeCenter(i, j, k)
        renderHut(cx, cy, cz, 0, +1) unless isOcc(i+1, j, k)
        renderHut(cx, cy, cz, 0, -1) unless isOcc(i-1, j, k)
        renderHut(cx, cy, cz, 1, +1) unless isOcc(i, j+1, k)
        renderHut(cx, cy, cz, 1, -1) unless isOcc(i, j-1, k)
        renderHut(cx, cy, cz, 2, +1) unless isOcc(i, j, k+1)
        renderHut(cx, cy, cz, 2, -1) unless isOcc(i, j, k-1)
  state

export collectBandTriangles = (G, teapotRadialDistance, bandLo, bandHi, maxIters = 10) ->
  seeds = pickDodecahedronSeeds(G)
  tmpBridge = createBridge(G, teapotRadialDistance)
  state = tmpBridge.seedMany(seeds)
  baseSixPhi = tmpBridge.sixPhiByVertex.slice()

  inBand = (cart) ->
    r = Math.hypot(cart[0], cart[1], cart[2])
    return false if r < 1e-9
    dir = [cart[0]/r, cart[1]/r, cart[2]/r]
    rT = teapotRadialDistance(dir)
    return false unless rT?
    dist = r - rT
    dist > bandLo and dist < bandHi

  band = new Map()
  addBand = (cart, sixPhi) ->
    return unless inBand(cart)
    k = cartKey(cart)
    return if band.has(k)
    band.set k, { cart, sixPhi }

  # Seed from n=0 edges
  edgesSeen = new Set()
  for tri in state.triangles
    for e in [0..2]
      a = tri[e]; b = tri[(e+1) % 3]
      k = if a < b then "#{a}-#{b}" else "#{b}-#{a}"
      continue if edgesSeen.has(k)
      edgesSeen.add k
      p1 = baseSixPhi[a]
      p2 = baseSixPhi[b]
      continue unless p1? and p2?
      for c in G.goldenApexCandidates(p1, p2)
        cart = [c.cart.x.toFloat(), c.cart.y.toFloat(), c.cart.z.toFloat()]
        addBand cart, c.apex

  # Iteratively grow by querying between band-vertex pairs
  for iter in [0...maxIters]
    before = band.size
    cur = Array.from(band.values())
    for i in [0...cur.length]
      for j in [(i+1)...cur.length]
        a = cur[i]; b = cur[j]
        dx = a.cart[0]-b.cart[0]; dy = a.cart[1]-b.cart[1]; dz = a.cart[2]-b.cart[2]
        L = Math.hypot(dx, dy, dz)
        continue unless Math.abs(L - SHORT_LEN) < 0.01 or Math.abs(L - LONG_LEN) < 0.01
        for c in G.goldenApexCandidates(a.sixPhi, b.sixPhi)
          cart = [c.cart.x.toFloat(), c.cart.y.toFloat(), c.cart.z.toFloat()]
          addBand cart, c.apex
    break if band.size == before

  # Enumerate all golden triangles among band vertices, then filter to those
  # whose 3 vertices sit on a single radial shell (within `shellEps`). This
  # rejects wedge triangles that span the band depth and end up geometrically
  # intersecting each other in render. The remaining tiles look like clean
  # shingles on a shell — at the cost of leaving some holes where no single-
  # shell tile exists.
  shellEps = 0.05
  bandList = Array.from(band.values())
  bandKeys = new Set(band.keys())
  triCart = new Map()
  for i in [0...bandList.length]
    for j in [(i+1)...bandList.length]
      a = bandList[i]; b = bandList[j]
      dx = a.cart[0]-b.cart[0]; dy = a.cart[1]-b.cart[1]; dz = a.cart[2]-b.cart[2]
      L = Math.hypot(dx, dy, dz)
      continue unless Math.abs(L - SHORT_LEN) < 0.01 or Math.abs(L - LONG_LEN) < 0.01
      for c in G.goldenApexCandidates(a.sixPhi, b.sixPhi)
        cart = [c.cart.x.toFloat(), c.cart.y.toFloat(), c.cart.z.toFloat()]
        k = cartKey(cart)
        continue unless bandKeys.has(k)
        # Single-shell guard: all three vertex radii within shellEps of each
        # other. Without this, cross-shell triangles produce the geometric-
        # intersection mess that backface culling can't hide.
        rA = Math.hypot(a.cart[0], a.cart[1], a.cart[2])
        rB = Math.hypot(b.cart[0], b.cart[1], b.cart[2])
        rC = Math.hypot(cart[0], cart[1], cart[2])
        rMin = Math.min(rA, rB, rC); rMax = Math.max(rA, rB, rC)
        continue if rMax - rMin > shellEps
        ka = cartKey(a.cart); kb = cartKey(b.cart); kc = k
        tKey = [ka, kb, kc].sort().join('|')
        continue if triCart.has(tKey)
        cx = (a.cart[0] + b.cart[0] + cart[0]) / 3
        cy = (a.cart[1] + b.cart[1] + cart[1]) / 3
        cz = (a.cart[2] + b.cart[2] + cart[2]) / 3
        centroidR = Math.hypot(cx, cy, cz)
        triCart.set tKey,
          tri: [a.sixPhi, b.sixPhi, band.get(k).sixPhi]
          centroidR: centroidR
  sorted = Array.from(triCart.values()).sort((x, y) -> y.centroidR - x.centroidR)
  (s.tri for s in sorted)

# Pick a fiboTriangle near the origin for use as a seed. Returns
# [SixPhiVector, SixPhiVector, SixPhiVector] or null if none qualify.
# G.fiboTriangles entries are Memo wrappers ({value, notifier, resolver}) after
# createFiboTriangles flat()s the saveThis() returns.
export pickSeedTriangle = (G, maxAvgRadius = 2.5) ->
  best = null
  bestAvg = Infinity
  for entry in G.fiboTriangles
    rec = entry?.value ? entry
    continue unless rec?.path?
    verts = (GeoPhi.createPhiPoint(name) for name in rec.path)
    continue if verts.some (v) -> !v?
    carts = verts.map sixPhiToCart
    rs = carts.map ([x,y,z]) -> Math.hypot(x,y,z)
    avg = (rs[0] + rs[1] + rs[2]) / 3
    continue if avg > maxAvgRadius
    if avg < bestAvg
      bestAvg = avg
      best = verts
  best

