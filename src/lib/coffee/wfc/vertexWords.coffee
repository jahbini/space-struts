# vertexWords.coffee
#
# L2 of the WFC stack: legal vertex angle multisets. A 2D Robinson tiling
# has every interior vertex's angles summing to exactly 360°. The JSON
# enumerates the 12 multisets (sorted descending) admitted by the
# constraint p + 2q + 3r = 10 (with p = #36, q = #72, r = #108).
#
# This prototype uses multiset legality only — cyclic order is ignored,
# which admits non-Penrose periodic patches (e.g. all-T or all-G). The
# strict Penrose cyclic words can replace each multiset later.
#
# Loading: call `await init()` once before any predicate call. Same async
# init pattern as anglePalette.coffee.
#
# Word convention: a "word" is an array of angle degrees (integers), in the
# order they were attached to the vertex. The predicates sort descending
# internally; cyclic order doesn't matter.

state = null   # { entries: [[deg, deg, ...], ...] }

export init = ->
  return if state?
  raw = await (await fetch('/wfc/vertexWords.json')).json()
  # Each entry is already sorted descending in the JSON; copy defensively.
  entries = (m.slice().sort((a, b) -> b - a) for m in raw.closed_vertex_multisets)
  state = { entries }
  null

ensure = ->
  throw new Error('vertexWords: init() not yet awaited') unless state?

sumAll = (xs) ->
  s = 0
  s += x for x in xs
  s

sortDesc = (xs) -> xs.slice().sort((a, b) -> b - a)

# Returns true if `sorted` (sorted desc) is a prefix of `target` (also
# sorted desc) — meaning the first `sorted.length` entries match element-
# wise.
isPrefixOf = (sorted, target) ->
  return false if sorted.length > target.length
  for i in [0...sorted.length]
    return false if sorted[i] != target[i]
  true

# A word is a legal PREFIX iff there exists at least one closed multiset
# entry such that the word's sorted-desc form is a prefix of that entry,
# AND the running sum does not exceed 360°. The empty word is always legal.
export isLegalPrefix = (word) ->
  ensure()
  s = sumAll(word)
  return false if s > 360
  return true if word.length == 0
  sorted = sortDesc(word)
  for entry in state.entries
    return true if isPrefixOf(sorted, entry)
  false

# A word is CLOSED iff its sorted-desc form exactly matches a closed
# multiset entry AND the running sum equals 360°.
export isClosed = (word) ->
  ensure()
  return false if sumAll(word) != 360
  sorted = sortDesc(word)
  for entry in state.entries
    continue if entry.length != sorted.length
    match = true
    for i in [0...sorted.length]
      if sorted[i] != entry[i]
        match = false
        break
    return true if match
  false

# Diagnostic: returns the full list of legal closed multisets (copies, so
# callers can't mutate the internal table).
export getClosedMultisets = ->
  ensure()
  (e.slice() for e in state.entries)
