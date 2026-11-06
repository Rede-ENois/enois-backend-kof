# How to contribute

This repository is the **big-bang rewrite of `enois-backend` (Java 25 / Spring Boot 4) into
[Kof](https://github.com/KofLang/Kof4j)**, JVM target. When it ships it replaces the Java service
behind the same gateway, on the same database, with the same HTTP contract. The front end must not
notice the switch.

Read [`AGENTS.md`](AGENTS.md) and [`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md) first. The operating
contract is there; this file is the short version for humans.

## Commands

```bash
export PATH="$HOME/.local/kof:$PATH"   # kof 0.7.1 (java -jar wrapper)
kof deps resolve                       # after editing kofdeps
scripts/kof-test                       # whole suite (H2, no network)
scripts/kof-test tests/feed            # one domain
scripts/kof-run                        # boot locally (H2 by default, PORT=8081)
kof fmt src -w && kof fmt tests -w     # canonical formatting before commit
```

`kof test` and `kof run` 0.7.1 cannot see the kofdeps jars or `src/` (KOF_GAPS G9/G10), so the
scripts drive the same compiler through its API.

## Definition of done for a ported domain

1. Read the Java domain end to end: controllers, DTOs, services, adapters, its tests.
2. Port models, store (SQL, same tables/columns), service, routes. Keep business rules identical,
   including limits, throttles, guards and pt-BR messages.
3. Port **every** MockMvc test of the domain to an HTTP-level Kof test. A test you cannot port gets a
   line in `docs/PORTING_STATUS.md` with the reason. **Never weaken an assertion.**
4. Cross-domain calls go through a small interface owned by the caller, wired in
   `src/app/AppWiring.kf`.
5. Update `docs/PORTING_STATUS.md` (domain, endpoints ported/total, tests ported/total, gaps).
6. Install the module in `AppWiring.kf` and add its representative route to
   `tests/integration/BootRoutesTest.kf`.
7. `kof fmt`, full suite green, atomic semantic commits in English.

## Pull request rules

A PR is only reviewed if it satisfies all six points.

1. **One domain or one concern per PR.**
2. **A ported test for every ported behaviour.** A test you cannot port gets a line in
   `docs/PORTING_STATUS.md`, never a weakened assertion.
3. **Documentation updated in the same PR** (`docs/PORTING_STATUS.md`, `docs/KOF_GAPS.md`).
4. **No comment narrating the obvious.**
5. **`scripts/kof-test` green before pushing.**
6. **An open issue with the implementation plan**, referenced by the PR.

Plus: the PR declares AI use through the template checkbox, and the merge needs approval from
someone who did not push the code.

## Kof rules

Idiomatic Kof first. Java interop only inside `src/kernel/**`. Measured compiler limits are in
section 4 of [`AGENTS.md`](AGENTS.md), each with a minimal repro in `docs/KOF_GAPS.md`. When you hit
a new bug: write the smallest repro, document it, apply the workaround inside the kernel when
possible, move on. **Never silence a failure and never invent an API.**

## Contributing with AI

1. **Declare the use** through the PR template checkbox. No tool name, no `Co-Authored-By`, no
   "Generated with" line.
2. **Whoever submits answers for the code.** Read the diff line by line.
3. **Proof, not promise.** Run `scripts/kof-test` and describe the result.
4. **Zero slop.** No comment narrating the obvious, no mass-generated files, no speculative
   abstraction, no refactor the task did not ask for.
5. **No invented Kof.** Verify every API in the Kof4j source.
6. **Port, do not paraphrase.** Business rules, limits, guards and pt-BR messages are copied
   behaviour.
7. **Human review before merge remains the rule.**
