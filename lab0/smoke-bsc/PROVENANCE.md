# Provenance

These four files are copied **verbatim** from the Bluespec compiler's own
repository, so that Lab 0 works without cloning all of `bsc` (~200 MB):

- Upstream: <https://github.com/B-Lang-org/bsc/tree/main/examples/smoke_test>
- Files: `FibOne.bsv`, `Makefile`, `mkFibOne.out.expected`, `.gitignore`
- Copied at commit `083dcb67143e9e912fb1d2d7a7755d8bd094d92d` (2026-08-27)
- License: BSD-3-Clause, (c) Bluespec, Inc. — see the upstream `LICENSE.txt`

Nothing here has been modified. If you would rather run the original in place:

```bash
git clone https://github.com/B-Lang-org/bsc
cd bsc/examples/smoke_test && make smoke_test
```
