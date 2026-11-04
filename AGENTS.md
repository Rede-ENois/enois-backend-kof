# AGENTS.md

Operational contract for every agent (human or AI) working on `enois-backend-kof`.

This repository is the **big-bang rewrite of `enois-backend` (Java 25 / Spring Boot 4) into
[Kof](https://github.com/KofLang/Kof4j)**, JVM target. When it ships it replaces the Java
service behind the same gateway, on the same MariaDB/MySQL database, with the same HTTP contract.
The front end must not notice the switch.

## 1. Source of truth

- **Behaviour reference:** the Java service at `origin/qa`, checked out read-only at
  `/Users/fabiohr/Projects/enois/.worktrees/backend-ref`
  (`src/main/java/com/socialcoisa/rede/<domain>`). Never edit it.
- **The Java tests are the spec.** `src/test/java/com/socialcoisa/rede/<domain>` (MockMvc) define
  status codes, JSON shapes, error codes and edge cases. Every behaviour asserted there must be
  asserted by an HTTP-level Kof test here.
- **Domain docs:** `backend-ref/docs/` (`API.md`, `MODULES.md`, `SECURITY.md`, `DATABASE.md`, ...).

## 2. Contract that must not change

- **Paths:** served from the root (the gateway strips `/api`). `/api/v1/*` is an alias of `/api/*`
  (see `apiv1/V1AliasFilter`).
- **JSON:** same field names, same nullability, same date format, same enum spelling. Compare with
  the Java DTO records field by field.
- **Errors:** `ApiException(status, "CODE", "mensagem pt-BR")` becomes
  `{"code":"CODE","message":"...","timestamp":"..."}` with the same status. Controllers that use the
  `ApiResponse<T>` envelope keep the envelope. Error codes and pt-BR messages are part of the contract.
- **Auth:** opaque server-side session tokens (DB lookup), `Authorization: Bearer` or the HttpOnly
  cookies with the same names, SameSite and TTLs. CSRF: `X-CSRF-Protection: 1` on cookie-authenticated
  writes.
- **Unknown routes answer 200 with an empty body** (anti-enumeration, `FallbackSurfaceFilter`).
- **Writes honour `Idempotency-Key`** exactly as the Java service does.
- **Database:** the schema is owned by the Flyway migrations in `resources/db/migration`, copied
  verbatim from the Java repo. **Never edit an applied migration.** New schema changes get a new
  `V<n>__*.sql`, using MariaDB/MySQL syntax that also runs on H2 in MySQL mode. Flyway runs at boot
  (kernel), so `flyway_schema_history` stays compatible with the Java service.

## 3. Layout

```
src/
  Main.kf                      composition root: config, db, migrations, wiring, routes, jobs, listen
  kernel/                      platform layer: the ONLY place allowed to import Java/third-party APIs
    db/ http/ config/ jobs/ security/ ...
  <domain>/                    one folder per Java domain package (feed, identity, profile, ...)
    <Domain>Model.kf           records, enums, pure rules
    <Domain>Store.kf           SQL through kernel/db
    <Domain>Service.kf         use cases (transactions, guards, events)
    <Domain>Routes.kf          HTTP adapter: register(app, deps), request parsing, JSON mapping
tests/
  <domain>/*.kf                `test "..." { }` suites, HTTP-level against a booted app on H2
resources/                     migrations, templates, catalogs (copied from the Java repo)
```

Packages: `package kernel.db`, `package feed`, ... **Type names are globally unique**: prefix with
the domain (`FeedPost`, `GroupMember`, `ProfileView`), never a bare `Item`/`Request`/`Response`.

## 4. Kof rules (best practices + measured compiler limits, Kof 0.7.1)

Idiomatic Kof first: `record` for data, `class` only for stateful services, `listOf/mapOf/setOf`,
`map/filter/reduce`, `String?` with narrowing, `switch` with pattern matching, `test "..." {}`.
No annotations, no reflection, no DI container: wiring is explicit constructor calls in `Main.kf`.

Measured limits (each one has a minimal repro in `docs/KOF_GAPS.md`):

1. **Java interop only inside `src/kernel/**`.** Overload resolution is unreliable
   (`FluentConfiguration.configuration(Map)` picked the `Configuration` overload), **Java varargs
   produce a `VerifyError`**, and **reading a public primitive field of a Java object produces a
   `VerifyError`**. Each kernel adapter that touches Java has a test proving it loads and runs.
2. **Do not use `db.query/db.execute` from the stdlib**: max 4 bind params, single connection.
   Use `kernel.db` (HikariCP pool + JDBC, unlimited typed binds, transactions).
3. **Collections are homogeneous**: `listOf<Object>(1L, "x")` is rejected (SEM056).
4. **`Map.get` returns `T?`**: narrow before use. `Map<_, Bool>.get` returns `Troolean`: compare with
   `== true`.
5. Qualified Java names are not receivers: `import java.x.Y` then `Y.call()`.
6. **One `main()` per module directory.** Probes and scratch programs live outside `src/`.
7. `kof check` does not see `kofdeps` jars; validate with `scripts/kof-test`/`scripts/kof-run`.
8. **Static fields and top-level names share one namespace with every field/variable of the module
   (G35):** a static `seen` in the kernel broke tests that had their own `seen`. Name static fields
   uniquely after their owner (`responseHeadersSlot`, `authUserSlot`), never `seen`/`values`/`count`.
9. Never name a variable `db`, `query` or `transaction` (G17); call your own methods with `this.`.
10. No `finally` after a rethrow (G12): capture the failure, release resources, then rethrow.
11. Interfaces from another package cannot be implemented (G30) and lambdas returning another
    package's class fail (G33): cross-domain seams are concrete classes with overridable no-op
    methods, subclassed with `extends`.

When you hit a new compiler/runtime bug: write the smallest repro, add it to `docs/KOF_GAPS.md`
(symptom, repro, workaround), apply the workaround **inside the kernel when possible**, move on.
Never silence a failure.

## 5. Commands

```bash
export PATH="$HOME/.local/kof:$PATH"          # kof 0.7.1 (java -jar wrapper)
kof deps resolve                               # after editing kofdeps
scripts/kof-test                               # whole suite (H2, no network)
scripts/kof-test tests/feed                    # one domain
scripts/kof-run                                # boot locally (H2 by default, PORT=8081)
kof fmt src -w && kof fmt tests -w             # canonical formatting before commit
```

`kof test` and `kof run` 0.7.1 cannot see the kofdeps jars or `src/` (KOF_GAPS G9/G10), so the
scripts drive the same compiler through its API. The kernel API is documented in `docs/KERNEL.md`.

Tests never touch the network or a real database: H2 in MySQL mode with the real migrations,
unique-prefix fixtures, an ephemeral port per suite.

## 6. Porting a domain (definition of done)

1. Read the Java domain end to end: controllers, DTOs, services, adapters, its tests.
2. Port models, store (SQL, same tables/columns), service, routes. Keep business rules identical,
   including limits, throttles, guards and pt-BR messages.
3. Port **every** MockMvc test of the domain to an HTTP-level Kof test. A test you cannot port gets
   a line in `docs/PORTING_STATUS.md` with the reason. Never weaken an assertion.
4. Cross-domain calls go through a small interface owned by the caller
   (`interface FeedProfileLookup { ... }`), implemented by the other domain and wired in
   `Main.kf`. Never reach into another domain's tables from your store.
5. Update `docs/PORTING_STATUS.md` (domain, endpoints ported/total, tests ported/total, gaps).
6. `kof fmt`, full suite green, atomic semantic commits in English.

## 7. Security rules (inherited, non-negotiable)

- Never disable or weaken a security control to make a test pass.
- Hot-path guards (filters, limiters, attempt counters): no per-request DB query without cache and
  per-IP quota; attempt limits are claimed atomically (`UPDATE ... WHERE attempts < N`) before
  checking the code.
- Sanitising migrations use explicit denylists, never allowlists with regex exceptions.
- No PII in logs. Secrets only from env vars. Commit messages never describe security fixes.

## 8. Git

- Several agents work in parallel: each one works in its own `git worktree` and branch
  (`port/<domain>`). Never run the suite in a checkout another process is using.
- Commits: English, Conventional Commits, atomic. No AI attribution lines of any kind.
- Scout rule: a broken test, build or lint you find is fixed in the same task, or registered in
  `docs/PORTING_STATUS.md` and called out in the PR.
