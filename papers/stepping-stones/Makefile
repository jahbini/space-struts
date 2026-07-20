INKSCAPE ?= /Applications/Inkscape.app/Contents/MacOS/inkscape
COFFEE   ?= coffee
TCLSH    ?= tclsh
PANDOC   ?= pandoc
FIGDIR   := figures/turtle
TCLDIR   := tcl
HAFDIR   := tcl-haf

# Chapters. If a chapter has a *.md, that IS the source of truth for the
# same-named *.tex at root — the pattern rule below regenerates the .tex
# whenever the .md is newer. Chapters without a matching .md are hand-tuned
# .tex only; they compile as-is.
#
# ALL_CHAPTER_TEXS = every root *.tex except main.tex. main.pdf depends on
# it so any chapter edit (direct .tex or via .md) triggers a rebuild.
NON_CHAPTER_MDS  := TURTLES.md
CHAPTER_MDS      := $(filter-out $(NON_CHAPTER_MDS),$(wildcard *.md))
CHAPTER_TEXS     := $(patsubst %.md,%.tex,$(CHAPTER_MDS))
ALL_CHAPTER_TEXS := $(filter-out main.tex,$(wildcard *.tex))

# Three turtles, three file extensions, three separate pattern rules:
#   *.txt -> phiTurtle.coffee          (legacy 2D golden lattice)
#   *.tcl -> tcl/run.tcl               (3D icosahedral group, 72° minimum turn)
#   *.haf -> tcl-haf/run.tcl           (2D HafBase Z[ω] lattice, 36° minimum turn)
TURTLES  := $(wildcard $(FIGDIR)/*.txt)
COFFEE_SVGS := $(TURTLES:.txt=.svg)
COFFEE_PDFS := $(TURTLES:.txt=.pdf)

TCL_WALKS := $(wildcard $(FIGDIR)/*.tcl)
TCL_SVGS  := $(TCL_WALKS:.tcl=.svg)
TCL_PDFS  := $(TCL_WALKS:.tcl=.pdf)

HAF_WALKS := $(wildcard $(FIGDIR)/*.haf)
HAF_SVGS  := $(HAF_WALKS:.haf=.svg)
HAF_PDFS  := $(HAF_WALKS:.haf=.pdf)

# Static SVGs sitting directly in figures/ (not produced by any turtle;
# these are hand-drawn or externally sourced). Each converts to a PDF.
STATIC_SVGS := $(wildcard figures/*.svg)
STATIC_PDFS := $(STATIC_SVGS:.svg=.pdf)

PDFS := $(COFFEE_PDFS) $(TCL_PDFS) $(HAF_PDFS) $(STATIC_PDFS)

.PHONY: all figures verify clean cleanfigs
.PHONY: preview-%
.PRECIOUS: $(FIGDIR)/%.svg

all: figures main.pdf

figures: $(PDFS)

# --- coffee: txt -> svg -----------------------------------------------------
$(FIGDIR)/%.svg: $(FIGDIR)/%.txt
	$(COFFEE) $(FIGDIR)/phiTurtle.coffee $<

# --- TCL: tcl -> svg (3D icosahedral turtle)
$(FIGDIR)/%.svg: $(FIGDIR)/%.tcl
	$(TCLSH) $(TCLDIR)/run.tcl --svg $@ $<

# --- HafBase: haf -> svg (2D 36° turtle)
$(FIGDIR)/%.svg: $(FIGDIR)/%.haf
	$(TCLSH) $(HAFDIR)/run.tcl --svg $@ $<

# --- inkscape: svg -> pdf --------------------------------------------------
$(FIGDIR)/%.pdf: $(FIGDIR)/%.svg
	$(INKSCAPE) $< --export-type=pdf --export-area-drawing --export-filename=$@

figures/%.pdf: figures/%.svg
	$(INKSCAPE) $< --export-type=pdf --export-area-drawing --export-filename=$@

# --- markdown -> LaTeX (rewrites the same-named .tex at root) --------------
# WARNING: this rule overwrites the root *.tex whenever the *.md is newer.
# If you have hand edits in foo.tex that don't exist in foo.md, either move
# them into foo.md first, or delete foo.md to opt out of auto-generation.
%.tex: %.md tools/md2tex.sh
	tools/md2tex.sh $< $@

# --- LaTeX -----------------------------------------------------------------
main.pdf: main.tex $(ALL_CHAPTER_TEXS) $(PDFS)
	pdflatex -interaction=nonstopmode main.tex
	pdflatex -interaction=nonstopmode main.tex

# --- single-figure preview -------------------------------------------------
# `make preview-<name>` builds just figures/turtle/<name>.pdf (from whichever
# of *.txt / *.tcl / *.haf exists) and opens it in Preview.app. Keep the
# Preview window open — it auto-refreshes when the PDF changes on disk, so
# after the first invocation, subsequent `make figures/turtle/<name>.pdf`
# (or another `make preview-<name>`) will show up in place without reopening.
preview-%: $(FIGDIR)/%.pdf
	open $<

# --- verification: run TCL acceptance walks --------------------------------
verify:
	@echo "-- icosahedral (tcl/) --"
	@for w in $(TCLDIR)/walks/*.txt; do \
		echo "== $$w =="; \
		$(TCLSH) $(TCLDIR)/run.tcl $$w | grep -E 'CLOSED|OPEN|violated|error' || true; \
	done
	@echo "-- HafBase (tcl-haf/) --"
	@for w in $(HAFDIR)/walks/*.txt; do \
		echo "== $$w =="; \
		$(TCLSH) $(HAFDIR)/run.tcl $$w | grep -E 'CLOSED|OPEN|violated|error' || true; \
	done

clean:
	rm -f *.aux *.log *.out *.toc *.synctex* main.pdf

cleanfigs:
	rm -f $(COFFEE_SVGS) $(TCL_SVGS) $(HAF_SVGS) $(PDFS)
