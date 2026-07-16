# preamble.tcl — Stage 3 turtle.
#
# Real: PhiBase, SixPhi 6-tuples, exact short/long/back, mark/goto, gsave/
# grestore, all 60 icosahedral rotations from tables.tcl.  Floor tracked as
# a signed axis slot (idx in 0..5 for A..F, sign in ±1) through every turn.
# Floor invariant asserted at every command by default; disable with
# `checkfloor off`.  G is real: query returns "A+"/"C-"/etc.; `G k` rotates
# heading (and floor) 72° about the signed floor axis.  Macros: `name = { ... }`
# defines a proc via the unknown handler (§3, R1 macro sugar).

namespace eval ::turtle {
    variable pos
    variable heading
    variable pen         1
    variable floor_idx   0    ;# 0..5 for A..F
    variable floor_sign  1    ;# ±1
    variable floor_check 1    ;# assert heading[floor_idx] == 0 after each turn
    variable marks
    variable stack
    variable trace_lines
    variable segments      ;# list of {from_pos to_pos size} recorded when pen down
    array set marks {}
    set stack {}
    set trace_lines {}
    set segments {}

    # Canonical start pose (see Stage 1 comments for derivation).
    variable home_pos [::six::mk \
        [::pb::mk 1  1] [::pb::mk 1 -1] \
        [::pb::mk 1  1] [::pb::mk 1 -1] \
        [::pb::mk 1  1] [::pb::mk 1 -1]]
    variable home_heading [::six::mk \
        [::pb::mk 0  0] [::pb::mk 0 2] \
        [::pb::mk 0  0] [::pb::mk -2 2] \
        [::pb::mk 0 -2] [::pb::mk -2 2]]

    set pos     $home_pos
    set heading $home_heading
}

# ---- helpers -------------------------------------------------------------
proc ::turtle::_trace {msg} {
    variable trace_lines
    lappend trace_lines $msg
}

proc ::turtle::_floor_letter {} {
    variable floor_idx
    lindex {A B C D E F} $floor_idx
}

proc ::turtle::_floor_string {} {
    variable floor_idx
    variable floor_sign
    return "[_floor_letter][expr {$floor_sign > 0 ? {+} : {-}}]"
}

# Assert heading component along the floor axis is exactly zero. If floor
# is (i, s), then heading . floor = s * heading[i]; equivalent to heading[i]==0.
proc ::turtle::_assert_floor_perp {ctx} {
    variable heading
    variable floor_idx
    variable floor_check
    if {!$floor_check} return
    set slot [lindex $heading $floor_idx]
    if {![::pb::iszero $slot]} {
        error "floor invariant violated after $ctx: heading[[_floor_letter]] = [::pb::toString $slot]"
    }
}

# ---- rotation dispatch ---------------------------------------------------
# tables.tcl entries are 4-lists: {coord_perm coord_signs basis_perm basis_signs}.
# Coord acts on heading (SixPhi vector); basis acts on floor (signed direction).
proc ::turtle::_apply_rot {name} {
    if {![info exists ::tab::rot($name)]} { error "no such rotation: $name" }
    lassign $::tab::rot($name) cperm csigns bperm bsigns
    variable heading
    variable floor_idx
    variable floor_sign
    set heading    [::six::signperm $heading $cperm $csigns]
    set new_idx    [lindex $bperm $floor_idx]
    set new_sign   [expr {$floor_sign * [lindex $bsigns $floor_idx]}]
    set floor_idx  $new_idx
    set floor_sign $new_sign
}

# ---- pen -----------------------------------------------------------------
proc pendown {} { set ::turtle::pen 1; ::turtle::_trace "pendown" }
proc penup   {} { set ::turtle::pen 0; ::turtle::_trace "penup" }

# ---- steps ---------------------------------------------------------------
proc ::turtle::_record_seg {from to size} {
    variable pen
    variable segments
    if {$pen} { lappend segments [list $from $to $size] }
}
proc short {} {
    set from $::turtle::pos
    set to [::six::add $from $::turtle::heading]
    ::turtle::_record_seg $from $to short
    set ::turtle::pos $to
    ::turtle::_trace "short"
}
proc long {} {
    set from $::turtle::pos
    set to [::six::add $from [::six::mulphi $::turtle::heading]]
    ::turtle::_record_seg $from $to long
    set ::turtle::pos $to
    ::turtle::_trace "long"
}
proc back {} {
    set from $::turtle::pos
    set to [::six::sub $from $::turtle::heading]
    ::turtle::_record_seg $from $to back
    set ::turtle::pos $to
    ::turtle::_trace "back"
}

# ---- marks ---------------------------------------------------------------
proc mark {name} {
    set ::turtle::marks($name) $::turtle::pos
    ::turtle::_trace "mark $name"
}
proc goto {name} {
    if {![info exists ::turtle::marks($name)]} { error "no such mark: $name" }
    set ::turtle::pos $::turtle::marks($name)
    ::turtle::_trace "goto $name"
}

# ---- home ----------------------------------------------------------------
proc home {} {
    set ::turtle::pos        $::turtle::home_pos
    set ::turtle::heading    $::turtle::home_heading
    set ::turtle::floor_idx  0
    set ::turtle::floor_sign 1
    ::turtle::_trace "home"
}

# ---- gsave / grestore ----------------------------------------------------
# Push/pop entire turtle state except marks (default: marks are global).
proc gsave {} {
    lappend ::turtle::stack [list \
        $::turtle::pos $::turtle::heading $::turtle::pen \
        $::turtle::floor_idx $::turtle::floor_sign]
    ::turtle::_trace "gsave"
}
proc grestore {} {
    if {[llength $::turtle::stack] == 0} { error "grestore: stack empty" }
    set top [lindex $::turtle::stack end]
    set ::turtle::stack [lrange $::turtle::stack 0 end-1]
    lassign $top \
        ::turtle::pos ::turtle::heading ::turtle::pen \
        ::turtle::floor_idx ::turtle::floor_sign
    ::turtle::_trace "grestore"
}

# ---- repeat --------------------------------------------------------------
proc repeat {n body} {
    for {set i 0} {$i < $n} {incr i} { uplevel 1 $body }
}

# ---- world-axis 5-fold turns (A..F) --------------------------------------
proc ::turtle::_face_turn {axis k} {
    set km [expr {(($k % 5) + 5) % 5}]
    if {$km == 0} return
    set name "$axis[expr {$km <= 2 ? $km : $km - 5}]"
    _apply_rot $name
    _assert_floor_perp "$axis $k"
    _trace "$axis $k"
}
foreach axis {A B C D E F} {
    proc $axis {{k 1}} [format {::turtle::_face_turn %s $k} $axis]
}

# ---- vertex 3-fold turns (10 legal triples) ------------------------------
foreach triple {ABC ABD ACE ADF AEF BCF BDE BEF CDE CDF} {
    proc $triple {{k 1}} [format {
        set km [expr {(($k %% 3) + 3) %% 3}]
        if {$km == 0} return
        set name "%s[expr {$km == 1 ? 1 : -1}]"
        ::turtle::_apply_rot $name
        ::turtle::_assert_floor_perp "%s $k"
        ::turtle::_trace "%s $k"
    } $triple $triple $triple]
}

# ---- 2-fold edge flips ---------------------------------------------------
foreach pair {AB AC AD AE AF BC BD BE BF CD CE CF DE DF EF} {
    proc $pair {} [format {
        ::turtle::_apply_rot %s
        ::turtle::_assert_floor_perp "%s"
        ::turtle::_trace "%s"
    } $pair $pair $pair]
}

# ---- G (floor query + rotation about signed floor axis) ------------------
#
# G units are 36 degrees (matches the face-turtle `left`/`right` convention).
# The 60-element icosahedral group only holds even-multiples of 36 (i.e.,
# the face-axis rotations 0, +/-72, +/-144). Odd multiples are recovered
# via the identity
#   R(theta) = negate . R(theta - 180)
# so that G 3 (108°) is "face-rotate by -72°, then negate the heading."
# Valid because the ten in-plane heading directions on the perp plane
# satisfy dir(j+5) = -dir(j). Floor unchanged in all cases.
proc G {args} {
    switch [llength $args] {
        0 { return [::turtle::_floor_string] }
        1 {
            set k [lindex $args 0]
            set signedK [expr {$::turtle::floor_sign * $k}]
            set kmod    [expr {(($signedK % 10) + 10) % 10}]
            set letter  [::turtle::_floor_letter]
            if {$kmod == 0} {
                ::turtle::_trace "G $k"
                return
            }
            if {$kmod % 2 == 0} {
                # Pure face rotation about floor by kmod/2 face-steps.
                ::turtle::_face_turn $letter [expr {$kmod / 2}]
            } else {
                # Odd k in 36-deg units: rotate by kmod-5 (even), then
                # negate the heading slotwise (2nd factor of the identity above).
                set even [expr {$kmod - 5}]
                if {$even != 0} {
                    ::turtle::_face_turn $letter [expr {$even / 2}]
                }
                set ::turtle::heading [::six::negate $::turtle::heading]
                ::turtle::_assert_floor_perp "G $k (negate)"
            }
            # Overwrite the last trace line so the walk shows the user's
            # original G call rather than the internal face turn.
            set idx [expr {[llength $::turtle::trace_lines] - 1}]
            lset ::turtle::trace_lines $idx "G $k"
        }
        default { error "G takes 0 or 1 arguments" }
    }
}

# ---- floor-check control (dev knob) --------------------------------------
proc checkfloor {mode} {
    switch $mode {
        on  - 1 - true  { set ::turtle::floor_check 1 }
        off - 0 - false { set ::turtle::floor_check 0 }
        default { error "checkfloor: use on or off" }
    }
    ::turtle::_trace "checkfloor $mode"
}

# ---- macro sugar: `name = { body }` --------------------------------------
# The safe-interp `unknown` fallback catches any unknown command. If the
# call shape is `name = {body}`, define a global proc. Otherwise pass
# through to a normal "unknown command" error.
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
    puts "final position:  [::six::toString $::turtle::pos]"
    puts "final heading:   [::six::toString $::turtle::heading]"
    puts "final floor:     [::turtle::_floor_string]"
    puts "start position:  [::six::toString $::turtle::home_pos]"
    if {[::six::equals $::turtle::pos $::turtle::home_pos]} {
        puts "CLOSED: returned to start exactly."
    } else {
        puts "OPEN:   position differs from start."
    }
}
