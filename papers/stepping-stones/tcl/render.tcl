# render.tcl — SVG output for the 3D TCL turtle.
#
# Segments and vertices accumulated in ::turtle are projected via the
# exact geoPhi cartesian3Phi map to 3D Cartesian (Q(φ)), converted to
# floats (numerical only from here), projected to 2D by isometric view
# along +(1,1,1)/√3, and emitted as SVG.
#
# The turtle walk can force a different view with `viewaxis <name>`:
#   iso   — isometric along (1,1,1) (default)
#   A..F  — orthographic along +bX (face-on view of face X+)
# For book figures with a single planar face, use viewaxis A (etc.).

namespace eval ::render {
    variable view "iso"
}

# ---- cartesian3Phi: SixPhi -> 3D Cartesian floats -------------------------
# Matches geoPhi.coffee's cartesian3Phi (line 317). sr = 2*phi + 4.
proc ::render::cartesian3Phi {sixvec} {
    lassign $sixvec pA pB pC pD pE pF
    set phi [::pb::phi]
    # x = e - f + phi * (a + b)
    set x  [::pb::add [::pb::sub $pE $pF] [::pb::mul $phi [::pb::add $pA $pB]]]
    # y = c - d + phi * (e + f)
    set y  [::pb::add [::pb::sub $pC $pD] [::pb::mul $phi [::pb::add $pE $pF]]]
    # z = a - b + phi * (c + d)
    set z  [::pb::add [::pb::sub $pA $pB] [::pb::mul $phi [::pb::add $pC $pD]]]
    set sr [expr {2.0 * 1.6180339887498949 + 4.0}]
    list [expr {[::pb::toFloat $x] / $sr}] \
         [expr {[::pb::toFloat $y] / $sr}] \
         [expr {[::pb::toFloat $z] / $sr}]
}

# ---- 3D -> 2D projection --------------------------------------------------
# Returns {u v} with SVG-style axes (v grows down).
proc ::render::project {xyz} {
    variable view
    lassign $xyz x y z
    switch $view {
        iso {
            # Isometric along (1,1,1)/sqrt(3).
            #   u = (x - y) / sqrt(2)
            #   v = (2z - x - y) / sqrt(6)   (flip so +z is up on screen)
            set u [expr {($x - $y) / 1.4142135623730951}]
            set v [expr {(2.0 * $z - $x - $y) / 2.449489742783178}]
        }
        A {
            # Face-on view of face A+ (normal b_A = (phi,1,0)/|A|).
            # In-plane basis: u along (1,-phi,0)/|A|, v along +z (SVG-flipped).
            set nA [expr {sqrt(1.6180339887498949**2 + 1.0)}]
            set u [expr {($x - 1.6180339887498949 * $y) / $nA}]
            set v $z
        }
        default {
            # Fallback: drop z.
            set u $x
            set v $y
        }
    }
    list $u [expr {-$v}]
}

# ---- viewaxis command exposed to walks ------------------------------------
proc viewaxis {name} {
    switch $name {
        iso - A { set ::render::view $name }
        default { error "viewaxis: unknown view '$name'" }
    }
}

# ---- SVG emission ---------------------------------------------------------
# `svg <outfile>` builds an SVG string from turtle state and hands it to the
# master interpreter via the `write_svg` alias (safe interp cannot open).
proc svg {outfile} {
    set segs $::turtle::segments
    set pts {}
    array unset vseen
    foreach seg $segs {
        lassign $seg from to size
        foreach p [list $from $to] {
            set k [join $p ,]
            if {![info exists vseen($k)]} {
                set vseen($k) [::render::project [::render::cartesian3Phi $p]]
                lappend pts $vseen($k)
            }
        }
    }
    if {[llength $pts] == 0} {
        set vseen(origin) [::render::project [::render::cartesian3Phi $::turtle::home_pos]]
        lappend pts $vseen(origin)
    }
    set xs {}; set ys {}
    foreach p $pts { lappend xs [lindex $p 0]; lappend ys [lindex $p 1] }
    set minX [::render::_min $xs]; set maxX [::render::_max $xs]
    set minY [::render::_min $ys]; set maxY [::render::_max $ys]
    set pad   0.25
    set scale 300.0
    set w [expr {($maxX - $minX + 2 * $pad) * $scale}]
    set h [expr {($maxY - $minY + 2 * $pad) * $scale}]

    set lines {}
    lappend lines "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 [format {%.0f} $w] [format {%.0f} $h]\" font-family=\"monospace\">"
    lappend lines "<rect width=\"100%\" height=\"100%\" fill=\"white\"/>"
    foreach seg $segs {
        lassign $seg from to size
        set fp [::render::project [::render::cartesian3Phi $from]]
        set tp [::render::project [::render::cartesian3Phi $to]]
        lassign [::render::_sx $fp $minX $minY $pad $scale] fx fy
        lassign [::render::_sx $tp $minX $minY $pad $scale] tx ty
        if {$size eq "long"} {
            set stroke "#8e3b1f"; set sw 3.5
        } else {
            set stroke "#1a237e"; set sw 2.5
        }
        lappend lines "<line x1=\"[format {%.2f} $fx]\" y1=\"[format {%.2f} $fy]\" x2=\"[format {%.2f} $tx]\" y2=\"[format {%.2f} $ty]\" stroke=\"$stroke\" stroke-width=\"$sw\" stroke-linecap=\"round\"/>"
    }
    foreach {k pt} [array get vseen] {
        lassign [::render::_sx $pt $minX $minY $pad $scale] cx cy
        lappend lines "<circle cx=\"[format {%.2f} $cx]\" cy=\"[format {%.2f} $cy]\" r=\"4\" fill=\"#1a237e\"/>"
    }
    lappend lines "</svg>"
    write_svg $outfile [join $lines "\n"]
    ::turtle::_trace "svg $outfile"
}

proc ::render::_min {xs} { set m [lindex $xs 0]; foreach x $xs { if {$x < $m} {set m $x} }; return $m }
proc ::render::_max {xs} { set m [lindex $xs 0]; foreach x $xs { if {$x > $m} {set m $x} }; return $m }
proc ::render::_sx {p minX minY pad scale} {
    lassign $p x y
    list [expr {($x - $minX + $pad) * $scale}] [expr {($y - $minY + $pad) * $scale}]
}
