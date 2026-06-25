# anglePalette.coffee
#
# L1 of the WFC stack: the angle palette. cos(angle) is stored as an exact
# rational over Z[phi] — no floats anywhere in this module.
#
# Loading: call `await init()` once before any cosOf() call. The Svelte page
# does this from its onMount; this module does not perform top-level fetch
# so it can be imported synchronously by other modules that don't need the
# data at import time.
#
# JSON convention vs. project convention:
#   JSON     "cos": { "num": [n, p], "den": d }   means (n + p*phi) / d
#   Project  new PhiBase(p, n)                    means (p*phi + n)
# We swap the JSON's [n, p] order on the way in. We DO NOT fold the
# denominator into the PhiBase — the return shape is {num: PhiBase, den: int}
# mirroring the JSON.

import { PhiBase } from '$lib/coffee/phiBase.coffee'

state = null   # { cosTable, robinson2DAngles, paletteAngles }

export init = ->
  return if state?
  raw = await (await fetch('/wfc/anglePalette.json')).json()
  cosTable = {}
  for angleStr, entry of raw.angles
    continue if angleStr.startsWith('_')
    [n, p] = entry.cos.num
    den = entry.cos.den
    cosTable[angleStr] = { num: new PhiBase(p, n), den: den }
  state =
    cosTable: cosTable
    robinson2DAngles: (Number(a) for a in raw._robinson_2d_subset)
    paletteAngles: (Number(k) for k of cosTable)
  null

ensure = ->
  throw new Error('anglePalette: init() not yet awaited') unless state?

# cosOf(angleDeg): exact cos as { num: PhiBase, den: int }; null if the
# angle isn't in the palette. Accepts number or numeric string.
export cosOf = (angleDeg) ->
  ensure()
  state.cosTable[String(angleDeg)] ? null

# Robinson 2D subset (per the JSON's _robinson_2d_subset hint).
export getRobinson2DAngles = ->
  ensure()
  state.robinson2DAngles.slice()

# All angles in the palette. Useful for diagnostics / iteration.
export getPaletteAngles = ->
  ensure()
  state.paletteAngles.slice()
