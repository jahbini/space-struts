# phiShells.coffee
#
# Radial-shell quantization for the robot build.
#
# Each vertex in the golden-triangle hull around the teapot is snapped to a
# discrete radial shell phi^k for some integer k, chosen as the SMALLEST k such
# that phi^k >= r_teapot(direction). This guarantees the hull strictly encloses
# the teapot in every direction the robot reaches.
#
# Exports:
#   PHI                   - golden ratio
#   SHELLS                - sorted array of {k, r} from phi^-4 up through phi^6
#   phiShellFor(dir, teapotRadialDistance)
#                         - returns {k, r, rTeapot} for a unit direction; if the
#                           ray misses the mesh, returns null
#   shellEnclosing(rTeapot)
#                         - same as phiShellFor but takes a raw radius (used
#                           by tests and by callers that already have r)

PHI = (1 + Math.sqrt(5)) / 2

SHELLS = ({ k, r: Math.pow(PHI, k) } for k in [-4..6])

export { PHI, SHELLS }

# Given a teapot-surface radius r (along some direction), return the smallest
# shell with shell.r >= r. Falls back to the outermost shell if r exceeds it.
export shellEnclosing = (r) ->
  for shell in SHELLS
    return shell if shell.r >= r
  SHELLS[SHELLS.length - 1]

# Convenience: ray-cast through the mesh and pick the enclosing shell.
# radialDistance is injected so this module stays decoupled from any
# specific mesh (lets tests substitute a stub; production callers pass
# the relevant mesh's radialDistance — e.g. the one in
# src/routes/explore/hull/teapotMesh.coffee).
export phiShellFor = (dir, radialDistance) ->
  r = radialDistance(dir)
  return null unless r?
  shell = shellEnclosing(r)
  { k: shell.k, r: shell.r, rTeapot: r }
