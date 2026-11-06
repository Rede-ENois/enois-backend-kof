## What changes

<!-- 2 to 5 lines. Which domain, which endpoints, which Java reference. -->

Closes #<!-- issue of origin -->

## How it was verified

<!-- Proof, not promise -->

- `scripts/kof-test` → <!-- N/N -->
- Java tests ported for this domain → <!-- x/y, gaps listed in docs/PORTING_STATUS.md -->
- checked by hand: <!-- what -->

## Contract impact

<!-- Paths, JSON shape, nullability, enum spelling, status codes, error codes, pt-BR messages. -->

## Checklist

- [ ] One domain or one concern per PR — no unrelated refactor riding along
- [ ] Issue of origin referenced above
- [ ] `scripts/kof-test` green
- [ ] Every Java test of the touched domain ported, or a line in `docs/PORTING_STATUS.md` with the reason
- [ ] No weakened assertion, no hidden skip
- [ ] No stub, placeholder, TODO pretending to be done, or silent fallback
- [ ] Java interop only inside `src/kernel/**`
- [ ] No invented Kof API; a new compiler limit has a repro in `docs/KOF_GAPS.md`
- [ ] `AppWiring.kf` and `BootRoutesTest.kf` updated for a new module
- [ ] No secret, no personal data, no security-fix detail in public text
- [ ] `docs/PORTING_STATUS.md` updated
- [ ] Self-review done: read the `git diff` line by line and understand every line
- [ ] Kafka/HTTP contract unchanged: paths, JSON shape, nullability, enum spelling, status and error codes
- [ ] No invented Kof API; new limit documented with a repro
- [ ] Self-review done: read the `git diff` line by line and understand every line
- [ ] AI tools helped write this change (check if yes; no tool name or attribution line needed)
