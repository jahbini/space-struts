#!/usr/bin/env coffee
###
phiTurtle3D.coffee — scaffolding for the two 3D PhiBase turtles.

  coffee phiTurtle3D.coffee verify             # build + verify the named group table,
                                               # write icosaGroup.json
  coffee phiTurtle3D.coffee edge  walk.txt     # strut turtle  (3D lattice, group I turns)
  coffee phiTurtle3D.coffee face  walk.txt     # face walker   (2D charts on the dodec + fold)

NAMING CONVENTION (the whole point):
  The six 5-fold axes ARE the six SixPhi basis letters A..F.
  Every rotation axis of the icosahedral group I (order 60) is named by a
  subset of those letters:
     singleton  A            6  face axes   (5-fold)  ->  "A k"    k in {1,2,-1,-2}, units of 72 deg
     pair       EF          15  edge axes   (2-fold)  ->  "EF"     180 deg flip
     triple     ACE         10  vertex axes (3-fold)  ->  "ACE k"  k in {1,-1}, units of 120 deg
  Only 10 of the C(6,3)=20 triples are realized as vertices; `verify`
  prints the legal list.  Everything is exact Z[phi]; matrices are stored
  DOUBLED (2R has Z[phi] entries; halving asserts evenness).  Floats appear
  only at SVG render time.
###

fs   = require 'fs'
path = require 'path'

# ------------------------------- PhiBase ------------------------------------

class PhiBase
  constructor: (@n, @p) ->
  add:  (o) -> new PhiBase @n + o.n, @p + o.p
  sub:  (o) -> new PhiBase @n - o.n, @p - o.p
  mul:  (o) -> new PhiBase @n * o.n + @p * o.p, @n * o.p + @p * o.n + @p * o.p
  neg:      -> new PhiBase -@n, -@p
  half:     ->
    throw new Error "PhiBase #{@} is not halvable" if (@n & 1) or (@p & 1)
    new PhiBase @n / 2, @p / 2
  equals: (o) -> @n is o.n and @p is o.p
  isZero:     -> @n is 0 and @p is 0
  toFloat:    -> @n + @p * PHI_FLOAT
  toString:   -> "P(#{@n},#{@p})"

P         = (n, p) -> new PhiBase n, p
ZERO      = P 0, 0
ONE       = P 1, 0
TWO       = P 2, 0
PHI       = P 0, 1
INV_PHI   = P -1, 1        # 1/phi = phi - 1
PHI_SQ    = P 1, 1         # phi^2 = phi + 1
PHI_FLOAT = (1 + Math.sqrt 5) / 2

# ------------------------------- Vec3 over PhiBase --------------------------

v3     = (a, b, c) -> [a, b, c]
v3add  = (u, v) -> [u[0].add(v[0]), u[1].add(v[1]), u[2].add(v[2])]
v3sub  = (u, v) -> [u[0].sub(v[0]), u[1].sub(v[1]), u[2].sub(v[2])]
v3neg  = (u)    -> [u[0].neg(), u[1].neg(), u[2].neg()]
v3scale= (c, u) -> [c.mul(u[0]), c.mul(u[1]), c.mul(u[2])]
v3half = (u)    -> [u[0].half(), u[1].half(), u[2].half()]
v3dot  = (u, v) -> u[0].mul(v[0]).add(u[1].mul(v[1])).add(u[2].mul(v[2]))
v3cross= (u, v) -> [
  u[1].mul(v[2]).sub(u[2].mul(v[1]))
  u[2].mul(v[0]).sub(u[0].mul(v[2]))
  u[0].mul(v[1]).sub(u[1].mul(v[0]))
]
v3eq   = (u, v) -> u[0].equals(v[0]) and u[1].equals(v[1]) and u[2].equals(v[2])
v3str  = (u)    -> "(#{u[0]}, #{u[1]}, #{u[2]})"
v3float= (u)    -> [u[0].toFloat(), u[1].toFloat(), u[2].toFloat()]

# ------------------------------- 3x3 doubled matrices -----------------------
# A group element R is stored as M2 = 2R, entries in Z[phi].

m3add  = (A, B) -> ((A[i][j].add B[i][j] for j in [0..2]) for i in [0..2])
m3scale= (c, A) -> ((c.mul A[i][j] for j in [0..2]) for i in [0..2])
m3diag = (c)    -> ((if i is j then c else ZERO) for j in [0..2] for i in [0..2])
m3T    = (A)    -> ((A[j][i] for j in [0..2]) for i in [0..2])
m3eq   = (A, B) -> A.every (row, i) -> row.every (x, j) -> x.equals B[i][j]

crossMat = (d) -> [
  [ZERO,        d[2].neg(),  d[1]      ]
  [d[2],        ZERO,        d[0].neg()]
  [d[1].neg(),  d[0],        ZERO      ]
]

outerMat = (d) -> ((d[i].mul d[j] for j in [0..2]) for i in [0..2])

# (2A)(2B) = 4AB, halve once -> 2AB
m3mulHalf = (A2, B2) ->
  for i in [0..2]
    for j in [0..2]
      s = ZERO
      s = s.add A2[i][k].mul(B2[k][j]) for k in [0..2]
      s.half()

# (2R) v, halved -> R v.  Throws if R v leaves Z[phi]^3 (it never should
# for lattice vectors; the assert is the drift alarm).
m3applyHalf = (M2, u) ->
  v3half (for i in [0..2]
    s = ZERO
    s = s.add M2[i][k].mul(u[k]) for k in [0..2]
    s)

# ------------------------------- The six bases ------------------------------

LETTERS  = 'ABCDEF'
sixBases = [
  v3 PHI,       ZERO,      ONE         # A  (phi, 0,  1)
  v3 PHI,       ZERO,      ONE.neg()   # B  (phi, 0, -1)
  v3 ZERO,      ONE,       PHI         # C  (0,   1,  phi)
  v3 ZERO,      ONE.neg(), PHI         # D  (0,  -1,  phi)
  v3 ONE,       PHI,       ZERO        # E  (1,   phi, 0)
  v3 ONE.neg(), PHI,       ZERO        # F  (-1,  phi, 0)
]

# ------------------------------- Dodecahedron -------------------------------
# Two mirror-image vertex families are possible; keep the one whose SixPhi
# alphabet is exactly {+-phi^2, +-1/phi} with three phi^2-magnitude slots
# per vertex (face incidence).  The choice is made by test, not by decree.

cubeCorners = ->
  out = []
  for sx in [1, -1] then for sy in [1, -1] then for sz in [1, -1]
    out.push v3 P(sx,0), P(sy,0), P(sz,0)
  out

cyclicFamily = (a, b) ->    # (0, +-a, +-b) and its two cyclic shifts
  out = []
  for sa in [1, -1] then for sb in [1, -1]
    A = if sa is 1 then a else a.neg()
    B = if sb is 1 then b else b.neg()
    out.push v3 ZERO, A, B
    out.push v3 B, ZERO, A
    out.push v3 A, B, ZERO
  out

alphabetOK = (verts) ->
  for v in verts
    big = 0; ok = true
    for b in sixBases
      d = v3dot v, b
      if d.equals(PHI_SQ) or d.equals(PHI_SQ.neg()) then big++
      else unless d.equals(INV_PHI) or d.equals(INV_PHI.neg()) then ok = false
    return false unless ok and big is 3
  true

famA = cubeCorners().concat cyclicFamily(INV_PHI, PHI)   # ridge (0, 1/phi, phi)
famB = cubeCorners().concat cyclicFamily(PHI, INV_PHI)   # ridge (0, phi, 1/phi)

VERTICES  = null
CHIRALITY = null
if alphabetOK famA
  VERTICES = famA; CHIRALITY = 'famA: cyclic (0, 1/phi, phi)'
if alphabetOK famB
  throw new Error 'both vertex families pass the alphabet test?!' if VERTICES?
  VERTICES = famB; CHIRALITY = 'famB: cyclic (0, phi, 1/phi)'
throw new Error 'neither vertex family matches the SixPhi alphabet' unless VERTICES?

# Faces: one per signed basis direction; the five vertices with v.b = +-phi^2.
# Cycle ordered CCW as seen from outside (float sort at build time only).

FACES = []       # {id, letter, sign, normal, cycle: [vertex indices]}
buildFaces = ->
  for i in [0..5]
    for sign in [1, -1]
      n    = if sign is 1 then sixBases[i] else v3neg sixBases[i]
      want = if sign is 1 then PHI_SQ else PHI_SQ.neg()
      # membership test against the SIGNED basis dot, exact
      idxs = (k for v, k in VERTICES when v3dot(v, sixBases[i]).equals want)
      throw new Error "face #{LETTERS[i]}#{sign}: expected 5 vertices, got #{idxs.length}" unless idxs.length is 5
      nf = v3float n
      cf = [0, 0, 0]
      cf[j] += v3float(VERTICES[k])[j] / 5 for j in [0..2] for k in idxs
      nlen = Math.hypot nf...
      nn   = (x / nlen for x in nf)
      r0   = (v3float(VERTICES[idxs[0]])[j] - cf[j] for j in [0..2])
      w    = [nn[1]*r0[2]-nn[2]*r0[1], nn[2]*r0[0]-nn[0]*r0[2], nn[0]*r0[1]-nn[1]*r0[0]]
      ang  = (k) ->
        r = (v3float(VERTICES[k])[j] - cf[j] for j in [0..2])
        Math.atan2 r[0]*w[0]+r[1]*w[1]+r[2]*w[2], r[0]*r0[0]+r[1]*r0[1]+r[2]*r0[2]
      idxs.sort (p, q) -> ang(p) - ang(q)
      FACES.push
        id: "#{LETTERS[i]}#{if sign is 1 then '+' else '-'}"
        letter: i, sign: sign, normal: n, cycle: idxs
buildFaces()

# 30 undirected edges, from face cycles
EDGE_SET = new Map
for f in FACES
  for k in [0..4]
    a = f.cycle[k]; b = f.cycle[(k+1) % 5]
    EDGE_SET.set "#{Math.min a, b}-#{Math.max a, b}", [a, b]
EDGES = Array.from EDGE_SET.values()
throw new Error "expected 30 edges, got #{EDGES.length}" unless EDGES.length is 30

# ------------------------------- Named rotations ----------------------------
# All built by exact Rodrigues, doubled.  |face axis|^2 = 2+phi,
# |vertex|^2 = 3, |edge dir|^2 = 4 (after the divide-by-phi normalization).

faceTurn = (d, k) ->     # k in {1,2,-1,-2}, units of +72 deg right-hand about d
  M2 = switch Math.abs k
    when 1 then m3add m3add(m3diag(INV_PHI), crossMat(d)), m3scale(P(2,-1), outerMat(d))
    when 2 then m3add m3add(m3diag(PHI.neg()), m3scale(INV_PHI, crossMat(d))), outerMat(d)
  if k < 0 then m3T M2 else M2

vertexTurn = (v, k) ->   # k in {1,-1}, units of +120 deg right-hand about v
  M2 = m3add m3add(m3diag(ONE.neg()), crossMat(v)), outerMat(v)
  if k < 0 then m3T M2 else M2

edgeFlip = (e) ->        # 180 deg about e, |e|^2 = 4
  m3add outerMat(e), m3diag(TWO.neg())

# --- vertex axes: which unsigned letter-triples are realized, and their
#     canonical direction (the end where >= 2 of the named dots are +phi^2)

tripleOf = (v) ->
  (LETTERS[i] for i in [0..5] when Math.abs(v3dot(v, sixBases[i]).toFloat()) > 2).join ''

VERTEX_AXES = new Map                      # 'ACE' -> canonical direction Vec3
for v in VERTICES
  t = tripleOf v
  t = t.split('').sort().join('')
  pos = (i for i in [0..5] when t.includes(LETTERS[i]) and v3dot(v, sixBases[i]).equals(PHI_SQ)).length
  VERTEX_AXES.set t, v if pos >= 2
throw new Error "expected 10 vertex axes, got #{VERTEX_AXES.size}" unless VERTEX_AXES.size is 10

# --- edge axes from letter pairs: axis = (b_i x b_j) / phi, |.|^2 = 4

EDGE_AXES = new Map                        # 'AB' -> direction Vec3
for i in [0..4]
  for j in [(i + 1)..5]
    e = v3scale INV_PHI, v3cross(sixBases[i], sixBases[j])
    throw new Error "edge axis #{LETTERS[i]}#{LETTERS[j]}: |e|^2 != 4" unless v3dot(e, e).equals P(4,0)
    EDGE_AXES.set LETTERS[i] + LETTERS[j], e

# --- assemble and verify the group

GROUP = [{name: 'id', M2: m3diag TWO}]
for i in [0..5]
  for k in [1, 2, -1, -2]
    GROUP.push {name: "#{LETTERS[i]} #{k}", M2: faceTurn(sixBases[i], k)}
VERTEX_AXES.forEach (v, t) ->
  GROUP.push {name: "#{t} 1",  M2: vertexTurn(v,  1)}
  GROUP.push {name: "#{t} -1", M2: vertexTurn(v, -1)}
EDGE_AXES.forEach (e, pair) ->
  GROUP.push {name: pair, M2: edgeFlip(e)}

signedPermOf = (M2) ->
  for i in [0..5]
    w = m3applyHalf M2, sixBases[i]
    hit = null
    for j in [0..5]
      hit = {j, s:  1} if v3eq w, sixBases[j]
      hit = {j, s: -1} if v3eq w, v3neg(sixBases[j])
    throw new Error "element does not permute the six axes" unless hit?
    hit

findElement = (M2) ->
  for g, idx in GROUP
    return idx if m3eq g.M2, M2
  -1

verifyGroup = ->
  throw new Error "expected 60 elements, got #{GROUP.length}" unless GROUP.length is 60
  for g, i in GROUP
    for h, j in GROUP
      throw new Error "duplicate elements #{g.name} = #{h.name}" if i < j and m3eq g.M2, h.M2
  g.perm = signedPermOf g.M2 for g in GROUP
  for g in GROUP
    for h in GROUP
      throw new Error "not closed: #{g.name} * #{h.name}" if findElement(m3mulHalf g.M2, h.M2) < 0
  true

# ------------------------------- Shared rendering ---------------------------

fcross = (a, b) -> [a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0]]
fnormz = (a) ->
  len = Math.hypot a...
  if len < 1e-9 then null else (x / len for x in a)

DEFAULT_DIR = fnormz [0.55, 0.5, 1.0]
VIEWMAT = null
setViewToward = (d) ->   # d: float direction from solid center toward the camera
  d = fnormz(d) ? DEFAULT_DIR
  up = if Math.abs(d[1]) > 0.94 then [1, 0, 0] else [0, 1, 0]
  u = fnormz fcross(up, d)
  v = fcross d, u
  VIEWMAT = [u, v, d]
setViewToward DEFAULT_DIR

ROT3 = (p) ->
  (VIEWMAT[i][0]*p[0] + VIEWMAT[i][1]*p[1] + VIEWMAT[i][2]*p[2] for i in [0..2])

VIEW = (v) ->
  [x, y, z] = ROT3 v
  [x, -y]

faceIsFront = (fi) ->
  n = ROT3 v3float FACES[fi].normal
  n[2] > 0

EDGE_FACES = new Map      # "a-b" -> [face indices]
for f, fi in FACES
  for k in [0..4]
    a = f.cycle[k]; b = f.cycle[(k+1) % 5]
    key = "#{Math.min a, b}-#{Math.max a, b}"
    EDGE_FACES.set key, [] unless EDGE_FACES.has key
    EDGE_FACES.get(key).push fi

svgScene = (segments3f, labels, dots, facePolys = []) ->
  # segments3f: [{a, b, cls}]  labels: [{at, text}]  dots: [{at, color, r}]
  # facePolys: [{pts: [3f...], fill, label}]
  pts = []
  pts.push VIEW(s.a), VIEW(s.b) for s in segments3f
  pts.push VIEW(l.at) for l in labels
  pts.push VIEW(p) for p in poly.pts for poly in facePolys
  xs = (p[0] for p in pts); ys = (p[1] for p in pts)
  [minX, maxX] = [Math.min(xs...), Math.max(xs...)]
  [minY, maxY] = [Math.min(ys...), Math.max(ys...)]
  pad = 0.9; scale = 150
  w = (maxX - minX + 2*pad) * scale
  h = (maxY - minY + 2*pad) * scale
  SX = (p) -> ((p[0] - minX + pad) * scale).toFixed 2
  SY = (p) -> ((p[1] - minY + pad) * scale).toFixed 2
  out = ["""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 #{w.toFixed 0} #{h.toFixed 0}" font-family="monospace">"""]
  out.push """<rect width="100%" height="100%" fill="white"/>"""
  styles =
    wireback: 'stroke="#dedede" stroke-width="1.2" stroke-dasharray="5,4"'
    wire:     'stroke="#b5b5b5" stroke-width="1.6"'
    path:     'stroke="#1a237e" stroke-width="3" stroke-linecap="round"'
  for poly in facePolys
    ps = (("#{SX VIEW p},#{SY VIEW p}") for p in poly.pts).join ' '
    out.push """<polygon points="#{ps}" fill="#{poly.fill}" stroke="none"/>"""
  order = ['wireback', 'wire', 'path']
  for cls in order
    for s in segments3f when s.cls is cls
      a = VIEW s.a; b = VIEW s.b
      out.push """<line x1="#{SX a}" y1="#{SY a}" x2="#{SX b}" y2="#{SY b}" #{styles[cls]}/>"""
  for poly in facePolys when poly.label?
    c = [0, 0, 0]
    c[j] += p[j] / poly.pts.length for j in [0..2] for p in poly.pts
    pc = VIEW c
    out.push """<text x="#{SX pc}" y="#{SY pc}" font-size="17" fill="#8d6e00" text-anchor="middle" opacity="0.75">#{poly.label}</text>"""
  for d in dots
    p = VIEW d.at
    out.push """<circle cx="#{SX p}" cy="#{SY p}" r="#{d.r ? 4.5}" fill="#{d.color}"/>"""
  for l in labels
    p = VIEW l.at
    out.push """<text x="#{(+SX(p)) + 7}" y="#{(+SY(p)) - 7}" font-size="11" fill="#333">#{l.text}</text>"""
  out.push "</svg>"
  out.join '\n'

wireframeSegs = ->
  for [a, b] in EDGES
    key   = "#{Math.min a, b}-#{Math.max a, b}"
    front = EDGE_FACES.get(key).some (fi) -> faceIsFront fi
    {a: v3float(VERTICES[a]), b: v3float(VERTICES[b]), cls: if front then 'wire' else 'wireback'}

# ------------------------------- Tokenizer (shared) --------------------------

tokenize = (text) ->
  lines = (line.replace /#.*$/, '' for line in text.split '\n')
  toks  = lines.join(' ').replace(/\[/g, ' [ ').replace(/\]/g, ' ] ')
  (t for t in toks.split(/\s+/) when t.length)

isInt = (t) -> /^-?\d+$/.test t

# ------------------------------- Edge (strut) turtle -------------------------

parseEdge = (toks, pos = 0, depth = 0) ->
  prog = []
  turnByName = (name) ->
    for g in GROUP when g.name is name then return g
    null
  while pos < toks.length
    t = toks[pos]; pos++
    tl = t.toLowerCase()
    switch tl
      when ']'
        throw new Error "unmatched ']'" if depth is 0
        return [prog, pos]
      when 'repeat'
        count = parseInt toks[pos]; pos++
        throw new Error "repeat needs '['" if toks[pos] isnt '['
        [body, pos] = parseEdge toks, pos + 1, depth + 1
        prog.push {op: 'repeat', count, body}
      when 'short'   then prog.push {op: 'step', size: 'short'}
      when 'long'    then prog.push {op: 'step', size: 'long'}
      when 'penup'   then prog.push {op: 'pen', down: false}
      when 'pendown' then prog.push {op: 'pen', down: true}
      else
        word = t.toUpperCase()
        if /^[A-F]{1,3}$/.test word
          canon = if word.length is 1 then word else word.split('').sort().join('')
          k = 1
          if toks[pos]? and isInt toks[pos]
            k = parseInt toks[pos]; pos++
          name = if canon.length is 2 then canon else "#{canon} #{k}"
          g = turnByName name
          unless g?
            extra = if canon.length is 3 then " (legal triples: #{Array.from(VERTEX_AXES.keys()).join ', '})" else ''
            throw new Error "no such rotation: '#{name}'#{extra}"
          prog.push {op: 'turn', g, name}
        else if tl in ['left', 'right', 'fold']
          throw new Error "'#{t}' is a face-turtle command — run: coffee phiTurtle3D.coffee face <file>"
        else
          throw new Error "unknown command: #{t}"
  throw new Error "missing ']'" if depth > 0
  [prog, pos]

runEdgeTurtle = (text) ->
  [prog] = parseEdge tokenize text
  faceA   = FACES[0]                       # A+
  ace     = VERTEX_AXES.get 'ACE'          # canonical ACE vertex, lies on A+
  k0      = faceA.cycle.findIndex (i) -> v3eq VERTICES[i], ace
  throw new Error 'ACE vertex not on face A+?!' if k0 < 0
  start   = VERTICES[faceA.cycle[k0]]
  heading = v3sub VERTICES[faceA.cycle[(k0 + 1) % 5]], start
  st =
    pos: start, heading: heading, pen: true
    segments: [], verts: new Map, trace: [], steps: 0
  key  = (v) -> v3str v
  mark = (v) -> st.verts.set key(v), v if st.pen
  mark st.pos
  exec = (cmd) ->
    switch cmd.op
      when 'repeat' then exec c for c in cmd.body for [1..cmd.count]
      when 'pen'    then st.pen = cmd.down
      when 'turn'
        st.heading = m3applyHalf cmd.g.M2, st.heading
        st.trace.push {kind: 'turn', name: cmd.name}
      when 'step'
        d    = if cmd.size is 'long' then v3scale(PHI, st.heading) else st.heading
        next = v3add st.pos, d
        st.segments.push [st.pos, next] if st.pen
        mark st.pos; st.pos = next; mark st.pos
        st.steps++
        st.trace.push {kind: 'step', size: cmd.size, pos: st.pos, pen: st.pen}
  exec c for c in prog
  st.start = start
  st

edgeReport = (st) ->
  lines = ["start at #{v3str st.start}  (vertex ACE, on face A+)", ""]
  n = 0
  for t in st.trace
    if t.kind is 'turn'
      lines.push "      turn #{t.name}"
    else
      n++
      lines.push "#{String(n).padStart 4}  #{t.size.padEnd 5}  #{v3str t.pos}#{if t.pen then '' else '   [pen up]'}"
  if v3eq st.pos, st.start
    lines.push "", "CLOSED: turtle returned to #{v3str st.start} exactly."
  else
    lines.push "", "OPEN: turtle rests at #{v3str st.pos}."
  lines.join '\n'

edgeSVG = (st) ->
  c = [0, 0, 0]; n = 0
  st.verts.forEach (v) ->
    f = v3float v
    c[j] += f[j] for j in [0..2]
    n++
  setViewToward (if n then (x / n for x in c) else null)
  segs = wireframeSegs()
  segs.push {a: v3float(a), b: v3float(b), cls: 'path'} for [a, b] in st.segments
  labels = []; dots = []
  st.verts.forEach (v) ->
    origin = v3eq v, st.start
    dots.push {at: v3float(v), color: if origin then '#c62828' else '#1a237e'}
    labels.push {at: v3float(v), text: v3str(v).replace(/ /g, '')}
  svgScene segs, labels, dots

# ------------------------------- Face (walker) turtle ------------------------
# 2D chart per face: the standard pentagon, side 1 = one dodec edge, in the
# (e0, e72) basis.  Chart points are exact PhiBase pairs.  Fold = exact
# affine chart transition; psi never appears.

R36chart = [[P(-1,1), P(1,-1)], [P(-1,1), P(1,0)]]
chartRot = do ->
  pows = [[[ONE, ZERO], [ZERO, ONE]]]
  mul2 = (A, B) ->
    for i in [0..1]
      for j in [0..1]
        A[i][0].mul(B[0][j]).add A[i][1].mul(B[1][j])
  pows.push mul2(R36chart, pows[k]) for k in [0..8]
  pows
applyRot = (r, [a, b]) ->
  M = chartRot[((r % 10) + 10) % 10]
  [M[0][0].mul(a).add(M[0][1].mul b), M[1][0].mul(a).add(M[1][1].mul b)]

c2add = ([a,b],[c,d]) -> [a.add(c), b.add(d)]
c2sub = ([a,b],[c,d]) -> [a.sub(c), b.sub(d)]
c2eq  = ([a,b],[c,d]) -> a.equals(c) and b.equals(d)
c2str = ([a,b]) -> "(#{a}, #{b})"

UNIT2 = do ->                       # 2D unit displacement table, headings 0..9
  t = [[ONE, ZERO]]
  t.push applyRot(1, t[k]) for k in [0..8]
  t
PENTA = do ->                       # standard chart pentagon, side 1, CCW
  vs = [[ZERO, ZERO]]
  vs.push c2add(vs[k], UNIT2[2*k]) for k in [0..3]
  vs

# face adjacency + transitions across each chart edge
TRANSITIONS = ({} for f in FACES)   # TRANSITIONS[faceIdx][k] = {to, rot, t}
buildTransitions = ->
  for f, fi in FACES
    for k in [0..4]
      a = f.cycle[k]; b = f.cycle[(k+1) % 5]
      for g, gi in FACES when gi isnt fi
        for m in [0..4]
          if g.cycle[m] is b and g.cycle[(m+1) % 5] is a
            rot = (((2*m + 5 - 2*k) % 10) + 10) % 10
            t   = c2sub PENTA[(m+1) % 5], applyRot(rot, PENTA[k])
            TRANSITIONS[fi][k] = {to: gi, rot, t}
  # sanity: fold there and back is the identity on a probe point
  probe = [P(3,-2), P(1,4)]
  for f, fi in FACES
    for k in [0..4]
      tr  = TRANSITIONS[fi][k]
      throw new Error "missing transition #{f.id}/#{k}" unless tr?
      # the reverse edge index m on the neighbor:
      back = null
      for m in [0..4] when TRANSITIONS[tr.to][m]?.to is fi
        cand = TRANSITIONS[tr.to][m]
        p2 = c2add applyRot(cand.rot, c2add(applyRot(tr.rot, probe), tr.t)), cand.t
        back = m if c2eq p2, probe
      throw new Error "fold round-trip failed at #{f.id}/#{k}" unless back?
buildTransitions()

# float embedding of a chart into 3D, per face (render only)
EMBED = for f in FACES
  V = (v3float VERTICES[f.cycle[i]] for i in [0..4])
  ex  = (V[1][j] - V[0][j] for j in [0..2])
  s   = Math.hypot ex...
  ex  = (x / s for x in ex)
  d2  = (V[2][j] - V[0][j] for j in [0..2])
  dpe = d2[0]*ex[0] + d2[1]*ex[1] + d2[2]*ex[2]
  ey  = (d2[j] - dpe * ex[j] for j in [0..2])
  el  = Math.hypot ey...
  ey  = (y / el for y in ey)
  # chart v2 must land on V2 — flip ey if the other sign fits better (it won't, CCW is consistent)
  {origin: V[0], ex, ey, s}

COS72 = (PHI_FLOAT - 1) / 2
SIN72 = Math.sqrt 1 - COS72*COS72
chartTo3D = (fi, [a, b]) ->
  e  = EMBED[fi]
  x2 = a.toFloat() + b.toFloat() * COS72
  y2 = b.toFloat() * SIN72
  (e.origin[j] + e.s * (x2 * e.ex[j] + y2 * e.ey[j]) for j in [0..2])

parseFace = (toks, pos = 0, depth = 0) ->
  prog = []
  while pos < toks.length
    t = toks[pos].toLowerCase(); pos++
    switch t
      when ']'
        throw new Error "unmatched ']'" if depth is 0
        return [prog, pos]
      when 'repeat'
        count = parseInt toks[pos]; pos++
        throw new Error "repeat needs '['" if toks[pos] isnt '['
        [body, pos] = parseFace toks, pos + 1, depth + 1
        prog.push {op: 'repeat', count, body}
      when 'left', 'right'
        k = 1
        if toks[pos]? and isInt toks[pos]
          k = parseInt toks[pos]; pos++
        k = -k if t is 'right'
        prog.push {op: 'turn', k}
      when 'short'   then prog.push {op: 'step', size: 'short'}
      when 'long'    then prog.push {op: 'step', size: 'long'}
      when 'penup'   then prog.push {op: 'pen', down: false}
      when 'pendown' then prog.push {op: 'pen', down: true}
      when 'fold'
        throw new Error "fold needs an edge index 0..4" unless toks[pos]? and isInt toks[pos]
        k = parseInt toks[pos]; pos++
        throw new Error "fold edge must be 0..4" unless 0 <= k <= 4
        prog.push {op: 'fold', k}
      else
        if /^[a-f]{1,3}$/.test t
          throw new Error "'#{t}' looks like an edge-turtle turn — run: coffee phiTurtle3D.coffee edge <file>"
        throw new Error "unknown command: #{t}"
  throw new Error "missing ']'" if depth > 0
  [prog, pos]

runFaceTurtle = (text) ->
  [prog] = parseFace tokenize text
  st =
    face: 0                       # A+
    pos: [ZERO, ZERO]             # chart vertex 0
    heading: 0                    # 36-degree units in the chart
    pen: true
    segments: []                  # {face, from, to}
    verts: []                     # {face, at}
    trace: []
    steps: 0
  key  = (fi, p) -> "#{fi}|#{c2str p}"
  seen = new Set
  mark = ->
    return unless st.pen
    k = key st.face, st.pos
    unless seen.has k
      seen.add k
      st.verts.push {face: st.face, at: st.pos}
  mark()
  exec = (cmd) ->
    switch cmd.op
      when 'repeat' then exec c for c in cmd.body for [1..cmd.count]
      when 'pen'    then st.pen = cmd.down
      when 'turn'   then st.heading = ((st.heading + cmd.k) % 10 + 10) % 10
      when 'step'
        d = UNIT2[st.heading]
        d = [PHI.mul(d[0]), PHI.mul(d[1])] if cmd.size is 'long'
        next = c2add st.pos, d
        st.segments.push {face: st.face, from: st.pos, to: next} if st.pen
        mark(); st.pos = next; mark()
        st.steps++
        st.trace.push {kind: 'step', size: cmd.size, face: FACES[st.face].id, pos: st.pos, pen: st.pen}
      when 'fold'
        tr = TRANSITIONS[st.face][cmd.k]
        st.pos     = c2add applyRot(tr.rot, st.pos), tr.t
        st.heading = ((st.heading + tr.rot) % 10 + 10) % 10
        st.face    = tr.to
        st.trace.push {kind: 'fold', k: cmd.k, faceIdx: st.face, face: FACES[st.face].id, pos: st.pos}
  exec c for c in prog
  st

faceReport = (st) ->
  lines = ["start on face A+ at chart (P(0,0), P(0,0)), heading 0", ""]
  n = 0
  for t in st.trace
    if t.kind is 'fold'
      lines.push "      fold #{t.k}  ->  face #{t.face}, chart #{c2str t.pos}"
    else
      n++
      lines.push "#{String(n).padStart 4}  #{t.size.padEnd 5}  face #{t.face}  #{c2str t.pos}#{if t.pen then '' else '   [pen up]'}"
  lines.join '\n'

faceSVG = (st) ->
  visited = new Set [0]
  visited.add s.face for s in st.segments
  visited.add t.faceIdx for t in st.trace when t.kind is 'fold'
  visited.add st.face
  c = [0, 0, 0]
  visited.forEach (fi) ->
    nf = v3float FACES[fi].normal
    c[j] += nf[j] for j in [0..2]
  setViewToward c
  segs = wireframeSegs()
  for s in st.segments
    segs.push {a: chartTo3D(s.face, s.from), b: chartTo3D(s.face, s.to), cls: 'path'}
  facePolys = []
  visited.forEach (fi) ->
    facePolys.push
      pts: (v3float VERTICES[i] for i in FACES[fi].cycle)
      fill: '#fdf3d0'
      label: FACES[fi].id
  labels = []; dots = []
  for v, i in st.verts
    at = chartTo3D v.face, v.at
    dots.push {at, color: '#1a237e', r: 3}
  startAt = chartTo3D 0, [ZERO, ZERO]
  dots.push {at: startAt, color: '#c62828', r: 5}
  labels.push {at: startAt, text: "start A+ (P(0,0),P(0,0))"}
  for t in st.trace when t.kind is 'fold'
    at = chartTo3D t.faceIdx, t.pos
    dots.push {at, color: '#e65100', r: 4.5}
    labels.push {at, text: "fold&#8594;#{t.face} #{c2str(t.pos).replace(/ /g, '')}"}
  finalAt = chartTo3D st.face, st.pos
  labels.push {at: finalAt, text: "end #{FACES[st.face].id} #{c2str(st.pos).replace(/ /g, '')}"}
  svgScene segs, labels, dots, facePolys

# ------------------------------- verify -------------------------------------

doVerify = ->
  console.log "chirality: #{CHIRALITY}"
  console.log "vertices: #{VERTICES.length}, faces: #{FACES.length}, edges: #{EDGES.length}"
  verifyGroup()
  console.log "group: 60 distinct elements, closed under composition, every"
  console.log "       element acts on the six axes as an exact signed permutation."
  console.log "legal vertex-axis triples: #{Array.from(VERTEX_AXES.keys()).sort().join ' '}"
  console.log ""
  permStr = (perm) ->
    (("#{if e.s > 0 then '+' else '-'}#{LETTERS[e.j]}") for e in perm).join ' '
  console.log "name      action on axes A..F"
  for g in GROUP
    console.log "#{g.name.padEnd 8}  #{permStr g.perm}"
  json =
    chirality: CHIRALITY
    vertexTriples: Array.from(VERTEX_AXES.keys()).sort()
    elements: ({name: g.name, perm: g.perm} for g in GROUP)
  fs.writeFileSync 'icosaGroup.json', JSON.stringify(json, null, 1)
  console.log "\nwrote icosaGroup.json"

# ------------------------------- main ----------------------------------------

main = ->
  mode = process.argv[2]
  if mode is 'verify'
    doVerify()
  else if mode in ['edge', 'face'] and process.argv[3]?
    file = process.argv[3]
    text = fs.readFileSync file, 'utf8'
    verifyGroup()
    if mode is 'edge'
      st = runEdgeTurtle text
      console.log edgeReport st
      out = path.join path.dirname(file), path.basename(file, path.extname file) + '.svg'
      fs.writeFileSync out, edgeSVG st
    else
      st = runFaceTurtle text
      console.log faceReport st
      out = path.join path.dirname(file), path.basename(file, path.extname file) + '.svg'
      fs.writeFileSync out, faceSVG st
    console.log "wrote #{out}"
  else
    console.error "usage: coffee phiTurtle3D.coffee verify | edge <walk.txt> | face <walk.txt>"
    process.exit 1

main()
