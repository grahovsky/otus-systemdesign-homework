SHELL := /bin/bash

PLANTUML_JAR := plantuml.jar
PLANTUML_URL := https://github.com/plantuml/plantuml/releases/latest/download/plantuml.jar
JAVA ?= java
HW ?=

# Корень поиска: одно задание (HW=hw_01) или все hw_*
ROOT := $(if $(HW),$(HW)/solution/diagrams,$(wildcard hw_*/solution/diagrams))
PUML_FILES := $(shell find $(ROOT) -name '*.puml' 2>/dev/null | sort)
SVG_FILES := $(PUML_FILES:.puml=.svg)

.PHONY: all clean help

all: $(SVG_FILES)
	@echo "Generated $(words $(SVG_FILES)) diagram(s)"

$(PLANTUML_JAR):
	@echo "Downloading latest PlantUML..."
	curl -fsSL -o '$@' '$(PLANTUML_URL)'

%.svg: %.puml $(PLANTUML_JAR)
	$(JAVA) -Dfile.encoding=UTF-8 -jar $(PLANTUML_JAR) -charset UTF-8 \
	  -SdefaultFontName="Segoe UI" -SdefaultFontSize=12 -tsvg '$<'

clean:
	@$(if $(SVG_FILES),rm -f $(SVG_FILES),true)
	@echo "Removed generated SVG diagrams"

help:
	@echo "  make             generate all hw_*/solution/diagrams/*.puml -> SVG"
	@echo "  make HW=hw_01    only one assignment folder"
	@echo "  make clean       remove generated SVG (optional HW=...)"
	@echo "Requires: java, curl, make (Git Bash on Windows)"
