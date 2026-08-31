# Lab 1 — A matrix multiply unit

**CS2.501 Advanced Computer Architecture · Monsoon 2026 · IIIT Hyderabad**

Build a hardware unit that multiplies small matrices, in BSV. It accepts
requests through a queue, accumulates results internally, and hands them back
through another queue.

The specification below fixes **what** your unit must do. It says almost nothing
about **how**, because how is the assignment. There are many correct designs.
They differ by more than a factor of two, and — this is the point — *no single
number says which is best*.

---

## 1 · Why this unit exists

Every accelerator in the last third of this course — GPU tensor cores, the TPU's
systolic array, the NPU in your phone — is, at its heart, a small matrix
multiplier with a scratchpad around it. They differ in size, in numeric format,
and in how data reaches them, but not much in what the arithmetic unit does.

So we are going to build one, and then in **Lab 2 we will bolt it onto a real
RISC-V CPU** — Fife, from lectures 3–5 — as a custom instruction. That is why
the interface below looks the way it does: every request carries at most one
32-bit word in and returns at most one out, because in Lab 2 each request
becomes one instruction, where the word in is `rs1`, the word out is `rd`, and
the small indices come from the immediate field.

You do not need to think about Fife yet. But do not "improve" the interface by
widening it — the width is the point, and Lab 2 will not accept a wider one.

## 2 · What it computes

```
C[M][N]  +=  A[M][K] × B[K][N]
```

`A` and `B` hold signed `W_ELEM`-bit integers. `C` accumulates in signed
`W_ACC`-bit integers. For submission:

| | value |
|---|---|
| `M`, `K`, `N` | 4, 4, 4 |
| `W_ELEM` | 8 (so `A`, `B` are `Int#(8)`) |
| `W_ACC` | 32 (so `C` is `Int#(32)`) |

Wider accumulators than operands is not an accident, and §8 asks you to work out
exactly how much wider they have to be.

All of these are typedefs in `MM_Types.bsv`. §9 invites you to change them —
after you have the submitted shape working.

## 3 · The interface

You implement:

```bsv
interface MatMul_IFC;
   method Action                 req (MM_Req r);
   method ActionValue #(MM_Rsp)  rsp;
endinterface
```

Both methods are **guarded**: `req` blocks when you cannot accept a request,
`rsp` blocks when you have no response ready. The harness relies on that
back-pressure. Do not add explicit ready/valid signals.

There are four requests.

### `LoadA {row, chunk, word}` · `LoadB {row, chunk, word}`

Write one 32-bit slice into row `row` of `A` (or `B`). `chunk` selects which
slice, `word` carries `32 / W_ELEM` elements with **element 0 in the
low-order bits** — the order a little-endian RISC-V `lw` would deliver them.

At `W_ELEM = 8` a row of `A` is 4 elements = exactly 32 bits, so `chunk` is
always 0 and one load fills a whole row. That is a convenience of this shape,
not a property of the design; at `W_ELEM = 16` a row takes two loads.

### `Mul`

`C += A × B`, using whatever `A` and `B` currently hold. Signed. It accumulates —
it does not overwrite — so a sequence of `Mul`s with different operands sums
their products. That is what makes tiling work.

### `ReadC {row, chunk}` → one 32-bit word

Return one 32-bit slice of row `row` of `C`, **and zero the part of `C` it
returned.**

Reads are destructive. Reading all of `C` therefore leaves it zeroed and a fresh
accumulation begins with no separate reset instruction. `C` is zero after
hardware reset, so the very first accumulation starts clean too.

At `W_ACC = 32` one word is one element of `C`, so a row of `C` takes **four**
reads and the whole of `C` takes sixteen. Note the asymmetry with loads — it is
not a wart, and §8 asks what follows from it.

### Responses

**Every request returns exactly one response, in order.** Only `ReadC` sets
`has_value`; the others respond so that the response stream stays in lockstep
with the request stream. Lab 2 depends on that lockstep, so honour it even
though nothing in Lab 1 obviously needs it.

## 4 · What "correct" means

> **Your unit may do as much concurrently as you can make work, but the
> responses it produces must be identical to those of a unit that processed
> every request completely, one at a time, in order.**

That single sentence is the entire correctness condition, and it is worth
re-reading. It *permits* overlap — you are not required to finish one request
before starting the next. It *forbids* any overlap that is observable.

The interesting question is which overlaps are observable, and the answer
depends on decisions you have not made yet. A design that is correct when each
request takes one cycle can stop being correct when one of them takes several.

Overflow: the workloads are built so that no accumulation overflows `Int#(32)`.
If you overflow anyway, two's-complement wrapping is what the reference does.

## 5 · The two workloads

Both perform **exactly the same arithmetic** — 64 tiles, 4096 multiply-accumulates.
They differ only in how often results are read out.

| | epochs | `Mul`s per epoch | loads | `Mul`s | reads | **total requests** |
|---|---|---|---|---|---|---|
| **W1 — deep** | 1 | 64 | 512 | 64 | 16 | **592** |
| **W2 — shallow** | 32 | 2 | 512 | 64 | 512 | **1088** |

In W1 readout is 3% of the requests. In W2 it is 47%.

You report both, on purpose. **A design tuned for one may not be the best design
for the other**, and noticing why is a large part of what this lab is for.

A hint about where to look: in W1 there are always more loads waiting behind a
`Mul`. In W2 there is very often a *read* waiting behind one instead. Those are
not the same situation, and a design can be good at hiding one and bad at hiding
the other. If you find yourself wanting to special-case the two workloads, ask
instead what property of your design makes them differ.

## 6 · Two numbers, and neither one is the answer

Cycle count alone is a bad measure of a hardware design, because it says nothing
about **how long a cycle has to be**. A unit that does everything in one
enormous combinational sweep wins on cycles while being unbuildable at any
sensible clock rate — and Bluesim will never tell you, because it counts cycles
and knows nothing about time.

So you will report two numbers, from two tools:

```bash
make                                                   # cycles, W1 and W2
pip install --user 'yowasp-yosys==0.68.0.0.post1208'   # pinned; no sudo needed
make depth                                             # cells and logic_depth
# mkMatMul   cells=  113160   logic_depth=  71   area_x_delay=  8034360
```

Those are the numbers the starter you were given produces. They are your
baseline, not your target.

`logic_depth` is the number of gate levels on the longest combinational path —
an estimate of what sets your clock period. `cells` is a rough area count.

> **`logic_depth` is a proxy, not static timing analysis.** It counts gate
> levels and ignores gate and wire delay. It is deterministic and reproducible,
> which is what makes it useful for comparing *your own* designs against each
> other. Do not quote it in nanoseconds.

Two derived quantities are worth computing yourself:

| | what it estimates |
|---|---|
| `cycles × logic_depth` | **time to finish the job** — the thing a user cares about |
| `cells × logic_depth` | **cost of the hardware** — roughly, area × how slow it is |

### There is no single winner, and that is the assignment

We built and measured a spread of designs across this space before setting the
lab. What came out of it, and what you should expect to find yourself:

- the design with the **fewest cycles** had neither the fewest cells nor the
  lowest depth — it had the worst of both
- the design with the best **`cycles × depth`** was a third design again
- one design was beaten by another on **every column at once**. It was not a
  silly design. It was a reasonable-sounding idea that gives up area and depth
  and buys nothing back, and it is instructive precisely because the reasoning
  behind it sounds right until you measure it

Three metrics, three different winners. That is not a quirk of our particular
designs; it is the shape of the space.

We are deliberately not printing those numbers here. If you had them you would
aim at them, and the map you build yourself is the thing this lab is for.

### What you have to build

**At least three designs, and four if you can.** One of them may be the naive
starter you were given.

They have to be genuinely different, and what makes two designs different is
**what they compute in one cycle** — not variable names, and not a constant you
tuned. Two designs that do the same work per cycle are one design.

The axes worth moving, roughly in order of how much they change the numbers:

| axis | the question |
|---|---|
| **how much of the product one cycle computes** | all of it, or some slice of it — and *which* slice? There is more than one way to cut this work up, and they do not cost the same |
| **whether anything may proceed while a `Mul` runs** | and what state that costs you — see §4, and think before you build |
| **how `A` and `B` reach the arithmetic** | one copy, or more than one, and who is allowed to write which |

For each design, record W1 cycles, W2 cycles, `cells`, `logic_depth`, and the
two products above. Then sort the table by each column in turn.

If the ranking changes between columns, you have found the trade-off and you can
argue about it. **If one of your designs wins every column, you have not spread
them far enough apart** — go back and make one of them do substantially less per
cycle.

Your job is not to find "the best" design. It is to **map the trade-off with
your own designs and then argue for a choice**, given a stated priority.

## 7 · Building and measuring

What you are given:

| file | |
|---|---|
| `MatMul.bsv` | **your file** — ships as the naive design; edit it, replace it, rewrite it |
| `MM_Types.bsv` | the contract of §3. Do not modify for submission |
| `TbLab1.bsv` | the testbench, and the same one we grade with. Do not modify |
| `Makefile`, `area-delay.sh` | the two measurements of §6 |

```bash
make            # compile, run both workloads, check correctness, report cycles
make depth      # cells and logic_depth of mkMatMul
make schedule   # bsc's rule-conflict report -- see §8
make clean
```

`make` prints, per workload, the requests issued, the cycles taken, and the
difference between them:

```
  workload    requests   cycles   stalls   errors
  ----------  --------  -------  -------  -------
  W1 deep          592      593        1        0
  W2 shallow      1088     1089        1        0
```

`stalls` is `cycles - requests`: cycles in which your unit did not accept work.
The naive starter stalls once on each workload — the last response lands the
cycle after the last request, and that one is unavoidable. Anything much above
that is yours to account for, and §8 is where to start.

`TbLab1.bsv` is worth reading. It is the precise statement of what §4 means, and
it is more specific than prose can be.

**Correctness is checked first and it is absolute.** A fast wrong answer scores
nothing. This is not a formality — the most common way to lose correctness here
is by successfully making something faster.

One environment note that will otherwise cost you an hour: `yowasp-yosys` runs
in a sandbox that can only read files **at or below the current directory**. If
you point it at `/tmp` you will get "file not found" for a file that plainly
exists.

## 8 · Things to work out

These are not optional extras. They are the lab.

**Where do your cycles go?** W1 issues 592 requests. If your unit takes
substantially more than 592 cycles, something is stalling. What, and why? Count
before you optimise.

**What sets your longest path?** Look at what `Mul` computes as a single
expression and count the operations in series along one output. Which term
dominates — the multiply, or the summation over `K`?

Then be careful, because the obvious move is a trap. "Fewer multipliers" and
"shorter critical path" are different properties, and they do not always move
together. Of the natural ways to split this work across cycles, some cut the
path, some leave it exactly as long while using a quarter of the hardware, and
**at least one makes it longer than doing everything in a single cycle.** We
measured all three. Predict which is which before you build, then measure and
find out whether you were right — that prediction, and what it got wrong, is
worth writing up in your report.

**What happens when a `LoadA` arrives while a `Mul` is still in progress?** Work
out precisely what the sequential-order requirement of §4 demands here. There is
more than one legitimate answer and they cost different amounts.

**Why is W2 so much more expensive than W1, given identical arithmetic?** Put a
number on it. Then: if you could change the interface — which you cannot, but
if you could — what one change would help most? Real accelerators make exactly
that change; part 3 of the course explains why.

**How wide does the accumulator have to be?** Derive a bound on `W_ACC` in terms
of `W_ELEM`, `K`, and the number of `Mul`s per epoch. Then check: at `W_ACC =
16`, how many `Mul`s could you safely accumulate before reading out? This is why
the epoch structure exists.

**When BSV does not do what you expect.** If two rules that you believe should
run in the same cycle never do, bsc has already told you why — you just have not
looked. Run:

```bash
make schedule
```

and read the conflict report. It names the two rules and the exact resource they
contend for. bsc schedules **whole rules**, and that fact has consequences for
how you structure them. Working out those consequences is worth more than any
hint we could give you.

## 9 · After it works: other shapes

`MM_Types.bsv` is a contract for submission, but the shape parameters are
typedefs. Once the submitted configuration passes, change them and re-measure.

The constraint that makes shapes interesting: a row of `A` is `K × W_ELEM` bits,
and a word is 32. So `W_ELEM = 4` gives `K = N = 8` with rows still exactly one
word — an **8×8×8 unit using 4-bit operands**, doing 512 multiply-accumulates
per `Mul` instead of 64. `M` is independent of all this.

Try at least one alternative shape and report what happened to cycles, cells,
depth, and the ratio of arithmetic to data movement. Which shape gives the most
arithmetic per request, and is that the same one that gives the fewest cycles?

## 10 · Handing in

- `MatMul.bsv` (and anything it needs) implementing `mkMatMul` — your **chosen**
  design, which must be correct on both workloads
- `MM_Types.bsv` and `TbLab1.bsv`, unmodified
- `REPORT.md`, **three pages maximum**:

**The frontier.** At least **three** working designs of your own — four if you
can — in a table: W1 cycles, W2 cycles, cells, logic_depth, and the two derived
products from §6. One of them may be the naive starter. Say in one line what
each design does per cycle, and say which column each design wins.

**The argument.** Which would you ship, and why? Answer for two different
priorities — say, "this runs in a phone" versus "this runs in a datacentre" —
and if your answer is the same design both times, say what would have to change
for it not to be.

**Your reading of §8.** Briefly; a sentence or two each is often enough.

**One alternative shape from §9**, with numbers.

**What did not work.** A design you built that turned out worse than you
expected, and what the measurement told you that your reasoning had missed.
This is worth as much as the successes — say what you measured, not what you
hoped.

## 11 · Assessment

Deliberately light, and not a race.

The bar is: **correct on both workloads**, a frontier of at least three of your
own designs, and an argument that follows from your own numbers. A fourth design
that genuinely moves along one of the axes in §6 is worth more than a third page
of prose. Meeting that
with a clear report is a good mark.

There is no cycle target and no depth limit. A design that is slower but well
understood and honestly reported beats a faster one whose author cannot explain
it — and given that three different metrics pick three different winners,
"faster" is not even well defined until you say faster at what.

Class results will be published anonymised, as a scatter of cycles against
depth, so you can see the shape of the frontier everyone found together. That is
for interest and calibration. It is not the grade.
