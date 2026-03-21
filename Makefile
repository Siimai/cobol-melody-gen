COBC     = cobc
COBCOPY  = src
BUILDDIR = build
BIN      = $(BUILDDIR)/melody-gen

.PHONY: all run clean setup install-deps

all: setup $(BIN)

# Each called subprogram is compiled as a shared object (.so).
# All artifacts (binary + .so files) land in $(BUILDDIR).
# The -I flag tells cobc where to find copybooks (*.cpy).
$(BIN): src/main.cob src/scales.cob src/generator.cob src/export.cob src/midiexp.cob
	$(COBC) -m -I $(COBCOPY) src/scales.cob    -o $(BUILDDIR)/scales
	$(COBC) -m -I $(COBCOPY) src/generator.cob -o $(BUILDDIR)/generator
	$(COBC) -m -I $(COBCOPY) src/export.cob    -o $(BUILDDIR)/export
	$(COBC) -m -I $(COBCOPY) src/midiexp.cob   -o $(BUILDDIR)/midiexp
	$(COBC) -x -I $(COBCOPY) src/main.cob      -o $(BIN)

run: all
	COB_LIBRARY_PATH=./$(BUILDDIR) ./$(BIN)

setup:
	@mkdir -p output $(BUILDDIR)

clean:
	@rm -rf $(BUILDDIR)
	@echo "Cleaned build artifacts."

# Installs GnuCOBOL via Homebrew if not already present.
install-deps:
	@which cobc > /dev/null 2>&1 \
		&& echo "GnuCOBOL already installed: $$(cobc --version | head -1)" \
		|| { echo "Installing GnuCOBOL via Homebrew..."; brew install gnu-cobol; }
