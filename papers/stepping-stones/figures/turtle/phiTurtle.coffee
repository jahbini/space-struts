#!/usr/bin/env coffee
###
phiTurtle.coffee — a PhiBase turtle for students.

  coffee phiTurtle.coffee walk.txt        # writes walk.svg, prints coordinate table

The turtle lives on the 36-degree lattice.  Position is held in the
(e0, e72) basis — e0 = (1,0), e72 = (cos 72, sin 72) — so that every
vertex the turtle can reach is an exact pair of PhiBase numbers
(P(n,p), P(n,p)) with P(n,p) = n + p*phi.  No trigonometry, no floats,
no drift: floating point appears ONLY at SVG render time.

Command language (case-insensitive, '#' starts a comment):

  short            step forward one short unit (length 1)        alias: s
  long             step forward one long unit  (length phi)      alias: l
  left  [k]        turn k * 36 degrees counterclockwise (k=1)    alias: +
  right [k]        turn k * 36 degrees clockwise       (k=1)     alias: -
  penup            move without drawing                          alias: u
  pendown          draw while moving (initial state)             alias: d
  above            set label placement above for later `label`s   alias: ^
  below            set label placement below for later `label`s   alias: v
  label            attach a text label to the current vertex      alias: !
  scalephi n       multiply rendered lengths by phi^n (default 3)
                   Text size and arrow scale with n automatically.
  repeat n [ ... ] run the bracketed block n times

  Labels are OFF by default. A vertex only shows its address if a
  `label` command has been issued while the turtle sits on it.
  `above`/`below` only control which side of the point the text
  goes; they do not by themselves produce a label.
###

fs   = require 'fs'
path = require 'path'
xOnly = false
growPHI = 3

# ---------------- PhiBase: P(n,p) = n + p*phi, integer n and p --------------

class PhiBase
  constructor: (@n, @p) ->
  add:    (o) -> new PhiBase @n + o.n, @p + o.p
  sub:    (o) -> new PhiBase @n - o.n, @p - o.p
  mul:    (o) -> new PhiBase @n * o.n + @p * o.p, @n * o.p + @p * o.n + @p * o.p
  isZero:     -> @n is 0 and @p is 0
  toFloat:    -> @n*(PHI_FLOAT**growPHI) + @p * (PHI_FLOAT ** (growPHI+1) )         # render only
  toString:   -> "P(#{@n},#{@p})"

P = (n, p) -> new PhiBase n, p

PHI_FLOAT = (1 + Math.sqrt 5) / 2            # render only
COS72     = (PHI_FLOAT - 1) / 2              # render only
SIN72     = Math.sqrt(1 - COS72 * COS72)     # render only

# ---------------- The 36-degree rotation in the (e0, e72) basis -------------
#
#   R36 = [ phi-1   1-phi ]        det = (phi-1)*phi = 1
#         [ phi-1     1   ]
#
# Exact in Z[phi]; ten applications return to the identity.

PHI_M1 = P -1,  1        # phi - 1
ONE_MP = P  1, -1        # 1 - phi
PHI    = P  0,  1        # phi

rot36 = ([a, b]) ->
  [ PHI_M1.mul(a).add(ONE_MP.mul b), PHI_M1.mul(a).add(b) ]

# Displacement tables: UNIT_DISP[k] is one short step at heading k*36 degrees,
# LONG_DISP[k] is one long step (phi times the short step).

UNIT_DISP = [ [P(1,0), P(0,0)] ]
UNIT_DISP.push rot36 UNIT_DISP[k] for k in [0...9]
LONG_DISP = ([PHI.mul(a), PHI.mul(b)] for [a, b] in UNIT_DISP)

# ---------------- Parser -----------------------------------------------------

tokenize = (text) ->
  lines = (line.replace /#.*$/, '' for line in text.split '\n')
  toks  = lines.join(' ').replace(/\[/g, ' [ ').replace(/\]/g, ' ] ')
  (t.toLowerCase() for t in toks.split(/\s+/) when t.length)

parse = (toks, pos = 0, depth = 0) ->
  prog = []
  while pos < toks.length
    t = toks[pos]; pos++
    switch t
      when ']'
        throw new Error "unmatched ']'" if depth is 0
        return [prog, pos]
      when 'repeat'
        count = parseInt toks[pos]; pos++
        throw new Error "repeat needs a count" if isNaN count
        throw new Error "repeat needs '['"     if toks[pos] isnt '['
        [body, pos] = parse toks, pos + 1, depth + 1
        prog.push {op: 'repeat', count, body}
      when 'left', '+', 'right', '-'
        k = 1
        if toks[pos]? and /^\d+$/.test toks[pos]
          k = parseInt toks[pos]; pos++
        k = -k if t in ['right', '-']
        prog.push {op: 'turn', k}
      when 'short', 's' then prog.push {op: 'step', size: 'short'}
      when 'long',  'l' then prog.push {op: 'step', size: 'long'}
      when 'penup', 'u' then prog.push {op: 'pen', down: false}
      when 'pendown','d' then prog.push {op: 'pen', down: true}
      when 'xonly', 'x' then xOnly = true
      when 'above', '^' then prog.push {op: 'labelSide', side: 'above'}
      when 'below', 'v' then prog.push {op: 'labelSide', side: 'below'}
      when 'label', '!' then prog.push {op: 'label'}
      when 'scalephi'
        n = parseInt toks[pos]; pos++
        throw new Error "scalephi needs a nonnegative integer" if isNaN(n) or n < 0
        growPHI = n
      else throw new Error "unknown command: #{t}"
  throw new Error "missing ']'" if depth > 0
  [prog, pos]

# ---------------- Turtle ------------------------------------------------------

class Turtle
  constructor: ->
    @pos       = [P(0,0), P(0,0)]
    @heading   = 0                 # multiples of 36 degrees, 0..9
    @pen       = true
    @labelSide = 'above'
    @segments  = []                # [from, to] pairs of exact points
    @verts     = new Map           # key -> {pt, side}, dedup for labels
    @trace     = []
    @steps     = 0
    @mark @pos

  key: ([a, b]) -> "#{a.n},#{a.p};#{b.n},#{b.p}"

  mark: (pt) ->
    return unless @pen
    key = @key pt
    existing = @verts.get key
    if existing?
      existing.side = @labelSide     # keep any existing `labeled` flag
    else
      @verts.set key, {pt, side: @labelSide, labeled: false}

  run: (prog) -> @exec cmd for cmd in prog

  exec: (cmd) ->
    switch cmd.op
      when 'repeat' then @run cmd.body for [1..cmd.count]
      when 'pen'    then @pen = cmd.down
      when 'turn'   then @heading = ((@heading + cmd.k) % 10 + 10) % 10
      when 'labelSide'
        @labelSide = cmd.side
        # Retroactively update the current vertex's side if it exists,
        # so `short above label` and `short label above` behave the same.
        entry = @verts.get @key(@pos)
        entry.side = @labelSide if entry?
      when 'label'
        # `label` is honored regardless of pen state — create the
        # vertex entry (and thus a dot) if the turtle is standing on
        # an unmarked point due to pen-up moves.
        key = @key @pos
        entry = @verts.get key
        unless entry?
          entry = {pt: @pos, side: @labelSide, labeled: false}
          @verts.set key, entry
        entry.labeled = true
      when 'step'
        table = if cmd.size is 'long' then LONG_DISP else UNIT_DISP
        [da, db] = table[@heading]
        next = [@pos[0].add(da), @pos[1].add(db)]
        @segments.push [@pos, next] if @pen
        @mark @pos; @pos = next; @mark @pos
        @steps++
        @trace.push
          step: @steps, size: cmd.size, heading: @heading * 36
          pos: @pos, pen: @pen

# ---------------- SVG render (floats allowed from here down) ------------------

toXY = ([a, b]) ->
  x = a.toFloat() + b.toFloat() * COS72
  y = b.toFloat() * SIN72
  [x, -y]                          # flip y: SVG grows downward

render = (turtle) ->
  pts = (toXY entry.pt for entry from turtle.verts.values())
  for [from, to] in turtle.segments
    pts.push toXY(from), toXY(to)
  pts.push [0, 0]
  xs = (p[0] for p in pts); ys = (p[1] for p in pts)
  [minX, maxX] = [Math.min(xs...), Math.max(xs...)]
  [minY, maxY] = [Math.min(ys...), Math.max(ys...)]
  pad   = 1.2
  scale = 130
  w = (maxX - minX + 2 * pad) * scale
  h = (maxY - minY + 2 * pad) * scale
  sx = (x) -> (x - minX + pad) * scale
  sy = (y) -> (y - minY + pad) * scale

  # Everything visual (text, offsets, arrow, dots, strokes) scales
  # by phi^growPHI so bumping `scalephi` keeps proportions right.
  s          = PHI_FLOAT ** growPHI
  fontSize   = Math.round 15 * s
  offAbove   = 2 * s
  offBelow   = fontSize
  offRight   = 2 * s
  arrowPx    = 19 * s
  arrowSW    = 1 * s
  vertR      = 1.1 * s
  strokeShort = 0.6 * s
  footerSize = Math.round 8 * s

  svg = []
  svg.push """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 #{w.toFixed 0} #{h.toFixed 0}" font-family="monospace">"""
  svg.push """<defs><marker id="arrow" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse"><path d="M0,0 L10,5 L0,10 z" fill="#2e7d32"/></marker></defs>"""
  svg.push """<rect width="100%" height="100%" fill="white"/>"""

  for [from, to] in turtle.segments
    [x1, y1] = toXY from; [x2, y2] = toXY to
    svg.push """<line x1="#{sx(x1).toFixed 2}" y1="#{sy(y1).toFixed 2}" x2="#{sx(x2).toFixed 2}" y2="#{sy(y2).toFixed 2}" stroke="#1a237e" stroke-width="#{strokeShort.toFixed 2}" stroke-linecap="round"/>"""

  for entry from turtle.verts.values()
    {pt, side, labeled} = entry
    [x, y]  = toXY pt
    [a, b]  = pt
    origin  = a.isZero() and b.isZero()
    svg.push """<circle cx="#{sx(x).toFixed 2}" cy="#{sy(y).toFixed 2}" r="#{vertR.toFixed 2}" fill="#{if origin then '#c62828' else '#1a237e'}"/>"""
    if labeled
      ty = if side is 'below' then sy(y) + offBelow else sy(y) - offAbove
      label = if xOnly then "#{a}" else "(#{a},#{b})"
      svg.push """<text x="#{(sx(x) + offRight).toFixed 2}" y="#{ty.toFixed 2}" font-size="#{fontSize}" fill="#333">#{label}</text>"""

  # Heading indicator: a short arrow at the turtle's final position,
  # pointing in the direction of the next short step.
  [ax, ay] = toXY turtle.pos
  [dx, dy] = toXY UNIT_DISP[turtle.heading]     # delta in world coords
  mag = Math.sqrt(dx*dx + dy*dy)
  if mag > 0
    ux = dx / mag; uy = dy / mag
    x1 = sx(ax); y1 = sy(ay)
    x2 = x1 + ux * arrowPx; y2 = y1 + uy * arrowPx
    svg.push """<line x1="#{x1.toFixed 2}" y1="#{y1.toFixed 2}" x2="#{x2.toFixed 2}" y2="#{y2.toFixed 2}" stroke="#2e7d32" stroke-width="#{arrowSW.toFixed 2}" stroke-linecap="round" marker-end="url(#arrow)"/>"""

  svg.push """<text x="12" y="#{(h - 4).toFixed 0}" font-size="#{footerSize}" fill="#666">basis: e0=(1,0), e72=(cos72&#176;,sin72&#176;) &#8212; coordinates are exact P(n,p) = n + p&#183;&#966;</text>""" unless xOnly
  svg.push "</svg>"
  svg.join '\n'

# ---------------- Main ---------------------------------------------------------

main = ->
  file = process.argv[2]
  unless file
    console.error "usage: coffee phiTurtle.coffee <walkfile.txt>"
    process.exit 1
  [prog] = parse tokenize fs.readFileSync(file, 'utf8')
  turtle = new Turtle
  turtle.run prog

  console.log "step  size   heading  position"
  for t in turtle.trace
    sz = t.size.padEnd 5
    console.log "#{String(t.step).padStart 4}  #{sz}  #{String(t.heading).padStart 4}\u00b0   (#{t.pos[0]}, #{t.pos[1]})#{if t.pen then '' else '   [pen up]'}"

  [a, b] = turtle.pos
  if a.isZero() and b.isZero()
    console.log "\nCLOSED: turtle returned to (P(0,0), P(0,0)) exactly."
  else
    console.log "\nOPEN: turtle rests at (#{a}, #{b})."

  out = path.join path.dirname(file), path.basename(file, path.extname file) + '.svg'
  fs.writeFileSync out, render turtle
  console.log "wrote #{out}"

main()
