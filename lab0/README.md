# Lab 0 — Get the toolchain working

**CS2.501 Advanced Computer Architecture · Monsoon 2026 · IIIT Hyderabad**

Nothing in this lab is graded, and nothing in it is about architecture. Its only
job is to leave you with a machine that can compile BSV and run a simulation, so
that the labs and the mini-project start at the interesting part.

Budget **30–45 minutes**, most of it download time. Do it on the machine you
intend to work on for the rest of the semester.

At the end you will have run three things: the Bluespec compiler's own smoke
test, a small matrix multiply we wrote for this course, and **Fife** — the
pipelined RISC-V CPU your mini-project extends.

---

## What you are installing

| Tool | Why you need it | Required? |
|---|---|---|
| **`bsc`** — the Bluespec compiler | Compiles BSV to a C++ simulation (*Bluesim*) or to Verilog | Yes |
| **Verilator** | Simulates the Verilog that `bsc` generates | Strongly recommended |
| **Icarus Verilog** (`iverilog`) | The default simulator for the compiler's own smoke test | Recommended |
| A C/C++ compiler and `make` | Bluesim links the elaborated design as a C++ program | Yes |
| **`riscv64-unknown-elf-gcc`** | Only if you want to compile *your own* RISC-V test programs | No — we ship prebuilt ones |

You do **not** need an FPGA, a licence, or a Bluespec Inc. account. `bsc` has
been free and open source (BSD-3) since 2020.

---

## Step 1 — Install `bsc`

`bsc` is distributed as a prebuilt tarball. There is no installer and nothing to
configure: you untar it and put its `bin/` on your `PATH`.

Go to **<https://github.com/B-Lang-org/bsc/releases>** and, under the latest
release's *Assets*, pick the build matching your OS. As of the 2026.01 release:

| Your system | Asset to download |
|---|---|
| Ubuntu 22.04 / 24.04 / 26.04 | `bsc-2026.01-ubuntu-<version>.tar.gz` |
| **Ubuntu 20.04** | `bsc-2026.01-debian-11.11.tar.gz` — there is no 20.04 build any more, and the Debian 11 one works |
| Debian 11 / 12 / 13 | `bsc-2026.01-debian-<version>.tar.gz` |
| Rocky / RHEL 8, 9, 10 | `bsc-2026.01-rockylinux-<version>.tar.gz` |
| macOS 14 / 15 / 26 (Apple silicon) | `bsc-2026.01-macos-<version>.tar.gz` |
| macOS 15 (Intel) | `bsc-2026.01-macos-15-intel.tar.gz` |
| Windows | Use WSL2 with Ubuntu, then follow the Ubuntu row |

If your exact distribution is not listed, take the nearest **older** one — these
are dynamically linked against glibc, so an older build runs on a newer system
but not the other way round.

```bash
mkdir -p ~/tools && cd ~/tools
tar -xzf ~/Downloads/bsc-2026.01-debian-11.11.tar.gz     # ← your filename
```

> **Keep the directory whole.** The executables in `bin/` locate their
> libraries relative to their own path. Moving the whole folder is fine; moving
> `bin/bsc` out of it is not.

## Step 2 — Put it on your `PATH`

```bash
export PATH=$HOME/tools/bsc-2026.01-debian-11.11/bin:$PATH
```

That line lasts as long as the shell. Append it to `~/.bashrc` (or `~/.zshrc`)
to make it permanent, then open a new terminal. Confirm:

```bash
$ bsc -v
Bluespec Compiler, version 2026.01 (build 9bd39e6f)
```

If you get `bsc: command not found`, the path in your `export` is wrong — check
it with `ls $HOME/tools/*/bin/bsc`.

The reference manuals ship inside the tarball, under `doc/`: the **BSV Language
Reference Guide** and the **BSC User Guide** are the two you will actually open.

## Step 3 — Install the Verilog simulators

`bsc` generates Verilog but does not simulate it; that is Verilator's job.
Icarus Verilog is a second, smaller simulator that the compiler's own smoke test
uses by default.

```bash
# Debian / Ubuntu
sudo apt-get update && sudo apt-get install -y verilator iverilog build-essential

# macOS
brew install verilator icarus-verilog
```

The distribution's Verilator is usually a version or two behind the latest.
That is fine for this course.

## Step 4 — Check what you have

From this directory:

```bash
$ ./check-setup.sh
```

It runs nothing but version commands, and prints a line per tool:

```
Required
   ok   bsc                        Bluespec Compiler, version 2026.01 (build 9bd39e6f)
   ok   bluetcl                    /home/you/tools/bsc-2026.01-debian-11.11/bin/bluetcl
   ok   make                       GNU Make 4.2.1
   ok   cc                         cc (Ubuntu 9.4.0-1ubuntu1~20.04.2) 9.4.0
   ok   c++                        c++ (Ubuntu 9.4.0-1ubuntu1~20.04.2) 9.4.0
...
Summary: 9 ok, 0 warning(s), 0 missing
```

Warnings are survivable; a `MISS` in the *Required* block is not. Fix those
before going on.

---

## Step 5 — The smoke tests

Two of them, and they check different things. Run both.

### 5a · The compiler's own smoke test

The `bsc` project ships a smoke test with the compiler, and it is the first
thing to reach for whenever you suspect the *installation* rather than your
code. It compiles a Fibonacci generator down **both** paths — Verilog and
Bluesim — runs each, and diffs the output against a stored golden file.

The files in [`smoke-bsc/`](smoke-bsc/) are copied verbatim from
[`B-Lang-org/bsc/examples/smoke_test`](https://github.com/B-Lang-org/bsc/tree/main/examples/smoke_test)
so that you do not have to clone the 200 MB compiler repository; see
[`smoke-bsc/PROVENANCE.md`](smoke-bsc/PROVENANCE.md).

```bash
cd smoke-bsc
make smoke_test
```

Expected — the two `diff` lines must print **nothing**:

```
Checking Verilog generation
...
Comparing result of Bluespec Simulation
Some simulator specific difference expected
diff mkFibOne.out.expected smoke_test_verilog.out

Bluespec installation looks OK

Checking bsc compiles
...
Comparing result of Bluespec Simulation
diff mkFibOne.out.expected smoke_test_bluesim.out

Bluespec's Bluesim looks OK
```

To use Verilator instead of Icarus for the Verilog half: `make smoke_test verilator=1`.
`make clean` resets the directory. Other simulators are selectable too — `make help`.

### 5b · Ours: a 2×2 matrix multiply

The compiler's test proves `bsc` runs. This one proves *you* can drive it: an
ordinary `Makefile`, a module with an interface, and a self-checking testbench —
the shape every later lab takes.

It is also a deliberate preview. The mini-project asks you to build a matrix
multiply unit and attach it to Fife as a RISC-V instruction-set extension.
[`smoke-matmul/MatMul2.bsv`](smoke-matmul/MatMul2.bsv) is the seed of that unit
with the pipelining and the ISA plumbing removed — about sixty lines, worth
reading now even if none of it is familiar yet.

```bash
cd ../smoke-matmul
make
```

Expected:

```
=== Lab 0 smoke test: 2x2 matrix multiply ===
  ok    A x B            = [[19 22] [43 50]]
  ok    A x I            = [[1 2] [3 4]]
  ok    signed operands  = [[0 2] [-2 -4]]
SMOKE TEST PASSED

lab0/smoke-matmul: PASS
```

`make` exits non-zero if that verdict is missing, so it is safe to trust the
last line rather than reading the whole log. `make clean` resets.

---

## Step 6 — Build Fife

This is the real check: if Fife builds and runs on your machine, you are ready
for every lab in the course and for the mini-project.

Clone the textbook repository — Nikhil's *Learn Bluespec and RISC-V Design*,
which is also the source for lectures 3–5:

```bash
git clone https://github.com/rsnikhil/Learn_Bluespec_and_RISCV_Design
cd Learn_Bluespec_and_RISCV_Design/Code/Build/Fife
make b_all          # bsc-compile, link for Bluesim, run the Hello World test
```

The first build takes a few minutes. The last lines you are looking for:

```
Fife v0.90 2025-07-12: starting execution at PC 80000000
...
Loading memhex file test.memhex32
================================================================
GPRs: initialized to 0
Hello World!
```

That is a **pipelined RV32I CPU**, written in BSV, executing a compiled RISC-V
binary on your laptop. `make help` in that directory lists the other targets —
`b_run_add` runs an official RISC-V ISA test, and `v_all` does the same thing
through Verilog and Verilator instead of Bluesim. Try `v_all` too; it exercises
the Verilator half of your install the way `b_all` exercises Bluesim.

---

## Troubleshooting

| Symptom | Cause and fix |
|---|---|
| `bsc: command not found` | `PATH` not set, or set in a different shell. Re-run the `export` from step 2 and check with `which bsc`. |
| `bsc: error while loading shared libraries` | The tarball is for a newer glibc than your system. Download an **older** distribution's build. |
| `Bluespec directory not found` / library errors | `bin/bsc` was moved out of its install tree. Re-extract and keep the folder intact. |
| `BLUESPEC_HOME` complaints | You have a stale variable from an older install. `unset BLUESPEC_HOME` — `bsc` does not need it. |
| `iverilog: command not found` during `make smoke_test` | Step 3, or use `make smoke_test verilator=1`. |
| The Verilog `diff` shows differences but Bluesim's does not | Usually harmless simulator formatting; the upstream Makefile tolerates it deliberately. If Bluesim's diff is clean, your install is fine. |
| Fife build fails with `Command not found: bsc` under `make` | `make` uses a login shell that has not read your `~/.bashrc`. Set `PATH` inline: `PATH=$HOME/tools/bsc-.../bin:$PATH make b_all`. |
| Everything is slow | Bluesim link is the slow step. It is once per build, not once per run. |

Still stuck: post on the course Moodle forum with the **exact** command you ran
and the **full** output, plus the output of `./check-setup.sh`.

---

## What to hand in

Nothing. But you should be able to show, on your own machine:

- [ ] `bsc -v` prints a version
- [ ] `./check-setup.sh` reports 0 missing
- [ ] `smoke-bsc`: `make smoke_test` — both diffs clean
- [ ] `smoke-matmul`: `make` — `SMOKE TEST PASSED`
- [ ] `Build/Fife`: `make b_all` — `Hello World!`

If the last box is ticked, the mini-project has no setup left in it.

## Where to next

- **BSV, from zero** — Lecture 3, then the graded exercises under `Exercises/` in the
  repository you cloned in step 6; `Ex-03-A-Hello-World` onwards follow the textbook chapter by chapter
- **The textbook** — `Book_BLang_RISCV.pdf` at the root of the repo you cloned in step 6
- **Reading Drum and Fife** — the [Drum/Fife code walkthrough](https://sureshpurini.github.io/drum-fife-walkthrough)
