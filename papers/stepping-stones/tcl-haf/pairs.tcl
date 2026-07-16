# pairs.tcl — 2D lattice arithmetic for the HafBase (36-degree) turtle.
#
# A point / heading is a "pair" of PhiBase values (a, b) representing
# a·e0 + b·e72, where e0 = (1, 0) and e72 = (cos 72°, sin 72°). Because
# the (e0, e72) basis is closed under rotation by 36°, the exact rotation
# matrix has entries in Z[φ]:
#
#   R36 = [ φ-1   1-φ ]
#         [ φ-1     1 ]
#
# Ten applications of R36 return exactly to the identity, so the ten
# distinct headings 0..9 (steps of 36°) are all reachable exactly.
#
# The lattice this generates is Z[ω] where ω = exp(iπ/5) — the ring of
# 10th cyclotomic integers, rank 4 over Z. Every point the turtle can
# reach on this lattice has an exact (a, b) pair of PhiBase coordinates,
# and closures are tested by lattice equality, not by float distance.

namespace eval ::pair {}
namespace eval ::disp {
    variable UNIT
    variable LONG
}

proc ::pair::mk {a b} { list $a $b }

proc ::pair::zero {} {
    set z [::pb::zero]
    list $z $z
}

proc ::pair::add {u v} {
    list [::pb::add [lindex $u 0] [lindex $v 0]] \
         [::pb::add [lindex $u 1] [lindex $v 1]]
}

proc ::pair::sub {u v} {
    list [::pb::sub [lindex $u 0] [lindex $v 0]] \
         [::pb::sub [lindex $u 1] [lindex $v 1]]
}

proc ::pair::negate {u} {
    list [::pb::negate [lindex $u 0]] [::pb::negate [lindex $u 1]]
}

proc ::pair::equals {u v} {
    expr {[::pb::equals [lindex $u 0] [lindex $v 0]] && \
          [::pb::equals [lindex $u 1] [lindex $v 1]]}
}

# Multiply pair by φ (scalar). Preserves lattice membership.
proc ::pair::mulphi {u} {
    list [::pb::mulphi [lindex $u 0]] [::pb::mulphi [lindex $u 1]]
}

# Apply R36 to (a, b): new_a = (φ-1)a + (1-φ)b; new_b = (φ-1)a + b.
proc ::pair::rot36 {u} {
    lassign $u a b
    set phi_m1 [::pb::mk 1 -1]   ;# φ - 1
    set one_mp [::pb::mk -1 1]   ;# 1 - φ
    set na [::pb::add [::pb::mul $phi_m1 $a] [::pb::mul $one_mp $b]]
    set nb [::pb::add [::pb::mul $phi_m1 $a] $b]
    list $na $nb
}

proc ::pair::toString {u} {
    list [::pb::toString [lindex $u 0]] [::pb::toString [lindex $u 1]]
}

# ---- Precompute displacement tables ---------------------------------------
# UNIT_DISP[k] = one short step at heading k * 36°.
# LONG_DISP[k] = one long step = φ · UNIT_DISP[k].
# Verified: rot36 applied 10 times to UNIT_DISP[0] returns UNIT_DISP[0]
# exactly; check that the 10th application is the identity of the lattice.
proc ::disp::_init {} {
    variable UNIT
    variable LONG
    set UNIT [list [::pair::mk [::pb::mk 0 1] [::pb::mk 0 0]]]
    for {set k 0} {$k < 9} {incr k} {
        lappend UNIT [::pair::rot36 [lindex $UNIT $k]]
    }
    # Sanity: R36^{10} must equal identity.
    set r10 [::pair::rot36 [lindex $UNIT 9]]
    if {![::pair::equals $r10 [lindex $UNIT 0]]} {
        error "HafBase internal error: R36^10 != identity"
    }
    set LONG {}
    foreach u $UNIT { lappend LONG [::pair::mulphi $u] }
}
::disp::_init
