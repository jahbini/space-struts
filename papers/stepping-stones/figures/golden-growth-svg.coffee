#!/usr/bin/env coffee
# golden-growth-svg.coffee
# Generates an outward-growth reference figure:
# golden triangle -> golden gnomon -> golden triangle -> golden gnomon
#
# Positive PhiBase spine:
# P(1,0), P(0,1), P(1,1), P(1,2)
#
# Run:
#   coffee golden-growth-svg.coffee > golden-growth.svg
# or:
#   coffee golden-growth-svg.coffee golden-growth.svg

fs = require 'fs'

PHI = (1 + Math.sqrt(5)) / 2
WIDTH = 1500
HEIGHT = 720
BASELINE = 470

fmt = (x) -> x.toFixed(3).replace(/\.?0+$/, '')
pointText = (p) -> "#{fmt p.x},#{fmt p.y}"

polygon = (points, attrs = '') ->
  "<polygon points=\"#{(pointText(p) for p in points).join ' '}\" #{attrs}/>"

lineSvg = (a, b, attrs = '') ->
  "<line x1=\"#{fmt a.x}\" y1=\"#{fmt a.y}\" x2=\"#{fmt b.x}\" y2=\"#{fmt b.y}\" #{attrs}/>"

textSvg = (p, value, attrs = '') ->
  "<text x=\"#{fmt p.x}\" y=\"#{fmt p.y}\" #{attrs}>#{value}</text>"

isosceles = (cx, baseline, equalSide, apexDegrees) ->
  half = apexDegrees * Math.PI / 360
  halfBase = equalSide * Math.sin half
  height = equalSide * Math.cos half
  [
    {x: cx, y: baseline - height}
    {x: cx - halfBase, y: baseline}
    {x: cx + halfBase, y: baseline}
  ]

mulPhi = ([n, p]) -> [p, n + p]
pairText = ([n, p]) -> "P(#{n},#{p})"

pairs = [[1,0]]
pairs.push mulPhi(pairs[pairs.length - 1]) for i in [1..3]

stages = [
  {kind: 'Golden triangle', angles: '36°–72°–72°', apex: 36, fill: '#f4d88a'}
  {kind: 'Golden gnomon', angles: '108°–36°–36°', apex: 108, fill: '#dcecc9'}
  {kind: 'Golden triangle', angles: '36°–72°–72°', apex: 36, fill: '#f4d88a'}
  {kind: 'Golden gnomon', angles: '108°–36°–36°', apex: 108, fill: '#dcecc9'}
]

centers = [150, 445, 810, 1240]
baseSide = 92
displayExponent = 0.82

parts = []
parts.push "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"#{WIDTH}\" height=\"#{HEIGHT}\" viewBox=\"0 0 #{WIDTH} #{HEIGHT}\">"
parts.push '''
<style>
.shape{stroke:#111;stroke-width:3;stroke-linejoin:round}
.arrow{stroke:#111;stroke-width:2.5;fill:none;marker-end:url(#arrowhead)}
.title{font-family:Georgia,"Times New Roman",serif;font-size:31px;font-weight:700;fill:#111}
.subtitle{font-family:Georgia,"Times New Roman",serif;font-size:20px;fill:#222}
.label{font-family:Georgia,"Times New Roman",serif;font-size:21px;font-weight:700;fill:#111}
.small{font-family:Georgia,"Times New Roman",serif;font-size:17px;fill:#222}
.phi{font-family:Georgia,"Times New Roman",serif;font-size:23px;font-style:italic;fill:#111}
</style>
<defs>
<marker id="arrowhead" markerWidth="10" markerHeight="7" refX="9" refY="3.5" orient="auto">
<polygon points="0 0,10 3.5,0 7" fill="#111"/>
</marker>
</defs>
'''
parts.push '<rect width="100%" height="100%" fill="white"/>'
parts.push textSvg({x: WIDTH/2, y: 46}, 'Growing Outward on the Positive PhiBase Spine', 'class="title" text-anchor="middle"')
parts.push textSvg({x: WIDTH/2, y: 82}, 'Begin with one small golden triangle. Each step enlarges the tracked length by φ.', 'class="subtitle" text-anchor="middle"')

drawn = []

for stage, i in stages
  realScale = Math.pow PHI, i
  displaySide = baseSide * Math.pow(realScale, displayExponent)
  pts = isosceles centers[i], BASELINE, displaySide, stage.apex
  drawn.push pts

  parts.push polygon pts, "class=\"shape\" fill=\"#{stage.fill}\""

  if stage.apex is 36
    parts.push lineSvg pts[0], pts[2], 'stroke="#174ea6" stroke-width="6"'
  else
    parts.push lineSvg pts[1], pts[2], 'stroke="#174ea6" stroke-width="6"'

  parts.push textSvg({x: centers[i], y: BASELINE + 42}, stage.kind, 'class="label" text-anchor="middle"')
  parts.push textSvg({x: centers[i], y: BASELINE + 68}, stage.angles, 'class="small" text-anchor="middle"')

  phiPower = ['1','φ','φ²','φ³'][i]
  parts.push textSvg({x: centers[i], y: BASELINE + 105}, "#{phiPower} = #{pairText pairs[i]}", 'class="phi" text-anchor="middle"')

for i in [0..2]
  aRight = Math.max (p.x for p in drawn[i])...
  bLeft = Math.min (p.x for p in drawn[i + 1])...
  y = 240
  parts.push lineSvg({x: aRight + 22, y}, {x: bLeft - 22, y}, 'class="arrow"')
  parts.push textSvg({x: (aRight + bLeft)/2, y: y - 15}, '× φ', 'class="phi" text-anchor="middle"')

stripY = 650
parts.push lineSvg({x: 190, y: stripY}, {x: 1310, y: stripY}, 'stroke="#174ea6" stroke-width="3"')
for pair, i in pairs
  x = 245 + i * 335
  parts.push "<circle cx=\"#{x}\" cy=\"#{stripY}\" r=\"7\" fill=\"#174ea6\"/>"
  parts.push textSvg({x, y: stripY - 18}, pairText(pair), 'class="small" text-anchor="middle"')

parts.push textSvg({x: WIDTH/2, y: 705}, 'The same growth rule carries the construction upward through positive PhiBase quantities.', 'class="subtitle" text-anchor="middle"')
parts.push '</svg>'

svg = parts.join "\n"
outputPath = process.argv[2]

if outputPath?
  fs.writeFileSync outputPath, svg, 'utf8'
  console.error "Wrote #{outputPath}"
else
  process.stdout.write svg
