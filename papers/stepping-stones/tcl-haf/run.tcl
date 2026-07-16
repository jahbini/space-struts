#!/usr/bin/env tclsh
# run.tcl — driver for the HafBase (36°) turtle.
#
# Usage:
#   tclsh tcl-haf/run.tcl <walk>
#   tclsh tcl-haf/run.tcl --svg <out.svg> <walk>
#
# A `-safe` sub-interpreter runs phibase + pairs + preamble + render, then
# the walk file. Two aliases exposed: `puts` (trace) and `write_svg` (SVG
# file emission). Everything dangerous stays hidden.
#
# Walk files may use the coffee-turtle `[ ... ]` block syntax; run.tcl
# rewrites `[`/`]` to `{`/`}` before evaluation so existing corpora load
# unchanged (spec §3 R1).

set svgOut ""
set walkFile ""
set argi 0
while {$argi < [llength $argv]} {
    set arg [lindex $argv $argi]
    switch -- $arg {
        --svg { incr argi; set svgOut [lindex $argv $argi] }
        default { set walkFile $arg }
    }
    incr argi
}
if {$walkFile eq ""} {
    puts stderr "usage: tclsh tcl-haf/run.tcl \[--svg <out.svg>\] <walk>"
    exit 1
}

set here     [file dirname [file normalize [info script]]]
set phibase  [file join $here phibase.tcl]
set pairs    [file join $here pairs.tcl]
set preamble [file join $here preamble.tcl]
set render   [file join $here render.tcl]

proc slurp {path} {
    set fh [open $path r]
    set txt [read $fh]
    close $fh
    return $txt
}

set safe [interp create -safe]
interp alias $safe puts {} puts

proc _write_svg_from_safe {path text} {
    set fh [open $path w]
    puts -nonewline $fh $text
    close $fh
}
interp alias $safe write_svg {} _write_svg_from_safe

foreach src [list $phibase $pairs $preamble $render] {
    if {[catch {$safe eval [slurp $src]} err opts]} {
        puts stderr "load error in $src: $err"
        puts stderr [dict get $opts -errorinfo]
        exit 1
    }
}

# Translate coffee-style [ ... ] blocks to TCL braces before evaluating.
# Safe interp has no command substitution surface exposed anyway.
set walkText [slurp $walkFile]
set walkText [string map {\[ " { " \] " } "} $walkText]

if {[catch {$safe eval $walkText} err opts]} {
    puts stderr "walk error: $err"
    puts stderr [dict get $opts -errorinfo]
    interp delete $safe
    exit 1
}

if {$svgOut ne ""} {
    if {[catch {$safe eval [list svg $svgOut]} err opts]} {
        puts stderr "svg error: $err"
        interp delete $safe
        exit 1
    }
}

$safe eval report
interp delete $safe
