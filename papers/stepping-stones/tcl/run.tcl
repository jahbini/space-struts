#!/usr/bin/env tclsh
# run.tcl — driver for the TCL turtle.
#
# Usage:
#   tclsh run.tcl <walk>                     — run walk and print report
#   tclsh run.tcl --svg <out.svg> <walk>     — run walk and emit SVG to out
#
# Creates a `-safe` sub-interpreter, evaluates preamble + tables + render
# inside it, then evaluates the user walk file. Dangerous builtins (exec,
# open, file, socket, source, load) remain hidden by `-safe`. Two narrow
# aliases are exposed to the safe interp: `puts` (trace output) and
# `write_svg` (SVG file emission, path+text only). If --svg is given the
# driver invokes `svg <out>` at the end of the walk automatically.

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
    puts stderr "usage: tclsh run.tcl \[--svg <out.svg>\] <walk>"
    exit 1
}

set here     [file dirname [file normalize [info script]]]
set phibase  [file join $here phibase.tcl]
set tables   [file join $here tables.tcl]
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

foreach src [list $phibase $tables $preamble $render] {
    if {[catch {$safe eval [slurp $src]} err opts]} {
        puts stderr "load error in $src: $err"
        puts stderr [dict get $opts -errorinfo]
        exit 1
    }
}

if {[catch {$safe eval [slurp $walkFile]} err opts]} {
    puts stderr "walk error: $err"
    puts stderr [dict get $opts -errorinfo]
    interp delete $safe
    exit 1
}

# Optionally emit SVG.
if {$svgOut ne ""} {
    if {[catch {$safe eval [list svg $svgOut]} err opts]} {
        puts stderr "svg error: $err"
        interp delete $safe
        exit 1
    }
}

# Closure report from inside the safe interp.
$safe eval report

interp delete $safe
