#!/usr/bin/env bash
# check-setup.sh --- report what Lab 0 found on your PATH, and what is missing.
#
# Run this before the smoke tests.  It changes nothing; it only looks.
#
#   ./check-setup.sh
#
# Exit status is 0 if everything *required* is present, 1 otherwise.
# Missing "recommended" tools produce a warning but not a failure.

set -uo pipefail

pass=0; warn=0; fail=0
ok()   { printf '  \033[32m ok \033[0m  %-26s %s\n' "$1" "$2"; pass=$((pass+1)); }
note() { printf '  \033[33mwarn\033[0m  %-26s %s\n' "$1" "$2"; warn=$((warn+1)); }
bad()  { printf '  \033[31mMISS\033[0m  %-26s %s\n' "$1" "$2"; fail=$((fail+1)); }

# probe <name> <required|recommended|optional> <version-command> <why>
probe () {
    local name=$1 tier=$2 vcmd=$3 why=$4 ver
    if command -v "$name" >/dev/null 2>&1; then
        ver=$(timeout 10 bash -c "$vcmd" </dev/null 2>&1 | head -1)
        [ -z "$ver" ] && ver="(found at $(command -v "$name"))"
        ok "$name" "$ver"
    else
        case $tier in
            required)    bad "$name" "not on PATH — $why" ;;
            *)           note "$name" "not on PATH — $why" ;;
        esac
    fi
}

echo
echo "Lab 0 — environment check"
echo "  host: $(uname -s) $(uname -m)$( [ -r /etc/os-release ] && . /etc/os-release && echo "  ($PRETTY_NAME)" )"
echo

echo "Required"
probe bsc      required    'bsc -v | head -1'          "the Bluespec compiler; see README step 1"
probe bluetcl  required    'command -v bluetcl'        "ships with bsc; if this is missing your PATH points at a partial install"
probe make     required    'make --version'            "every lab and the CPU builds are driven by make"
probe cc       required    'cc --version'              "Bluesim compiles the elaborated design to C++"
probe c++      required    'c++ --version'             "same"

echo
echo "Recommended"
probe verilator recommended 'verilator --version'       "needed to simulate the generated Verilog (Fife's v_* targets)"
probe iverilog  recommended 'iverilog -V | head -1'     "the default simulator for the upstream smoke test"
probe python3   recommended 'python3 --version'         "used by the pipeline-log to CSV tools"

echo
echo "Optional — only for building your own RISC-V test programs"
probe riscv64-unknown-elf-gcc optional 'riscv64-unknown-elf-gcc --version' "the course ships prebuilt .memhex32 files, so this is not needed to start"

# ---- BLUESPEC_HOME is not required by bsc, but a stale one is a classic trap.
echo
if [ -n "${BLUESPEC_HOME:-}" ]; then
    if [ -d "$BLUESPEC_HOME/lib" ]; then
        ok "BLUESPEC_HOME" "$BLUESPEC_HOME"
    else
        note "BLUESPEC_HOME" "set to '$BLUESPEC_HOME' but there is no lib/ there — unset it or fix it"
    fi
fi

# ---- A bsc on PATH whose lib/ has moved fails in a confusing way.
if command -v bsc >/dev/null 2>&1; then
    root=$(dirname "$(dirname "$(command -v bsc)")")
    if [ ! -d "$root/lib/Libraries" ]; then
        bad "bsc install tree" "found bin/bsc at $root but no lib/Libraries — the tarball must stay whole"
    fi
fi

echo
printf 'Summary: %d ok, %d warning(s), %d missing\n' "$pass" "$warn" "$fail"
if [ "$fail" -gt 0 ]; then
    echo "Fix the MISS lines above, then re-run.  Step 1 of README.md covers bsc."
    exit 1
fi
echo "Required tools are present. Next: the two smoke tests in README.md step 4."
