#!/usr/bin/env coffee
###
phiTurtle.coffee — an exact PhiBase turtle for students and book figures.

  coffee phiTurtle.coffee walk.txt

The turtle lives on the 36-degree lattice. Position is held exactly in
an (e0, e72) basis, where e0=(1,0) and e72=(cos72°,sin72°). Each basis
coordinate is a PhiBase number P(n,p)=n+pφ. Floating point appears only
when the exact construction is converted to SVG coordinates.

Command language (case-insensitive; # begins a comment):

  short                 step one short unit, length 1             alias: s
  long                  step one long unit, length φ              alias: l
  left [k]              turn k×36° counterclockwise               alias: +
  right [k]             turn k×36° clockwise                      alias: -
  penup                 move without drawing                      alias: u
  pendown               draw while moving                         alias: d
  above                 set label placement above (for `label`)   alias: ^
  below                 set label placement below (for `label`)   alias: v
  label                 attach a label to the current vertex      alias: !
  repeat n [ ... ]      run the bracketed block n times

  Labels are OFF by default. A vertex is drawn without text unless
  a `label` command was issued while the turtle sat on it.
  `above`/`below` only choose the side; they do not by themselves
  produce a label. The `labels address|step|both|none` command
  still controls WHAT a shown label contains (`none` suppresses all).
  xonly                 label only the first exact coordinate     alias: x
  labels address        exact-coordinate labels (default)
  labels step           walking-order labels
  labels both           both address and walking-order labels
  labels none           no vertex labels

The generated SVG distinguishes short and long segments. A closed walk
is checked by exact arithmetic, not by floating-point proximity.
###

fs   = require 'fs'
path = require 'path'

# ---------------- PhiBase: P(n,p)=n+pφ, with integer n and p ---------------

class PhiBase
  constructor: (@n, @p) ->
    unless Number.isSafeInteger(@n) and Number.isSafeInteger(@p)
      throw new Error "PhiBase coefficients must be safe integers"

  add: (o) -> new PhiBase @n + o.n, @p + o.p
  sub: (o) -> new PhiBase @n - o.n, @p - o.p
  mul: (o) ->
    new PhiBase \
      @n * o.n + @p * o.p, \
      @n * o.p + @p * o.n + @p * o.p

  equals: (o) -> @n is o.n and @p is o.p
  isZero: -> @n is 0 and @p is 0
  toFloat: -> @n + @p * PHI_FLOAT       # rendering only
  toString: -> "P(#{@n},#{@p})"

P = (n, p) -> new PhiBase n, p

PHI_FLOAT = (1 + Math.sqrt(5)) / 2       # rendering only
COS72     = (PHI_FLOAT - 1) / 2          # rendering only
SIN72     = Math.sqrt(1 - COS72 * COS72) # rendering only

# ---------------- Exact 36-degree rotation in the (e0,e72) basis -----------
#
#   R36 = [ φ-1   1-φ ]
#         [ φ-1     1 ]
#
# Its determinant is 1. Ten applications return exactly to the identity.

PHI_M1 = P -1,  1       # φ-1
ONE_MP = P  1, -1       # 1-φ
PHI    = P  0,  1       # φ

rot36 = ([a, b]) ->
  [
    PHI_M1.mul(a).add ONE_MP.mul(b)
    PHI_M1.mul(a).add b
  ]

samePoint = ([a1, b1], [a2, b2]) -> a1.equals(a2) and b1.equals(b2)

UNIT_DISP = [[P(1,0), P(0,0)]]
UNIT_DISP.push rot36(UNIT_DISP[k]) for k in [0...9]
LONG_DISP = ([PHI.mul(a), PHI.mul(b)] for [a, b] in UNIT_DISP)

unless samePoint(rot36(UNIT_DISP[9]), UNIT_DISP[0])
  throw new Error 'internal error: ten 36-degree turns did not return exactly'

# ---------------- Parser ----------------------------------------------------

tokenize = (text) ->
  lines = (line.replace(/#.*$/, '') for line in text.split '\n')
  joined = lines.join(' ').replace(/\[/g, ' [ ').replace(/\]/g, ' ] ')
  (token.toLowerCase() for token in joined.split(/\s+/) when token.length)

readNonnegativeInteger = (token, description) ->
  unless token? and /^\d+$/.test(token)
    throw new Error "#{description} must be a nonnegative integer"
  Number token

parse = (tokens, pos = 0, depth = 0, options = null) ->
  options ?=
    xOnly: false
    labels: 'address'

  program = []

  while pos < tokens.length
    token = tokens[pos]
    pos++

    switch token
      when ']'
        throw new Error "unmatched ']'" if depth is 0
        return [program, pos, options]

      when 'repeat'
        count = readNonnegativeInteger tokens[pos], 'repeat count'
        pos++
        throw new Error "repeat needs '['" unless tokens[pos] is '['
        [body, pos, options] = parse tokens, pos + 1, depth + 1, options
        program.push op: 'repeat', count, body

      when 'left', '+', 'right', '-'
        turns = 1
        if tokens[pos]? and /^\d+$/.test(tokens[pos])
          turns = Number tokens[pos]
          pos++
        turns = -turns if token in ['right', '-']
        program.push {op: 'turn', turns}

      when 'short', 's'
        program.push op: 'step', size: 'short'

      when 'long', 'l'
        program.push op: 'step', size: 'long'

      when 'penup', 'u'
        program.push op: 'pen', down: false

      when 'pendown', 'd'
        program.push op: 'pen', down: true

      when 'xonly', 'x'
        options.xOnly = true

      when 'above', '^'
        program.push op: 'labelSide', side: 'above'

      when 'below', 'v'
        program.push op: 'labelSide', side: 'below'

      when 'label', '!'
        program.push op: 'label'

      when 'labels'
        mode = tokens[pos]
        pos++
        unless mode in ['address', 'step', 'both', 'none']
          throw new Error "labels must be address, step, both, or none"
        options.labels = mode

      else
        throw new Error "unknown command: #{token}"

  throw new Error "missing ']'" if depth > 0
  [program, pos, options]

# ---------------- Turtle ----------------------------------------------------

class Turtle
  constructor: ->
    @pos = [P(0,0), P(0,0)]
    @heading = 0                # multiples of 36°, normalized to 0..9
    @pen = true
    @labelSide = 'above'
    @segments = []              # {from,to,size,step}
    @vertices = new Map         # exact key -> {point, firstVisit, side}
    @trace = []
    @steps = 0
    @mark @pos, 0

  key: ([a, b]) -> "#{a.n},#{a.p};#{b.n},#{b.p}"

  mark: (point, visit) ->
    key = @key point
    unless @vertices.has key
      @vertices.set key, {point, firstVisit: visit, side: @labelSide, labeled: false}

  run: (program) -> @exec(command) for command in program

  exec: (command) ->
    switch command.op
      when 'repeat'
        @run(command.body) for i in [0...command.count]

      when 'pen'
        @pen = command.down

      when 'turn'
        @heading = ((@heading + command.turns) % 10 + 10) % 10

      when 'labelSide'
        @labelSide = command.side
        entry = @vertices.get @key(@pos)
        entry.side = @labelSide if entry?

      when 'label'
        # `label` is honored regardless of pen state — create the
        # vertex entry (and thus a dot) if the turtle stands on an
        # unmarked point due to pen-up moves.
        key = @key @pos
        entry = @vertices.get key
        unless entry?
          entry = {point: @pos, firstVisit: @steps, side: @labelSide, labeled: false}
          @vertices.set key, entry
        entry.labeled = true

      when 'step'
        table = if command.size is 'long' then LONG_DISP else UNIT_DISP
        [da, db] = table[@heading]
        next = [@pos[0].add(da), @pos[1].add(db)]
        @steps++

        if @pen
          @segments.push
            from: @pos
            to: next
            size: command.size
            step: @steps
          @mark @pos, @steps - 1
          @mark next, @steps

        @pos = next
        @trace.push
          step: @steps
          size: command.size
          heading: @heading * 36
          pos: @pos
          pen: @pen

# ---------------- SVG rendering (floating point allowed below) --------------

toXY = ([a, b]) ->
  x = a.toFloat() + b.toFloat() * COS72
  y = b.toFloat() * SIN72
  [x, -y]                         # SVG y increases downward

escapeXml = (value) ->
  String(value)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&apos;')

pointAddress = ([a, b], xOnly) ->
  if xOnly then "#{a}" else "(#{a},#{b})"

render = (turtle, options) ->
  points = []
  points.push toXY(entry.point) for entry from turtle.vertices.values()
  for segment in turtle.segments
    points.push toXY(segment.from), toXY(segment.to)
  points.push [0,0] if points.length is 0

  xs = (point[0] for point in points)
  ys = (point[1] for point in points)
  minX = Math.min xs...
  maxX = Math.max xs...
  minY = Math.min ys...
  maxY = Math.max ys...

  pad = 1.2
  scale = 130
  width = Math.max 1, (maxX - minX + 2 * pad) * scale
  height = Math.max 1, (maxY - minY + 2 * pad) * scale
  sx = (x) -> (x - minX + pad) * scale
  sy = (y) -> (y - minY + pad) * scale

  svg = []
  svg.push """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 #{width.toFixed(0)} #{height.toFixed(0)}" font-family="monospace" role="img">"""
  svg.push """<defs><marker id="arrow" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse"><path d="M0,0 L10,5 L0,10 z" fill="#2e7d32"/></marker></defs>"""
  svg.push '<rect width="100%" height="100%" fill="white"/>'

  for segment in turtle.segments
    [x1, y1] = toXY segment.from
    [x2, y2] = toXY segment.to
    stroke = if segment.size is 'long' then '#8e3b1f' else '#1a237e'
    widthPx = if segment.size is 'long' then 3.5 else 2.5
    svg.push """<line x1="#{sx(x1).toFixed(2)}" y1="#{sy(y1).toFixed(2)}" x2="#{sx(x2).toFixed(2)}" y2="#{sy(y2).toFixed(2)}" stroke="#{stroke}" stroke-width="#{widthPx}" stroke-linecap="round"/>"""

  showAddress = options.labels in ['address', 'both']
  showStep = options.labels in ['step', 'both']
  showLabels = options.labels isnt 'none'

  for entry from turtle.vertices.values()
    [x, y] = toXY entry.point
    [a, b] = entry.point
    origin = a.isZero() and b.isZero()
    fill = if origin then '#c62828' else '#1a237e'
    svg.push """<circle cx="#{sx(x).toFixed(2)}" cy="#{sy(y).toFixed(2)}" r="4.5" fill="#{fill}"/>"""

    if showLabels and entry.labeled
      pieces = []
      pieces.push pointAddress(entry.point, options.xOnly) if showAddress
      pieces.push "step #{entry.firstVisit}" if showStep
      label = escapeXml pieces.join ' · '
      ty = if entry.side is 'below' then sy(y) + 32 else sy(y) - 8
      svg.push """<text x="#{(sx(x)+8).toFixed(2)}" y="#{ty.toFixed(2)}" font-size="32" fill="#333">#{label}</text>"""

  # Heading indicator: a short arrow at the turtle's final position,
  # pointing in the direction of the next short step.
  [ax, ay] = toXY(turtle.pos)
  [dx, dy] = toXY(UNIT_DISP[turtle.heading])
  mag = Math.sqrt(dx*dx + dy*dy)
  if mag > 0
    arrowPx = 80
    ux = dx / mag; uy = dy / mag
    x1 = sx(ax); y1 = sy(ay)
    x2 = x1 + ux * arrowPx; y2 = y1 + uy * arrowPx
    svg.push """<line x1="#{x1.toFixed(2)}" y1="#{y1.toFixed(2)}" x2="#{x2.toFixed(2)}" y2="#{y2.toFixed(2)}" stroke="#2e7d32" stroke-width="4" stroke-linecap="round" marker-end="url(#arrow)"/>"""

  unless options.xOnly
    footer = 'basis: e0=(1,0), e72=(cos72°,sin72°) — exact coordinates P(n,p)=n+p·φ'
    svg.push """<text x="12" y="#{(height-4).toFixed(0)}" font-size="32" fill="#666">#{escapeXml footer}</text>"""

  svg.push '</svg>'
  svg.join '\n'

# ---------------- Main ------------------------------------------------------

main = ->
  file = process.argv[2]
  unless file
    console.error 'usage: coffee phiTurtle.coffee <walkfile.txt>'
    process.exit 1

  try
    source = fs.readFileSync file, 'utf8'
    [program, finalPos, options] = parse tokenize(source)
    throw new Error 'internal parser error' unless finalPos >= 0

    turtle = new Turtle
    turtle.run program

    console.log 'step  size   heading  position'
    for item in turtle.trace
      size = item.size.padEnd 5
      heading = String(item.heading).padStart 4
      suffix = if item.pen then '' else '   [pen up]'
      console.log "#{String(item.step).padStart(4)}  #{size}  #{heading}°   (#{item.pos[0]}, #{item.pos[1]})#{suffix}"

    [a, b] = turtle.pos
    if a.isZero() and b.isZero()
      console.log '\nCLOSED: turtle returned to (P(0,0), P(0,0)) exactly.'
    else
      console.log "\nOPEN: turtle rests at (#{a}, #{b})."

    output = path.join path.dirname(file), path.basename(file, path.extname(file)) + '.svg'
    fs.writeFileSync output, render(turtle, options), 'utf8'
    console.log "wrote #{output}"

  catch error
    console.error "phiTurtle: #{error.message}"
    process.exit 1

main()
