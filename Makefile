COBC    = cobc
COBCOPY = src
BIN     = melody-gen

.PHONY: all run clean setup install-deps

all: setup $(BIN)

# Each called subprogram is compiled as a shared object (.so).
# The -I flag tells cobc where to find copybooks (*.cpy).
$(BIN): src/main.cob src/scales.cob src/generator.cob src/export.cob src/midiexp.cob
	$(COBC) -m -I $(COBCOPY) src/scales.cob    -o scales
	$(COBC) -m -I $(COBCOPY) src/generator.cob -o generator
	$(COBC) -m -I $(COBCOPY) src/export.cob    -o export
	$(COBC) -m -I $(COBCOPY) src/midiexp.cob   -o midiexp
	$(COBC) -x -I $(COBCOPY) src/main.cob      -o $(BIN)

run: all
	./$(BIN)

setup:
	@mkdir -p output

clean:
	@rm -f $(BIN) *.so *.o
	@echo "Cleaned build artifacts."

# Installs GnuCOBOL via Homebrew if not already present.
install-deps:
	@which cobc > /dev/null 2>&1 \
		&& echo "GnuCOBOL already installed: $$(cobc --version | head -1)" \
		|| { echo "Installing GnuCOBOL via Homebrew..."; brew install gnu-cobol; }
