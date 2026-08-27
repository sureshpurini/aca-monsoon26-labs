# Makefile --- Lab 0 smoke test: 2x2 matrix multiply in Bluesim.
#
# Self-contained on purpose: it needs nothing but `bsc` on your PATH, so you can
# copy this directory anywhere.  (The lecture examples under ../../code/ share a
# common.mk instead; this one does not, so Lab 0 has no prerequisites.)
#
#   make          compile, link, run, and check the result
#   make clean    remove everything generated

TOP      = mkTbMatMul2
MAIN     = TbMatMul2.bsv
BUILDDIR = build_bsim
EXE      = $(TOP).bexe

BSC      ?= bsc
BSCFLAGS  = -sim -aggressive-conditions -no-warn-action-shadowing \
            -bdir $(BUILDDIR) -simdir $(BUILDDIR) -info-dir $(BUILDDIR)

.PHONY: all check run link compile clean

all: check

$(BUILDDIR):
	@mkdir -p $(BUILDDIR)

# Type-check the BSV and elaborate it down to a Bluesim module.
compile: | $(BUILDDIR)
	$(BSC) $(BSCFLAGS) -u -g $(TOP) $(MAIN)

# Generate C++ for the elaborated design and link it into an executable.
link: compile
	$(BSC) $(BSCFLAGS) -e $(TOP) -o $(EXE)

run: link
	@./$(EXE)

# Turn the simulation's verdict into an exit code, so `make` fails loudly on a
# broken install instead of printing a wall of output nobody reads to the end.
check: link
	@./$(EXE) | tee $(BUILDDIR)/run.log
	@echo
	@if grep -q '^SMOKE TEST PASSED' $(BUILDDIR)/run.log; then \
	    echo "lab0/smoke-matmul: PASS"; \
	else \
	    echo "lab0/smoke-matmul: FAIL -- see the output above"; exit 1; \
	fi

clean:
	rm -rf $(BUILDDIR) $(EXE) $(TOP).bexe.so
