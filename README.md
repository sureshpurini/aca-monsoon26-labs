# Labs — Advanced Computer Architecture (CS2.501)

**Monsoon 2026 · IIIT Hyderabad**
Instructors: Priyesh Shukla · Suresh Purini

Starter code and handouts for the hands-on part of the course. Everything here
is meant to be **cloned and built**, not just read:

```bash
git clone https://github.com/sureshpurini/aca-monsoon26-labs
cd aca-monsoon26-labs/lab0
```

New labs are added during the semester — `git pull` before starting each one.

| Lab | What you do | Status |
|---|---|---|
| [**lab0**](lab0/) — Get the toolchain working | Install `bsc` and Verilator; run three smoke tests, ending with the Fife CPU booting on your machine | Ready |
| lab1 | — | Later |
| Mini-project — a matmul accelerator as a RISC-V extension | Extend **Fife**, the pipelined RV32I CPU, with a custom matrix-multiply instruction | Later |

Start with **[lab0](lab0/)**. It has no prerequisites and it is what every later
lab assumes. The 2×2 matrix multiply you build there is deliberately the seed of
the mini-project's accelerator.

## What you will need

A Linux or macOS machine (Windows works through WSL2). No FPGA, no licence, and
no Bluespec Inc. account — the compiler has been free and open source since 2020.
Lab 0 walks through the whole install.

## Related

- **[Course site](https://sureshpurini.github.io/aca-monsoon26-web/)** — schedule, slides, readings, logistics
- **[Drum/Fife code walkthrough](https://sureshpurini.github.io/drum-fife-walkthrough)** — clickable cross-reference for the two CPUs
- **[Learn Bluespec and RISC-V Design](https://github.com/rsnikhil/Learn_Bluespec_and_RISCV_Design)** — Nikhil's textbook and the Drum/Fife sources
- **[The `bsc` compiler](https://github.com/B-Lang-org/bsc)** — releases, reference manuals, issue tracker

## A note on what lives here

This repository is public and holds only student-facing material. Solutions,
grading scripts, and exams are elsewhere. Course announcements and submissions
go through **Moodle**, not through GitHub issues.

Bug in a handout or a Makefile? An issue or a pull request here is welcome.
