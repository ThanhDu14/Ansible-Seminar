# Biên dịch slide. Cần shell-escape vì minted gọi Pygments để tô màu code.
#   make          -> dùng tectonic (mặc định, cài ở ~/.local/bin)
#   make latexmk  -> dùng TeX Live (sudo apt install texlive-xetex texlive-latex-extra latexmk python3-pygments)
#   make watch    -> latexmk tự biên dịch lại khi lưu file
MAIN := ansible-seminar
TECTONIC ?= $(shell command -v tectonic 2>/dev/null || echo $(HOME)/.local/bin/tectonic)

all: $(MAIN).pdf

$(MAIN).pdf: $(MAIN).tex beamerthemeFIT.sty $(wildcard images/*)
	$(TECTONIC) -Z shell-escape $(MAIN).tex

latexmk:
	latexmk -xelatex -shell-escape $(MAIN).tex

watch:
	latexmk -xelatex -shell-escape -pvc $(MAIN).tex

clean:
	rm -rf _minted* *.aux *.log *.nav *.out *.snm *.toc *.vrb *.fls *.fdb_latexmk *.xdv

.PHONY: all latexmk watch clean
