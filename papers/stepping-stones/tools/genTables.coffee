#!/usr/bin/env coffee
###
genTables.coffee — build the 60-element icosahedral rotation group I as
signed permutations of the six face-axes A..F, classify each element, and
emit tcl/tables.tcl for the TCL turtle.

Every element is stored as its "basis action" {perm, signs}:
  R(b_i) = signs[i] * b_{ perm[i] }
Group closure by BFS from two generators (R_A^1 and R_ACE^1) whose basis
actions are hand-derived below. The coordinate action used by TCL (slot
mapping applied to a position/heading SixPhi) is obtained by inversion;
see toCoord() at the bottom.

Verification stamps written to tables.tcl header:
  |G| = 60
  1 identity + 24 face + 20 vertex + 15 flip
  R_A^5 = R_ACE^3 = flip^2 = id (order tests)
###

fs   = require 'fs'
path = require 'path'

LETTERS = ['A','B','C','D','E','F']
LEGAL_TRIPLES = [
  'ABC','ABD','ACE','ADF','AEF',
  'BCF','BDE','BEF','CDE','CDF'
]

# ---- Generators ------------------------------------------------------------
#
# R_A^1 = 72-degree rotation about +b_A, right-hand.  The five neighbors of
# face A+ (i.e., the face normals b_j with b_j.b_A = +phi) are B+, C+, D-,
# E+, F+, and their CCW cyclic order around +A is
#   B+  ->  -D+  ->  F+  ->  E+  ->  C+  ->  B+ .
# So R_A^1 acts on basis vectors as:
#   b_A -> +b_A
#   b_B -> -b_D
#   b_C -> +b_B
#   b_D -> -b_F
#   b_E -> +b_C
#   b_F -> +b_E
gA = {perm: [0, 3, 1, 5, 2, 4], signs: [1, -1, 1, -1, 1, 1]}

# R_ACE = 120-degree rotation about +(b_A + b_C + b_E), which is the
# right-hand cyclic Cartesian rotation (x,y,z) -> (y,z,x).  Under this,
#   b_A=(phi,1,0) -> (1,0,phi) = b_C
#   b_B=(phi,-1,0) -> (-1,0,phi) = b_D
#   b_C -> (0,phi,1) = b_E
#   b_D -> (0,phi,-1) = b_F
#   b_E -> (phi,1,0) = b_A
#   b_F -> (phi,-1,0) = b_B
gACE = {perm: [2, 3, 4, 5, 0, 1], signs: [1, 1, 1, 1, 1, 1]}

identity = {perm: [0,1,2,3,4,5], signs: [1,1,1,1,1,1]}

# ---- Group ops -------------------------------------------------------------
compose = (g, h) ->
  # (g o h)(b_i) = g(h(b_i)) = h.signs[i] * g.signs[h.perm[i]] * b_{ g.perm[h.perm[i]] }
  perm  = new Array(6)
  signs = new Array(6)
  for i in [0...6]
    j = h.perm[i]
    perm[i]  = g.perm[j]
    signs[i] = h.signs[i] * g.signs[j]
  {perm, signs}

inverse = (g) ->
  perm  = new Array(6)
  signs = new Array(6)
  for i in [0...6]
    perm[g.perm[i]]  = i
    signs[g.perm[i]] = g.signs[i]
  {perm, signs}

key = (g) -> g.perm.join(',') + '|' + g.signs.join(',')

# ---- BFS closure -----------------------------------------------------------
seen = {}
seen[key(identity)] = identity
frontier = [identity]
gens = [gA, gACE]
while frontier.length
  next = []
  for g in frontier
    for h in gens
      p = compose(g, h)
      k = key(p)
      unless seen[k]?
        seen[k] = p
        next.push p
  frontier = next

elements = (v for _, v of seen)
console.log "|G| = #{elements.length}"
throw new Error "expected 60, got #{elements.length}" unless elements.length is 60

# ---- Classification --------------------------------------------------------
cycles = (g) ->
  visited = (false for _ in [0...6])
  out = []
  for start in [0...6]
    continue if visited[start]
    cyc = [start]
    visited[start] = true
    j = g.perm[start]
    while j isnt start
      cyc.push j
      visited[j] = true
      j = g.perm[j]
    out.push cyc
  out

classify = (g) ->
  cs   = cycles(g)
  lens = (c.length for c in cs).sort().join(',')
  fixed = (c[0] for c in cs when c.length is 1)
  switch lens
    when '1,1,1,1,1,1'
      if g.signs.every((s) -> s is 1)
        return {type: 'identity'}
      throw new Error "1,1,1,1,1,1 with non-trivial signs: #{key g}"
    when '1,5'
      idx = fixed[0]
      throw new Error "5-fold with negative sign on fixed axis" if g.signs[idx] isnt 1
      return {type: 'face', axis: LETTERS[idx], axisIdx: idx}
    when '3,3'
      t1 = (LETTERS[i] for i in cs[0]).sort().join('')
      t2 = (LETTERS[i] for i in cs[1]).sort().join('')
      for t in LEGAL_TRIPLES
        return {type: 'vertex', triple: t} if t is t1 or t is t2
      throw new Error "no legal triple among {#{t1},#{t2}}"
    when '1,1,2,2'
      pair = (LETTERS[i] for i in fixed).sort().join('')
      return {type: 'flip', pair}
    else
      throw new Error "unclassified cycles #{lens} for #{key g}"

# ---- Bucket by type --------------------------------------------------------
faceElems   = (g for g in elements when classify(g).type is 'face')
vertexElems = (g for g in elements when classify(g).type is 'vertex')
flipElems   = (g for g in elements when classify(g).type is 'flip')
console.log "face=#{faceElems.length} vertex=#{vertexElems.length} flip=#{flipElems.length}"

# ---- Choose a "k=+1" base for each face axis --------------------------------
# For X=A the base is gA by decree.  For X in B..F pick any element g in the
# group with g.perm[0] = X's index (i.e., g sends b_A to +/- b_X).  Then
#   base_X = g . gA . g^{-1}
# rotates about g(b_A) = +/- b_X.  If the sign is negative we invert to get
# a rotation about +b_X (still an arbitrary "k=+1" convention across axes,
# but locally consistent per axis so powers work).
faceBase = {A: gA}
for X in ['B','C','D','E','F']
  target = LETTERS.indexOf(X)
  for g in elements when g.perm[0] is target
    b = compose(compose(g, gA), inverse(g))
    b = inverse(b) if g.signs[0] is -1
    faceBase[X] = b
    break

# ---- Choose a "k=+1" base for each legal triple ----------------------------
# base_T rotates such that its 3-cycle on the {A,C,E}-slots-of-original ACE
# lines up with the target triple T.  Then k=-1 is its inverse.
trBase = {}
for T in LEGAL_TRIPLES
  targetIdx = (LETTERS.indexOf(c) for c in T).sort().join(',')
  for g in elements
    mapped = [g.perm[0], g.perm[2], g.perm[4]].sort().join(',')
    if mapped is targetIdx
      b = compose(compose(g, gACE), inverse(g))
      # b is a 3-fold whose classified triple is T (by construction of the
      # cycle image under g); no k adjustment needed.
      trBase[T] = b
      break

# ---- Flips: one representative per pair name -------------------------------
flipRep = {}
for g in flipElems
  c = classify(g)
  flipRep[c.pair] ?= g

# ---- Sanity: orders --------------------------------------------------------
checkOrder = (g, n, label) ->
  p = identity
  p = compose(g, p) for _ in [0...n]
  throw new Error "#{label} order #{n} check failed" unless key(p) is key(identity)

checkOrder gA,  5, "R_A"
checkOrder gACE, 3, "R_ACE"
checkOrder faceBase[X], 5, "R_#{X}" for X in LETTERS
checkOrder trBase[T],   3, "R_#{T}" for T in LEGAL_TRIPLES
checkOrder flipRep[p],  2, "flip #{p}" for p of flipRep

# ---- Sanity: closure (every product stays in the group) ---------------------
allKeys = {}
allKeys[key(g)] = true for g in elements
for g in elements
  for h in elements
    unless allKeys[key(compose(g, h))]
      throw new Error "closure violated: g . h not in group"
console.log "closure verified: all 3600 products land in the group"

# ---- §6.7 chirality assertion for dodecahedron1 ----------------------------
# Exact Z[phi] arithmetic inline (denominators unused for this test).
pb  = (p, n) -> {p, n}
pbAdd   = (a, b) -> pb(a.p + b.p, a.n + b.n)
pbScale = (a, k) -> pb(a.p * k, a.n * k)
pbMul   = (a, b) -> pb(a.p*b.n + a.n*b.p + a.p*b.p, a.n*b.n + a.p*b.p)
pbEq    = (a, b) -> a.p is b.p and a.n is b.n

BASIS_PB = [
  [pb(1,0),  pb(0,1),  pb(0,0)]   # A
  [pb(1,0),  pb(0,-1), pb(0,0)]   # B
  [pb(0,1),  pb(0,0),  pb(1,0)]   # C
  [pb(0,-1), pb(0,0),  pb(1,0)]   # D
  [pb(0,0),  pb(1,0),  pb(0,1)]   # E
  [pb(0,0),  pb(1,0),  pb(0,-1)]  # F
]

buildDodec = (patterns) ->
  verts = []
  # 8 cube corners
  for x in [-1, 1] then for y in [-1, 1] then for z in [-1, 1]
    verts.push [pb(0, x), pb(0, y), pb(0, z)]
  # 12 cyclic
  for pat in patterns
    for s1 in [-1, 1] then for s2 in [-1, 1]
      v = pat.slice()
      idx = 0
      for i in [0..2]
        continue if v[i].p is 0 and v[i].n is 0
        v[i] = pbScale(v[i], (if idx is 0 then s1 else s2))
        idx++
      verts.push v
  verts

INV  = pb(1, -1)   # 1/phi = phi - 1
PHI  = pb(1,  0)   # phi
ZERO = pb(0,  0)

PHI2  = pb( 1,  1)   # phi^2
NPHI2 = pb(-1, -1)
NINV  = pb(-1,  1)

dot3 = (v, b) ->
  pbAdd(pbAdd(pbMul(v[0], b[0]), pbMul(v[1], b[1])), pbMul(v[2], b[2]))

chiralityCheck = (verts) ->
  allowed = [PHI2, NPHI2, INV, NINV]
  for v, vi in verts
    phi2 = 0
    for b in BASIS_PB
      d = dot3(v, b)
      unless allowed.some((x) -> pbEq(x, d))
        return "FAIL: vertex #{vi} dot yields P(#{d.p},#{d.n})"
      phi2++ if pbEq(d, PHI2) or pbEq(d, NPHI2)
    return "FAIL: vertex #{vi} has #{phi2} phi^2 slots" unless phi2 is 3
  "PASS"

verts1 = buildDodec [
  [ZERO, INV, PHI], [PHI, ZERO, INV], [INV, PHI, ZERO]
]
result1 = chiralityCheck verts1
console.log "dodecahedron1 chirality: #{result1}"
throw new Error "dodecahedron1 failed chirality" unless result1 is 'PASS'

# dodecahedron2 = swap 1/phi and phi in the cyclic patterns. Under the same
# six basis normals this should FAIL, confirming the assertion actually
# discriminates chirality rather than passing everything.
verts2 = buildDodec [
  [ZERO, PHI, INV], [INV, ZERO, PHI], [PHI, INV, ZERO]
]
result2 = chiralityCheck verts2
console.log "dodecahedron2 chirality: #{result2}"
throw new Error "dodecahedron2 should have failed chirality" if result2 is 'PASS'
chiralityStamp = "PASS on dodecahedron1, FAIL on dodecahedron2 (correctly discriminated)"

# ---- Basis action -> coordinate action --------------------------------------
# Under g, position vector v becomes g(v).  Its i-th slot is g(v).b_i.  This
# equals v . g^{-1}(b_i) = signs[g.perm's preimage of i] * v . b_{preimage}.
# So coord_perm[k] = j where g.perm[j] = k, and coord_signs[k] = g.signs[j].
toCoord = (g) ->
  perm  = new Array(6)
  signs = new Array(6)
  for i in [0...6]
    perm[g.perm[i]]  = i
    signs[g.perm[i]] = g.signs[i]
  {perm, signs}

# ---- Emit tables.tcl -------------------------------------------------------
lines = []
lines.push "# tables.tcl — GENERATED by tools/genTables.coffee. Do not edit."
lines.push "# |G| = 60  (1 identity + 24 face + 20 vertex + 15 flip)"
lines.push "# Group closure verified: all 60x60 = 3600 products stay in the group."
lines.push "# Element orders verified: R_X^5 = R_TRIP^3 = flip^2 = identity."
lines.push "# Chirality (§6.7): #{chiralityStamp}"
lines.push "# Each entry has FOUR fields: {coord_perm coord_signs basis_perm basis_signs}."
lines.push "# Coordinate action (applied to heading/position SixPhi vectors):"
lines.push "#   v'[k] = coord_signs[k] * v[coord_perm[k]]"
lines.push "# Basis action (applied to floor as a signed axis index (i, s)):"
lines.push "#   (i, s) -> (basis_perm[i], s * basis_signs[i])"
lines.push ""
lines.push "namespace eval ::tab {}"
lines.push "array set ::tab::rot {}"
lines.push ""

emit = (name, elem) ->
  c = toCoord(elem)  # coord action for vectors
  # NOTE: use `elem` (not `b` or `g`) to avoid CoffeeScript's function-scope
  # var-hoisting from clobbering the outer loop's `b`. Learned the hard way.
  lines.push "set ::tab::rot(#{name}) [list [list #{c.perm.join(' ')}] [list #{c.signs.join(' ')}] [list #{elem.perm.join(' ')}] [list #{elem.signs.join(' ')}]]"

emit "id", identity

# Face rotations: X1, X2, X-1, X-2 for X in A..F
lines.push ""
lines.push "# --- 24 face-axis 5-fold rotations ---"
for X in LETTERS
  b = faceBase[X]
  emit "#{X}1",  b
  emit "#{X}2",  compose(b, b)
  emit "#{X}-1", inverse(b)
  emit "#{X}-2", inverse(compose(b, b))

# Vertex rotations: T1, T-1 for T in legal triples
lines.push ""
lines.push "# --- 20 vertex-axis 3-fold rotations ---"
for T in LEGAL_TRIPLES
  b = trBase[T]
  emit "#{T}1",  b
  emit "#{T}-1", inverse(b)

# Flips (order 2, no k)
lines.push ""
lines.push "# --- 15 edge-axis 2-fold flips ---"
pairKeys = Object.keys(flipRep).sort()
emit p, flipRep[p] for p in pairKeys

out = path.join __dirname, '..', 'tcl', 'tables.tcl'
fs.writeFileSync out, lines.join('\n') + '\n'
console.log "wrote #{out} (#{Object.keys(flipRep).length} flips, #{LEGAL_TRIPLES.length} triples)"
