# phibase.tcl — exact arithmetic in Z[φ] and a 6-tuple representation.
#
# A PhiBase value is a TCL list {p n d} representing (p·φ + n) / d, matching
# the constructor signature in ~/development/space-struts/src/lib/coffee/
# phiBase.coffee. Runtime v1 (turtle steps + world-axis rotations) stays in
# Z[φ], so d must be 1; d != 1 in a turtle state variable is a drift alarm.
#
# Zero-cost fast path: pb::add/sub/mul on two d==1 operands never touches d.
#
# A SixPhi vector is a TCL list of six PhiBase values, ordered A B C D E F,
# where slot i is (position) · basisNormals3Phi[i]. Steps are slotwise
# adds; world-axis rotations are signed permutations of the six slots.

namespace eval ::pb {}
namespace eval ::six {}

# ---------------- gcd for reduction ----------------------------------------
proc ::pb::_igcd {a b} {
    set a [expr {$a < 0 ? -$a : $a}]
    set b [expr {$b < 0 ? -$b : $b}]
    while {$b != 0} {
        set t [expr {$a % $b}]
        set a $b
        set b $t
    }
    return $a
}

# ---------------- constructor / canonical form -----------------------------
proc ::pb::mk {p n {d 1}} {
    if {$d == 0} { error "PhiBase denominator zero" }
    if {$d == 1} { return [list $p $n 1] }
    if {$d < 0} { set p [expr {-$p}]; set n [expr {-$n}]; set d [expr {-$d}] }
    set g [_igcd [_igcd $p $n] $d]
    if {$g > 1} { set p [expr {$p/$g}]; set n [expr {$n/$g}]; set d [expr {$d/$g}] }
    return [list $p $n $d]
}

proc ::pb::zero {}  { return [list 0 0 1] }
proc ::pb::one {}   { return [list 0 1 1] }
proc ::pb::phi {}   { return [list 1 0 1] }

proc ::pb::iszero {a}  { expr {[lindex $a 0]==0 && [lindex $a 1]==0} }
proc ::pb::inlattice {a} { expr {[lindex $a 2] == 1} }

# ---------------- arithmetic ----------------------------------------------
proc ::pb::add {a b} {
    lassign $a p1 n1 d1
    lassign $b p2 n2 d2
    if {$d1 == 1 && $d2 == 1} { return [list [expr {$p1+$p2}] [expr {$n1+$n2}] 1] }
    mk [expr {$p1*$d2 + $p2*$d1}] [expr {$n1*$d2 + $n2*$d1}] [expr {$d1*$d2}]
}

proc ::pb::sub {a b} {
    lassign $a p1 n1 d1
    lassign $b p2 n2 d2
    if {$d1 == 1 && $d2 == 1} { return [list [expr {$p1-$p2}] [expr {$n1-$n2}] 1] }
    mk [expr {$p1*$d2 - $p2*$d1}] [expr {$n1*$d2 - $n2*$d1}] [expr {$d1*$d2}]
}

proc ::pb::negate {a} {
    lassign $a p n d
    list [expr {-$p}] [expr {-$n}] $d
}

# (p1 φ + n1)(p2 φ + n2) = (p1 n2 + n1 p2 + p1 p2) φ + (n1 n2 + p1 p2),
# using φ² = φ + 1.
proc ::pb::mul {a b} {
    lassign $a p1 n1 d1
    lassign $b p2 n2 d2
    set pp [expr {$p1*$n2 + $n1*$p2 + $p1*$p2}]
    set nn [expr {$n1*$n2 + $p1*$p2}]
    if {$d1 == 1 && $d2 == 1} { return [list $pp $nn 1] }
    mk $pp $nn [expr {$d1*$d2}]
}

# Multiplication by φ: (p φ + n) → (p+n) φ + p.
proc ::pb::mulphi {a} {
    lassign $a p n d
    list [expr {$p + $n}] $p $d
}

proc ::pb::equals {a b} {
    lassign $a p1 n1 d1
    lassign $b p2 n2 d2
    expr {$p1*$d2 == $p2*$d1 && $n1*$d2 == $n2*$d1}
}

proc ::pb::toString {a} {
    lassign $a p n d
    if {$d == 1} { return "P($p,$n)" }
    return "P($p,$n,$d)"
}

# Numerical approximation, for render pass only. Never used in exact
# arithmetic. Uses the double-precision value of phi.
proc ::pb::toFloat {a} {
    lassign $a p n d
    expr {($p * 1.6180339887498949 + $n) / double($d)}
}

# ---------------- SixPhi ---------------------------------------------------
proc ::six::mk {vA vB vC vD vE vF} { list $vA $vB $vC $vD $vE $vF }

proc ::six::zero {} {
    set z [::pb::zero]
    list $z $z $z $z $z $z
}

proc ::six::add {u v} {
    set out {}
    for {set i 0} {$i < 6} {incr i} {
        lappend out [::pb::add [lindex $u $i] [lindex $v $i]]
    }
    return $out
}

proc ::six::sub {u v} {
    set out {}
    for {set i 0} {$i < 6} {incr i} {
        lappend out [::pb::sub [lindex $u $i] [lindex $v $i]]
    }
    return $out
}

proc ::six::negate {u} {
    set out {}
    foreach x $u { lappend out [::pb::negate $x] }
    return $out
}

proc ::six::mulphi {u} {
    set out {}
    foreach x $u { lappend out [::pb::mulphi $x] }
    return $out
}

proc ::six::equals {u v} {
    for {set i 0} {$i < 6} {incr i} {
        if {![::pb::equals [lindex $u $i] [lindex $v $i]]} { return 0 }
    }
    return 1
}

# Signed permutation: perm is a 6-list of source slot indices,
# signs is a 6-list of +1/-1. new[i] = signs[i] * old[perm[i]].
proc ::six::signperm {u perm signs} {
    set out {}
    for {set i 0} {$i < 6} {incr i} {
        set src [lindex $u [lindex $perm $i]]
        if {[lindex $signs $i] < 0} { set src [::pb::negate $src] }
        lappend out $src
    }
    return $out
}

proc ::six::toString {u} {
    set parts {}
    foreach x $u { lappend parts [::pb::toString $x] }
    return "\[[join $parts { }]\]"
}
