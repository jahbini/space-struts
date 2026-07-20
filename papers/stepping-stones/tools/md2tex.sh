#!/bin/bash
# md2tex.sh — convert a markdown chapter to LaTeX in this book's style.
#
# Usage: md2tex.sh <input.md> <output.tex>
#
# Pipeline: pandoc emits standard LaTeX (\section{X}\label{Y} for #, and
# \subsection{X}\label{Y} for ##). Two sed transforms then map those onto
# the book's conventions:
#
#   \subsection{X}\label{Y}   ->  \section*{X}
#
# The top-level heading (# in markdown) maps to one of two things
# depending on the file's basename:
#
#   front-matter files                stepping-stone body chapters
#   (introduction, preface,           (everything else)
#    foreword, afterword, epilogue)
#
#   \chapter*{X}                      \steppingstone{X}
#   \addcontentsline{toc}             \label{stone:Y}
#     {chapter}{X}
#
# The rest of pandoc's output (\[..\], \(..\), \begin{itemize}, etc.)
# already matches what the book expects.

set -euo pipefail
in=${1:?usage: md2tex.sh input.md output.tex}
out=${2:?usage: md2tex.sh input.md output.tex}

NL=$'\n'

case "$(basename "$in" .md)" in
    introduction|preface|foreword|afterword|epilogue)
        HEAD_SED="s/^\\\\section\\{(.*)\\}\\\\label\\{.*\\}$/\\\\chapter*{\\1}\\${NL}\\\\addcontentsline{toc}{chapter}{\\1}/"
        ;;
    *)
        HEAD_SED="s/^\\\\section\\{(.*)\\}\\\\label\\{(.*)\\}$/\\\\steppingstone{\\1}\\${NL}\\\\label{stone:\\2}/"
        ;;
esac

pandoc --from markdown+tex_math_single_backslash --to latex --wrap=preserve "$in" \
  | sed -E \
      -e "$HEAD_SED" \
      -e "s/^\\\\subsection\\{(.*)\\}\\\\label\\{(.*)\\}$/\\\\section*{\\1}/" \
  > "$out"
