# robinson.coffee
#
# L3 of the WFC stack: tile types as runtime objects (Vertex, Edge, Piece)
# plus a loader for `robinsonPieces.json`.
#
# Positions are exact PhiPoint2D (a, b) in the (e₀, e₇₂) basis — see
# phiPoint2D.coffee. All identity / equality decisions go through
# `PhiPoint2D.equals`; no epsilons here. Float is reserved for SVG render
# via `PhiPoint2D.toCartesian()`.

import { PhiBase } from '$lib/coffee/phiBase.coffee'
import { PhiPoint2D, getUnitDisp, getLongDisp, classifyDisplacement } from './phiPoint2D.coffee'

PB_ONE_LOCAL = new PhiBase(0, 1)

state = null

export init = ->
  return if state?
  raw = await (await fetch('/wfc/robinsonPieces.json')).json()
  templates = {}
  for kind, def of raw
    continue if kind.startsWith('_')
    templates[kind] =
      kind: kind
      name: def.name
      vertexAngles: (v.angle_deg for v in def.vertices)        # [36, 72, 72] or [108, 36, 36]
      vertexLabels: (v.label for v in def.vertices)            # ['A', 'B', 'C']
      edgeLengths: (e.length.slice() for e in def.edges)       # [[n,p], ...] in PhiBase
  state = { templates }
  null

ensure = ->
  throw new Error('robinson: init() not yet awaited') unless state?

export getTemplate = (kind) ->
  ensure()
  state.templates[kind] ? null

export pieceKinds = ->
  ensure()
  (k for k of state.templates)

# --- Vertex --------------------------------------------------------------
# pos: PhiPoint2D (exact).
# word: cyclic angle sequence in degrees (integers), in order of attachment.
# status: 'open' | 'closed' (Assembly sets 'closed' when word sums to 360).
export class Vertex
  constructor: (@pos) ->
    @word = []
    @status = 'open'

  equals: (other) -> @pos.equals(other.pos)

# --- Edge ----------------------------------------------------------------
# v0, v1: endpoint Vertex refs.
# scale: integer φ-power tag (0 for this prototype — single scale only).
# dir: integer 0..9 — direction k of the displacement v0 → v1 in 36° units.
# kind: 'short' (length 1) or 'long' (length φ).
# left, right: Piece refs on each CCW side; null when that side is open.
export class Edge
  constructor: (@v0, @v1, @dir, @kind, @scale = 0) ->
    @left = null
    @right = null

  isOpen: -> not @left? or not @right?

  # Midpoint as PhiPoint2D — exact, useful only for heuristics that don't
  # affect legality (e.g. "is this edge near the canvas boundary").
  midpoint: ->
    new PhiPoint2D(
      @v0.pos.a.add(@v1.pos.a).div(new PhiBase(0, 2))
      @v0.pos.b.add(@v1.pos.b).div(new PhiBase(0, 2))
    )

# --- Piece ---------------------------------------------------------------
# kind: 'T' | 'G'.
# verts: [Vertex, Vertex, Vertex] in CCW order, verts[0] = apex.
# edges: [Edge, Edge, Edge]; edges[i] connects verts[i] → verts[(i+1) % 3].
export class Piece
  constructor: (@kind, @verts, @edges) ->
    template = getTemplate(@kind)
    throw new Error("unknown piece kind: #{@kind}") unless template?
    if @verts.length != 3 or @edges.length != 3
      throw new Error("Piece must have exactly 3 verts and 3 edges")
    @template = template

  angleAt: (v) ->
    for vert, i in @verts
      return @template.vertexAngles[i] if vert == v
    null

# --- Seed factory --------------------------------------------------------
# Build a single oriented piece of `kind` with its first edge along the
# direction `dir36k` (k × 36°, default k=0 = +x). The piece sits CCW from
# that edge. Vertex positions are EXACT (PhiPoint2D, all in Z[φ]).
#
# For T: A at origin, B at A + LONG_DISP[k]  (since edge A→B = φ),
#         C at A + LONG_DISP[k+1] (angle at A = 36° → C is one 36° step CCW
#         from the edge direction; length A→C also = φ).
# For G: A at origin, B at A + UNIT_DISP[k] (edge A→B = 1),
#         C at A + UNIT_DISP[k+3] (angle at A = 108° → C is three 36° steps
#         CCW; length A→C = 1).
export buildSeed = (kind, dir36k = 0, tileScale = PB_ONE_LOCAL) ->
  ensure()
  template = state.templates[kind]
  throw new Error("unknown kind: #{kind}") unless template?

  origin = PhiPoint2D.ZERO
  short = (k) -> getUnitDisp(k).scale(tileScale)
  long  = (k) -> getLongDisp(k).scale(tileScale)

  if kind == 'T'
    posA = origin
    posB = origin.add(long(dir36k))
    posC = origin.add(long(dir36k + 1))
  else if kind == 'G'
    posA = origin
    posB = origin.add(short(dir36k))
    posC = origin.add(short(dir36k + 3))
  else
    throw new Error("unknown kind: #{kind}")

  v0 = new Vertex(posA)
  v1 = new Vertex(posB)
  v2 = new Vertex(posC)

  # Recompute edge directions from actual displacements (the classifier
  # uses the same tileScale so the tables match).
  e01 = makeEdge(v0, v1, 0, tileScale)
  e12 = makeEdge(v1, v2, 0, tileScale)
  e20 = makeEdge(v2, v0, 0, tileScale)

  piece = new Piece(kind, [v0, v1, v2], [e01, e12, e20])
  for v, i in piece.verts
    v.word.push template.vertexAngles[i]
  e01.left = piece
  e12.left = piece
  e20.left = piece
  piece

# Helper: build an Edge with direction/kind classified from the actual
# vertex displacements. Throws if the displacement isn't one of our 20
# known unit-or-long vectors at the given tileScale.
export makeEdge = (v0, v1, scale = 0, tileScale = PB_ONE_LOCAL) ->
  disp = v1.pos.sub(v0.pos)
  c = classifyDisplacement(disp, tileScale)
  unless c?
    throw new Error("makeEdge: displacement not a known 36k° unit/long step at tileScale #{tileScale.toString()}: #{disp.toString()}")
  new Edge(v0, v1, c.dir, c.len, scale)
