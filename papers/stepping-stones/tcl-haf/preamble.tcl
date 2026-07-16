# preamble.tcl — HafBase turtle vocabulary.
#
# Matches phiTurtle.coffee's command set:
#   short / long / back / pendown / penup
#   left k / right k    (turns of k · 36°, defaults to k=1)
#   repeat n { body }   (see run.tcl for [ ] -> { } translation)
#   mark <name> / goto <name>
#   gsave / grestore    (turtle state; marks and drawings are global)
#   label / above / below / scalephi n / xonly
#   home                (reset to origin, heading 0)
#
# What the coffee turtle has that this port intentionally omits for now:
#   arrow-marker heading indicator (easy to add if wanted).
#   The 36° "wall" of the icosahedral turtle does not apply here — every
#   integer multiple of 36° is a legal turn.

namespace eval ::turtle {
    variable pos
    variable heading    0     ;# 0..9, units of 36°
    variable pen        1
    variable xonly      0
    variable scalePhi   3     ;# rendered length multiplier is φ^scalePhi
    variable labelSide  "above"
    variable marks
    variable stack
    variable trace_lines
    variable segments         ;# list of {from to size}  size in {short,long}
    variable vertices         ;# dict key -> {pt labeled side}
    array set marks {}
    set stack {}
    set trace_lines {}
    set segments {}
    set vertices [dict create]

    variable home_pos [::pair::zero]
    set pos $home_pos
}

# ---- helpers -------------------------------------------------------------
proc ::turtle::_trace {msg} {
    variable trace_lines
    lappend trace_lines $msg
}

proc ::turtle::_key {pt} {
    lassign $pt a b
    lassign $a ap an ad
    lassign $b bp bn bd
    return "$ap,$an,$ad;$bp,$bn,$bd"
}

# Ensure the current position is registered as a vertex; set/refresh side.
proc ::turtle::_mark_vertex {pt} {
    variable vertices
    variable labelSide
    set k [_key $pt]
    if {[dict exists $vertices $k]} {
        set entry [dict get $vertices $k]
        dict set entry side $labelSide
        dict set vertices $k $entry
    } else {
        dict set vertices $k [dict create pt $pt labeled 0 side $labelSide]
    }
}

proc ::turtle::_record_seg {from to size} {
    variable pen
    variable segments
    variable vertices
    _mark_vertex $from
    _mark_vertex $to
    if {$pen} { lappend segments [list $from $to $size] }
}

# ---- pen -----------------------------------------------------------------
proc pendown {} { set ::turtle::pen 1; ::turtle::_trace "pendown" }
proc penup   {} { set ::turtle::pen 0; ::turtle::_trace "penup" }

# ---- steps ---------------------------------------------------------------
proc short {} {
    set d [lindex $::disp::UNIT $::turtle::heading]
    set from $::turtle::pos
    set to [::pair::add $from $d]
    ::turtle::_record_seg $from $to short
    set ::turtle::pos $to
    ::turtle::_trace "short"
}
proc long {} {
    set d [lindex $::disp::LONG $::turtle::heading]
    set from $::turtle::pos
    set to [::pair::add $from $d]
    ::turtle::_record_seg $from $to long
    set ::turtle::pos $to
    ::turtle::_trace "long"
}
proc back {} {
    set d [lindex $::disp::UNIT $::turtle::heading]
    set from $::turtle::pos
    set to [::pair::sub $from $d]
    ::turtle::_record_seg $from $to short
    set ::turtle::pos $to
    ::turtle::_trace "back"
}

# ---- turns (units of 36°) ------------------------------------------------
proc left  {{k 1}} {
    set ::turtle::heading [expr {(($::turtle::heading + $k) % 10 + 10) % 10}]
    ::turtle::_trace "left $k"
}
proc right {{k 1}} {
    set ::turtle::heading [expr {(($::turtle::heading - $k) % 10 + 10) % 10}]
    ::turtle::_trace "right $k"
}

# ---- home / marks --------------------------------------------------------
proc home {} {
    set ::turtle::pos     $::turtle::home_pos
    set ::turtle::heading 0
    ::turtle::_trace "home"
}
proc mark {name} {
    set ::turtle::marks($name) [list $::turtle::pos $::turtle::heading]
    ::turtle::_trace "mark $name"
}
proc goto {name} {
    if {![info exists ::turtle::marks($name)]} { error "no such mark: $name" }
    lassign $::turtle::marks($name) p h
    set ::turtle::pos     $p
    set ::turtle::heading $h
    ::turtle::_trace "goto $name"
}

# ---- gsave / grestore ----------------------------------------------------
proc gsave {} {
    lappend ::turtle::stack [list $::turtle::pos $::turtle::heading $::turtle::pen \
                                 $::turtle::labelSide]
    ::turtle::_trace "gsave"
}
proc grestore {} {
    if {[llength $::turtle::stack] == 0} { error "grestore: stack empty" }
    set top [lindex $::turtle::stack end]
    set ::turtle::stack [lrange $::turtle::stack 0 end-1]
    lassign $top ::turtle::pos ::turtle::heading ::turtle::pen ::turtle::labelSide
    ::turtle::_trace "grestore"
}

# ---- repeat --------------------------------------------------------------
proc repeat {n body} {
    for {set i 0} {$i < $n} {incr i} { uplevel 1 $body }
}

# ---- label commands ------------------------------------------------------
# `label` marks the current vertex to receive an address label at render.
# `above` / `below` set the side used by subsequent `label` calls, and also
# retroactively update the current vertex (so `short label above` and
# `short above label` are equivalent).
proc label {} {
    variable ::turtle::vertices
    set k [::turtle::_key $::turtle::pos]
    if {![dict exists $::turtle::vertices $k]} {
        ::turtle::_mark_vertex $::turtle::pos
    }
    set entry [dict get $::turtle::vertices $k]
    dict set entry labeled 1
    dict set ::turtle::vertices $k $entry
    ::turtle::_trace "label"
}
proc above {} {
    set ::turtle::labelSide "above"
    ::turtle::_mark_vertex $::turtle::pos
    ::turtle::_trace "above"
}
proc below {} {
    set ::turtle::labelSide "below"
    ::turtle::_mark_vertex $::turtle::pos
    ::turtle::_trace "below"
}

# ---- render knobs --------------------------------------------------------
proc scalephi {n} {
    if {![string is integer -strict $n] || $n < 0} {
        error "scalephi needs a nonnegative integer"
    }
    set ::turtle::scalePhi $n
    ::turtle::_trace "scalephi $n"
}
proc xonly {} { set ::turtle::xonly 1; ::turtle::_trace "xonly" }

# ---- macro sugar: `name = { body }` --------------------------------------
proc unknown {cmd args} {
    if {[llength $args] >= 2 && [lindex $args 0] eq "="} {
        set body [lindex $args 1]
        proc ::$cmd {} $body
        return
    }
    return -code error "invalid command name \"$cmd\""
}

# ---- closure / report ----------------------------------------------------
proc report {} {
    puts "trace:"
    foreach line $::turtle::trace_lines { puts "  $line" }
    puts ""
    puts "final position:  [::pair::toString $::turtle::pos]"
    puts "final heading:   $::turtle::heading  ([expr {$::turtle::heading * 36}]°)"
    puts "start position:  [::pair::toString $::turtle::home_pos]"
    if {[::pair::equals $::turtle::pos $::turtle::home_pos]} {
        puts "CLOSED: returned to start exactly."
    } else {
        puts "OPEN:   position differs from start."
    }
}
