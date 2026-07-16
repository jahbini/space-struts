INKSCAPE ?= /Applications/Inkscape.app/Contents/MacOS/inkscape
COFFEE   ?= coffee
TCLSH    ?= tclsh
FIGDIR   := figures/turtle
TCLDIR   := tcl
HAFDIR   := tcl-haf

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

PDFS := $(COFFEE_PDFS) $(TCL_PDFS) $(HAF_PDFS)

.PHONY: all figures verify clean cleanfigs
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

# --- LaTeX -----------------------------------------------------------------
main.pdf: main.tex $(PDFS)
	pdflatex -interaction=nonstopmode main.tex
	pdflatex -interaction=nonstopmode main.tex

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
