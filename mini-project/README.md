# Mini-project, Part 1 — The matrix-multiply unit

**CS2.501 Advanced Computer Architecture · Monsoon 2026 · IIIT Hyderabad**

Build a small matrix-multiply unit in BSV, use it to compute a large matrix
product, and explore three ways of building it. The three designs compute the
same thing and return the same answers. They differ in how much they do per
cycle — and therefore in cycles, area, and clock period, which do **not** pick
the same winner.

This is **Part 1** of the mini-project, and it is self-contained: specified,
assessed and submitted on its own. In **Part 2** the unit you build here gets
attached to a real RISC-V CPU as a custom instruction — see `SPEC.pdf` §12.

> **Read [`SPEC.pdf`](SPEC.pdf) first.** It is the specification; this file is
> just the orientation.

## What is here

| file | |
|---|---|
| `SPEC.pdf` | **the specification** — read it before touching anything else |
| `MatMul.bsv` | **your file** — ships as a naive design; edit it, replace it, rewrite it |
| `MM_Types.bsv` | the contract between your unit and the harness. **Do not modify** |
| `TbMatMul.bsv` | the testbench, and the same one we grade with. **Do not modify** |
| `Makefile`, `area-delay.sh` | the two measurements |

## Quick start

```bash
export PATH=$HOME/tools/bsc-2026.01-debian-11.11/bin:$PATH

make            # compile, run both workloads, check correctness, report cycles
make depth      # cells and logic_depth of mkMatMul
make schedule   # bsc's rule-conflict report
make clean
```

`make` should finish in a few seconds and end in `mini-project: PASS`. That is
the naive design you were given, working — it is your baseline, not your target.

`make depth` needs a one-time install. No root, no licence:

```bash
pip install --user 'yowasp-yosys==0.68.0.0.post1208'
```

The version is pinned so everyone's numbers are comparable.

## What you hand in

Three designs, the measurement table, and a report of at most three pages
arguing for one of them. The details are in `SPEC.pdf` §11.

**Correctness is checked first and it is absolute.** A fast wrong answer scores
nothing — and the most common way to lose correctness here is by successfully
making something faster.

## If you get stuck

- `SPEC.pdf` §10 lists what to work out; most debugging questions are answered
  there before you need to ask.
- `TbMatMul.bsv` is worth reading. It is the precise statement of what
  "correct" means, and it is more specific than prose can be.
- If two rules you expected to fire together never do, run `make schedule` and
  read the conflict report — `bsc` has already told you why.

Questions and submissions go through **Moodle**. A bug in the handout or the
Makefile is welcome as an issue or a pull request here.
