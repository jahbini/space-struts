# render.tcl — 2D SVG output for the HafBase turtle.
#
# ::render::toXY maps a pair (a, b) to Cartesian (x, y) using the basis
#   e0  = (1, 0)
#   e72 = (cos 72°, sin 72°)
# with y flipped (SVG grows downward). All sizes scale by φ^scalePhi so
# that bumping `scalephi` grows the figure uniformly, keeping label size
# and stroke width proportional to the segment length.

namespace eval ::render {}

proc ::render::toXY {p} {
    lassign $p a b
    set phi   1.6180339887498949
    set cos72 [expr {($phi - 1) / 2.0}]
    set sin72 [expr {sqrt(1.0 - $cos72 * $cos72)}]
    set af [::pb::toFloat $a]
    set bf [::pb::toFloat $b]
    set x [expr {$af + $bf * $cos72}]
    set y [expr {$bf * $sin72}]
    list $x [expr {-$y}]
}

proc ::render::_min {xs} { set m [lindex $xs 0]; foreach x $xs { if {$x < $m} {set m $x} }; return $m }
proc ::render::_max {xs} { set m [lindex $xs 0]; foreach x $xs { if {$x > $m} {set m $x} }; return $m }

# `svg <outfile>` — build SVG string from accumulated turtle state and hand
# to the master interp via `write_svg` (safe interp cannot open files).
proc svg {outfile} {
    set phi     1.6180339887498949
    set s       [expr {pow($phi, $::turtle::scalePhi)}]
    set fontSize [expr {round(15.0 * $s)}]
    set offAbove [expr {2.0 * $s}]
    set offBelow $fontSize
    set offRight [expr {2.0 * $s}]
    set arrowPx  [expr {19.0 * $s}]
    set arrowSW  [expr {1.0 * $s}]
    set vertR    [expr {1.1 * $s}]
    set strokeSh [expr {0.6 * $s}]
    set strokeLg [expr {0.85 * $s}]
    set footerSz [expr {round(8.0 * $s)}]

    # Collect projected points for bounding box.
    set pts {}
    dict for {k entry} $::turtle::vertices {
        set xy [::render::toXY [dict get $entry pt]]
        lappend pts $xy
    }
    if {[llength $pts] == 0} {
        lappend pts [::render::toXY $::turtle::home_pos]
    }
    set xs {}; set ys {}
    foreach p $pts { lappend xs [lindex $p 0]; lappend ys [lindex $p 1] }
    set minX [::render::_min $xs]; set maxX [::render::_max $xs]
    set minY [::render::_min $ys]; set maxY [::render::_max $ys]
    set pad   1.2
    set scale 130.0
    set w [expr {($maxX - $minX + 2 * $pad) * $scale}]
    set h [expr {($maxY - $minY + 2 * $pad) * $scale}]

    set sx_of {}   ;# closure-ish; we recompute inline

    set lines {}
    lappend lines "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 [format {%.0f} $w] [format {%.0f} $h]\" font-family=\"monospace\">"
    lappend lines "<defs><marker id=\"arrow\" viewBox=\"0 0 10 10\" refX=\"9\" refY=\"5\" markerWidth=\"6\" markerHeight=\"6\" orient=\"auto-start-reverse\"><path d=\"M0,0 L10,5 L0,10 z\" fill=\"#2e7d32\"/></marker></defs>"
    lappend lines "<rect width=\"100%\" height=\"100%\" fill=\"white\"/>"

    # Segments
    foreach seg $::turtle::segments {
        lassign $seg from to size
        lassign [::render::toXY $from] fx fy
        lassign [::render::toXY $to]   tx ty
        set fx [expr {($fx - $minX + $pad) * $scale}]
        set fy [expr {($fy - $minY + $pad) * $scale}]
        set tx [expr {($tx - $minX + $pad) * $scale}]
        set ty [expr {($ty - $minY + $pad) * $scale}]
        if {$size eq "long"} {
            set stroke "#8e3b1f"; set sw $strokeLg
        } else {
            set stroke "#1a237e"; set sw $strokeSh
        }
        lappend lines "<line x1=\"[format {%.2f} $fx]\" y1=\"[format {%.2f} $fy]\" x2=\"[format {%.2f} $tx]\" y2=\"[format {%.2f} $ty]\" stroke=\"$stroke\" stroke-width=\"[format {%.2f} $sw]\" stroke-linecap=\"round\"/>"
    }

    # Vertex dots + optional labels
    dict for {k entry} $::turtle::vertices {
        set pt      [dict get $entry pt]
        set labeled [dict get $entry labeled]
        set side    [dict get $entry side]
        lassign [::render::toXY $pt] x y
        set x [expr {($x - $minX + $pad) * $scale}]
        set y [expr {($y - $minY + $pad) * $scale}]
        set origin [::pair::equals $pt $::turtle::home_pos]
        set fill [expr {$origin ? "#c62828" : "#1a237e"}]
        lappend lines "<circle cx=\"[format {%.2f} $x]\" cy=\"[format {%.2f} $y]\" r=\"[format {%.2f} $vertR]\" fill=\"$fill\"/>"
        if {$labeled} {
            lassign $pt a b
            if {$::turtle::xonly} {
                set text [::pb::toString $a]
            } else {
                set text "([::pb::toString $a],[::pb::toString $b])"
            }
            if {$side eq "below"} {
                set ty [expr {$y + $offBelow}]
            } else {
                set ty [expr {$y - $offAbove}]
            }
            lappend lines "<text x=\"[format {%.2f} [expr {$x + $offRight}]]\" y=\"[format {%.2f} $ty]\" font-size=\"$fontSize\" fill=\"#333\">$text</text>"
        }
    }

    # Heading-indicator arrow at final position.
    lassign [::render::toXY $::turtle::pos] ax ay
    set ax [expr {($ax - $minX + $pad) * $scale}]
    set ay [expr {($ay - $minY + $pad) * $scale}]
    lassign [::render::toXY [lindex $::disp::UNIT $::turtle::heading]] dx dy
    set mag [expr {sqrt($dx * $dx + $dy * $dy)}]
    if {$mag > 0} {
        set ux [expr {$dx / $mag}]
        set uy [expr {$dy / $mag}]
        set bx [expr {$ax + $ux * $arrowPx}]
        set by [expr {$ay + $uy * $arrowPx}]
        lappend lines "<line x1=\"[format {%.2f} $ax]\" y1=\"[format {%.2f} $ay]\" x2=\"[format {%.2f} $bx]\" y2=\"[format {%.2f} $by]\" stroke=\"#2e7d32\" stroke-width=\"[format {%.2f} $arrowSW]\" stroke-linecap=\"round\" marker-end=\"url(#arrow)\"/>"
    }

    lappend lines "<text x=\"12\" y=\"[format {%.0f} [expr {$h - 4}]]\" font-size=\"$footerSz\" fill=\"#666\">basis: e0=(1,0), e72=(cos72°,sin72°) — heading in 36° steps, exact pair (a,b) with a,b in Z\[φ\]</text>"
    lappend lines "</svg>"

    write_svg $outfile [join $lines "\n"]
    ::turtle::_trace "svg $outfile"
}
