#!/bin/bash
# md2tex.sh — convert a markdown chapter to LaTeX in this book's style.
#
# Usage: md2tex.sh <input.md> <output.tex>
#
# Pipeline: pandoc emits standard LaTeX (\section{X}\label{Y} for #, and
# \subsection{X}\label{Y} for ##). Two sed transforms then map those onto
# the book's conventions:
#
#   \section{X}\label{Y}      ->  \steppingstone{X}
#                                 \label{stone:Y}
#   \subsection{X}\label{Y}   ->  \section*{X}
#
# The rest of pandoc's output (\[..\], \(..\), \begin{itemize}, etc.)
# already matches what the book expects.

set -euo pipefail
in=${1:?usage: md2tex.sh input.md output.tex}
out=${2:?usage: md2tex.sh input.md output.tex}

# Use a literal newline in the sed replacement (portable across BSD/GNU sed).
NL=$'\n'

pandoc --from markdown+tex_math_single_backslash --to latex --wrap=preserve "$in" \
  | sed -E \
      -e "s/^\\\\section\\{(.*)\\}\\\\label\\{(.*)\\}$/\\\\steppingstone{\\1}\\${NL}\\\\label{stone:\\2}/" \
      -e "s/^\\\\subsection\\{(.*)\\}\\\\label\\{(.*)\\}$/\\\\section*{\\1}/" \
  > "$out"
