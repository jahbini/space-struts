#!/usr/bin/env coffee
# golden-phibase-svg.coffee
#
# Draw one exact golden triangle, then split the remaining golden triangle
# three times. Each split produces one golden gnomon and one smaller
# golden triangle. The figure is generated as SVG with no drawing library.
#
# PhiBase convention:
#   P(n,p) = n + pφ
#
# Run:
#   coffee golden-phibase-svg.coffee > golden-phibase.svg
# or:
#   coffee golden-phibase-svg.coffee golden-phibase.svg

fs = require 'fs'

PHI = (1 + Math.sqrt(5)) / 2
DEPTH = 3
EPS = 1e-9

add = (u, v) -> x: u.x + v.x, y: u.y + v.y
sub = (u, v) -> x: u.x - v.x, y: u.y - v.y
scale = (u, s) -> x: u.x * s, y: u.y * s
mix = (u, v, t) -> add scale(u, 1 - t), scale(v, t)
length = (u, v) ->
  d = sub u, v
  Math.hypot d.x, d.y

near = (a, b, tolerance = 1e-7) ->
  Math.abs(a - b) <= tolerance * Math.max(1, Math.abs(a), Math.abs(b))

assert = (condition, message) ->
  throw new Error "Geometry check failed: #{message}" unless condition

fmt = (x) ->
  value = if Math.abs(x) < EPS then 0 else x
  value.toFixed(3).replace(/\.?0+$/, '')

pointText = (p) -> "#{fmt p.x},#{fmt p.y}"

# Multiplication by φ:
#   P(n,p)φ = P(p,n+p)
mulPhiPair = ([n, p]) -> [p, n + p]

# Division by φ:
#   P(n,p)/φ = P(p-n,n)
divPhiPair = ([n, p]) -> [p - n, n]

phiPowerPair = (power) ->
  pair = [1, 0]
  if power > 0
    pair = mulPhiPair pair for i in [1..power]
  else if power < 0
    pair = divPhiPair pair for i in [1..-power]
  pair

signed = (value) ->
  if value < 0 then "−#{Math.abs value}" else "#{value}"

pairLabel = ([n, p]) -> "P(#{signed n},#{signed p})"

# A golden triangle is represented as:
#   apex: angle 36°
#   left and right: angles 72°
# Its equal sides have length L and its base has length L/φ.
#
# Splitting at the left base angle uses its angle bisector. The cut point
# lies on apex--right and divides that side in the ratio φ:1. The result is
# one golden gnomon and one smaller golden triangle.
splitGolden = (triangle) ->
  {apex, left, right} = triangle

  side1 = length apex, left
  side2 = length apex, right
  base = length left, right

  assert near(side1, side2), 'equal sides are not equal'
  assert near(side1 / base, PHI), 'triangle is not golden'

  # AD:DC = φ:1, so D lies φ/(φ+1) from apex toward right.
  t = PHI / (PHI + 1)
  cut = mix apex, right, t

  gnomon = [apex, left, cut]
  smaller =
    apex: left
    left: right
    right: cut

  newSide1 = length smaller.apex, smaller.left
  newSide2 = length smaller.apex, smaller.right
  newBase = length smaller.left, smaller.right

  assert near(newSide1, newSide2), 'child equal sides are not equal'
  assert near(newSide1 / newBase, PHI), 'child is not golden'
  assert near(newSide1, base), 'child scale is not 1/φ of parent side'

  {gnomon, smaller, cutLine: [left, cut], cut}

polygon = (points, attrs = '') ->
  "<polygon points=\"#{(pointText(p) for p in points).join ' '}\" #{attrs}/>"

lineSvg = (a, b, attrs = '') ->
  "<line x1=\"#{fmt a.x}\" y1=\"#{fmt a.y}\" x2=\"#{fmt b.x}\" y2=\"#{fmt b.y}\" #{attrs}/>"

circleSvg = (p, r = 5, attrs = '') ->
  "<circle cx=\"#{fmt p.x}\" cy=\"#{fmt p.y}\" r=\"#{r}\" #{attrs}/>"

textSvg = (p, text, attrs = '') ->
  "<text x=\"#{fmt p.x}\" y=\"#{fmt p.y}\" #{attrs}>#{text}</text>"

midpoint = (a, b) -> mix a, b, 0.5

WIDTH = 1200
HEIGHT = 820
side = 560
base = side / PHI
halfBase = base / 2
height = Math.sqrt(side * side - halfBase * halfBase)

apex = x: WIDTH / 2, y: 78
left = x: WIDTH / 2 - halfBase, y: 78 + height
right = x: WIDTH / 2 + halfBase, y: 78 + height
root = {apex, left, right}

gnomons = []
cuts = []
points = [apex, left, right]
current = root

for level in [1..DEPTH]
  result = splitGolden current
  gnomons.push result.gnomon
  cuts.push level: level, a: result.cutLine[0], b: result.cutLine[1]
  points.push result.cut
  current = result.smaller

fills = ['#e7f2d0', '#dcebd3', '#d3e5d9']
parts = []

parts.push "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"#{WIDTH}\" height=\"#{HEIGHT}\" viewBox=\"0 0 #{WIDTH} #{HEIGHT}\" role=\"img\" aria-labelledby=\"title desc\">"
parts.push '<title id="title">Golden triangle recursively divided into golden gnomons and golden triangles</title>'
parts.push '<desc id="desc">An exact golden triangle is divided three times. Each cut creates one golden gnomon and one smaller golden triangle. Cut lengths are labelled with PhiBase pairs.</desc>'
parts.push '<style>.outline{fill:none;stroke:#111;stroke-width:3;stroke-linejoin:round}.cut{stroke:#333;stroke-width:2.4}.point{fill:#fff;stroke:#111;stroke-width:2}.label{font-family:Georgia,serif;font-size:21px;fill:#111}.small{font-family:Georgia,serif;font-size:17px;fill:#222}.title{font-family:Georgia,serif;font-size:29px;font-weight:700;fill:#111}</style>'
parts.push '<rect width="100%" height="100%" fill="white"/>'
parts.push textSvg {x: WIDTH / 2, y: 40}, 'Golden Triangle: Three Exact PhiBase Subdivisions', 'class="title" text-anchor="middle"'

for gnomon, i in gnomons
  parts.push polygon gnomon, "fill=\"#{fills[i % fills.length]}\" stroke=\"none\""

parts.push polygon [current.apex, current.left, current.right], 'fill="#f5d98b" stroke="none"'
parts.push polygon [apex, left, right], 'class="outline"'

for cut in cuts
  parts.push lineSvg cut.a, cut.b, 'class="cut"'

for p in points
  parts.push circleSvg p, 5, 'class="point"'

parts.push textSvg midpoint(apex, left), 'φ', 'class="label" text-anchor="end" dx="-12" dy="-4"'
parts.push textSvg midpoint(left, right), '1 = P(1,0)', 'class="label" text-anchor="middle" dy="34"'

for cut in cuts
  power = -(cut.level - 1)
  m = midpoint cut.a, cut.b
  pair = phiPowerPair power
  exponentText = switch power
    when 0 then '1'
    when -1 then 'φ⁻¹'
    when -2 then 'φ⁻²'
    else "φ^#{power}"
  label = "#{exponentText} = #{pairLabel pair}"
  parts.push textSvg m, label, 'class="small" text-anchor="middle" dy="-10" paint-order="stroke" stroke="white" stroke-width="5" stroke-linejoin="round"'

parts.push textSvg {x: 60, y: HEIGHT - 66}, 'Each cut leaves one golden gnomon and one smaller golden triangle. The cut lengths descend on the same Fibonacci spine: P(1,0), P(−1,1), P(2,−1), …', 'class="small"'
parts.push '</svg>'

svg = parts.join "\n"
outputPath = process.argv[2]

if outputPath?
  fs.writeFileSync outputPath, svg, 'utf8'
  console.error "Wrote #{outputPath}"
else
  process.stdout.write svg
