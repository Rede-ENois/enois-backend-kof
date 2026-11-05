# enois-backend-kof

The Énóis social network backend, written in **[Kof](https://github.com/KofLang/Kof4j)** and running on the JVM.

This is a full rewrite of `enois-backend` (Java 25, Spring Boot 4). The goal is a **drop-in replacement**: same
gateway, same MariaDB/MySQL database, same HTTP contract. The front end must not notice the switch.

```
 50 domains     642 Java routes -> 640 one-to-one + 2 through the binary lane
 84k lines .kf  333 test files, ~2300 tests, all green on H2 (MySQL mode)
 215 Flyway migrations, byte-identical to the Java repo
```

---

## Contents

- [Why this exists](#why-this-exists)
- [Status](#status)
- [Quick start](#quick-start)
- [Architecture](#architecture)
- [Request pipeline](#request-pipeline)
- [Domains](#domains)
- [Configuration](#configuration)
- [Testing](#testing)
- [Writing Kof here](#writing-kof-here)
- [Deploying](#deploying)
- [Documentation map](#documentation-map)
- [Contributing](#contributing)
- [License](#license)

---

## Why this exists

Kof is a young language with a JVM target (KofLang/Kof4j). This repo ports a real, large production backend to
Kof. It checks that Kof can run the whole platform, and it records every place where the compiler or runtime still
falls short. Each one has a minimal repro in [`docs/KOF_GAPS.md`](docs/KOF_GAPS.md) and goes back upstream.

The port was a **big bang**: every domain was rewritten. The Java code is the behaviour reference, and **the Java
tests are the spec**. Every MockMvc assertion in the Java suite has an HTTP-level Kof test here. When a Java test
could not be ported, the reason is written down.

## Status

| Area | State |
|---|---|
| Domains | All 50 ported, wired in one production composition (`src/app/AppWiring.kf`) |
| HTTP contract | Route parity audited by script: 640 of 642 Java mappings registered one to one; the 2 `GET\|PUT /storage/{key}` are served by the binary lane on purpose |
| Java tests | Ported or listed with a reason in [`docs/PORTING_STATUS.md`](docs/PORTING_STATUS.md) |
| Cross-domain seams | Every seam calls the owner's real API, or is kept as its own query for the reason in [`docs/SEAMS.md`](docs/SEAMS.md) |
| Database | Same schema, same `flyway_schema_history`: Java and Kof can take turns on one database |
| Compiler gaps | 185 recorded with repro and workaround, several already fixed upstream |

Before production, still to do:

- a security review of the hand-written JWT in `kernel/security/Jwt.kf`;
- a shadow run against a copy of the production database;
- the [deploy checklist](#deploying).

## Quick start

Requirements: JDK 25 and the Kof 0.7.1 CLI (`kof-cli-0.7.1.jar` with its `kof` wrapper in `~/.local/kof`).

```bash
export PATH="$HOME/.local/kof:$PATH"

kof deps resolve                       # fetch the jars listed in kofdeps
scripts/kof-run                        # boot on :8081 with an in-memory H2 database
curl -s localhost:8081/health          # {"status":"UP",...}

scripts/kof-test tests/feed            # one domain
scripts/kof-test                       # the whole suite (~20 min, 3 files in parallel)
```

The app needs `REDE_SECURITY_ENCRYPTION_KEY` set to boot; any non-empty value is enough for local runs. To run on a
real MariaDB, set `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER` and `DB_PASSWORD`, or a full `DB_URL`. The migrations run
at boot.

> Why scripts and not `kof run` / `kof test`? Kof 0.7.1 neither puts the `kofdeps` jars on the classpath (G9) nor
> resolves imports from `src/` (G10). `scripts/KofTool.java` drives the same compiler through its API, with the jars
> attached.

## Architecture

```
                         gateway (strips /api)
                                  |
                                  v
  +--------------------- public port (PORT) ----------------------+
  |  BinaryFront   byte-level front: media, multipart, storage     |
  |                bodies stream here; the rest goes to the runtime |
  +-----------------------------+----------------------------------+
                                | loopback only
                                v
  +----------------------- Kof web runtime ------------------------+
  |  kernel.http      filter chain, routes, cookies, SSE            |
  |  kernel.security  sessions, CSRF, CORS, limiters, guards, audit  |
  |                                                                  |
  |  <domain>Routes -> <domain>Service -> <domain>Store              |
  |        feed, identity, profile, groups, moderation, ... (50)     |
  |                                                                  |
  |  kernel.db (HikariCP + JDBC)   kernel.jobs   kernel.outbox       |
  |  ops.MailService (SMTP)        kernel.storage (S3 / local)       |
  +-------------------------------+----------------------------------+
                                  |
                                  v
                     MariaDB / MySQL (Flyway)
```

### Layout

```
src/
  Main.kf              config -> Platform.create -> AppWiring.install -> listen
  app/                 AppWiring (the only production composition) and the cross-domain bridges
  kernel/              the platform layer: the ONLY place that imports Java or third-party APIs
  <domain>/            <Domain>Model, <Domain>Store, <Domain>Service, <Domain>Routes, <Domain>Module
tests/
  <domain>/            HTTP-level suites against a booted app on H2
  integration/         boots the exact production wiring (BootRoutesTest, seam and wiring tests)
resources/
  db/migration/        Flyway migrations, copied verbatim from the Java repo
  templates/ fonts/ cosmetics/ emotes/ dailygames/ security/
scripts/               kof-test, kof-run and the Java helpers that drive the Kof compiler
docs/                  kernel API, porting status, seams, compiler gaps
```

### Principles

- **The kernel is the only place that touches Java.** Domains see small Kof APIs (`Db`, `Req`, `Http`,
  `Outbound`, `Jobs`, `MailService`). Kof's Java interop still has sharp edges (overloads, varargs, primitive fields),
  so keeping it in one folder keeps every workaround in one place, with a test proving it works.
- **One module per domain.** `<Domain>Module.install(platform, ...)` registers routes, filters and jobs, and returns the
  services other domains may use.
- **Explicit wiring, no container.** `src/app/AppWiring.kf` builds every module in dependency order. `Main.kf` and the
  integration tests call the same function, so the tests boot exactly what production boots.
- **Caller-owned seams.** When feed needs something from profile, feed declares a small class with the methods it needs,
  and the wiring passes a subclass backed by the profile module. Domains never read another domain's tables.
- **Never silence a failure.** Workarounds are named after their gap number, so they can be removed when Kof fixes the
  bug.

## Request pipeline

Each request goes through filters in the same order as the Spring security chain it replaces (the full table, with the
Java filter behind each one, is in [`docs/KERNEL.md`](docs/KERNEL.md#filter-order-java---kof)):

```
BinaryFront             binary and multipart paths are streamed here; the rest is forwarded
request-observability   request id, log context, access line
panic-mode              429 PANIC_MODE on writes while panic is on
path-guard              400 on a malformed escape
fallback-surface        unknown path: 200 with an empty body (anti-enumeration)
origin-gate             trusted origins, preflight, third-party CORS
session-csrf            X-CSRF-Protection: 1 on cookie-authenticated writes
abuse-guard             timed denial for error scanners
rate limits             global, identity, public reads, posts
duplicate-post          replays the answer of an identical in-flight POST
security headers        headers, cache control, weak ETag on public reads
cors                    credentialed grants
admin / write gates     /admin/** needs an admin or moderator; writes need a session
route handler           sessions via Bearer or cookie, idempotency, the domain service
method-not-allowed      405
```

Contract details kept from the Java service:

- Errors are `{"code":"CODE","message":"pt-BR message","timestamp":"..."}`, with the same status and code.
- Sessions are opaque tokens stored in the database. The cookies are `enois_session` and `enois_refresh`, with the same
  SameSite and TTLs.
- Unknown routes answer `200` with an empty body. This is why `BootRoutesTest` asserts a real answer for one route of
  every module.

### BinaryFront

The Kof runtime handles text bodies only (G161). Media uploads, multipart forms and storage proxying need raw bytes.
`kernel.http.BinaryFront` owns the public socket:

- it streams claimed paths itself: it authorizes, spools to disk, then commits;
- it forwards everything else, untouched, to the runtime on a loopback port.

The loopback port is never published. Server-Sent Events go through the front as well.

## Domains

| Group | Domains |
|---|---|
| Identity and people | `identity`, `age`, `onboarding`, `profile`, `preferences`, `presence`, `network`, `themes` |
| Content | `feed`, `media`, `gifs`, `emotes`, `blog`, `search`, `notices`, `releasenotes` |
| Community | `communities`, `communityprojects`, `groups`, `studypairs`, `events`, `projects` |
| Conversation | `messaging`, `calls`, `notifications`, `push` |
| Economy | `coin`, `cosmetics`, `marketplace`, `services`, `economy`, `games`, `dailygames` |
| Work | `jobs`, `importlinkedin`, `importresume`, `linkedin`, `companies`, `corporate`, `mentoring`, `freelances` |
| Open source | `contributions`, `contributors`, `githubprofile`, `suggestions` |
| Trust and safety | `moderation` (reports, sanctions, appeals, moderator panel, AI triage, automated barriers), `support` |
| Platform | `ops` (mail, monitoring), `apiv1`, `stats`, `leaves` |

Each domain has a section in [`docs/PORTING_STATUS.md`](docs/PORTING_STATUS.md) with its endpoints, ported tests,
deliberate differences and gaps.

## Configuration

Everything comes from environment variables. The names and defaults are the same as in the Java
`application.properties`, so a Java deployment's env file works as is. The main ones:

| Variable | Purpose |
|---|---|
| `PORT` | Public port (default `8081`) |
| `DB_URL` or `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD` | Database (default in-memory H2) |
| `DB_POOL_MAX`, `DB_POOL_MIN_IDLE` | HikariCP pool |
| `REDE_SECURITY_ENCRYPTION_KEY` | **Required.** Encrypts stored secrets (tokens, keys) |
| `FRONTEND_URL` | Links in e-mails and the trusted origin |
| `MAIL_HOST`, `MAIL_PORT`, `MAIL_USERNAME`, `MAIL_PASSWORD`, `MAIL_SMTP_*` | SMTP for verification and notification e-mails |
| `SUPPORT_EMAIL` | Sender and inbox of the support flow |
| `REDE_MEDIA_STORAGE`, `REDE_MEDIA_S3_*`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` | Media storage (S3-compatible or local) |
| `REDE_BINARY_MAX_BODY_BYTES` | Upload cap of the binary lane (default 520 MB, like Spring) |
| `VAPID_PUBLIC_KEY`, `VAPID_PRIVATE_KEY`, `VAPID_SUBJECT` | Web push |
| `GITHUB_CLIENT_ID`, `GITHUB_CLIENT_SECRET`, `GITHUB_*` | GitHub OAuth, contribution sync, support issues |
| `MODERATION_LLM_BASE_URL`, `MODERATION_LLM_API_KEY`, `MODERATION_LLM_MODEL` | AI report triage (off without a key) |
| `MODERATION_*`, `REDE_MODERATION_*` | Moderation automations, thresholds and quorums |
| `PANIC_MODE` | Emergency switch: blocks writes with `429 PANIC_MODE` |

Domain-specific keys are listed in each domain's section of `docs/PORTING_STATUS.md`.

## Testing

```bash
scripts/kof-test                                   # everything
scripts/kof-test tests/moderation tests/feed       # some domains
scripts/kof-test tests/integration/BootRoutesTest.kf
```

- **No network, no real database.** Each suite boots the app on an ephemeral loopback port with its own in-memory H2
  database in MySQL mode, migrated by the real Flyway files. Outbound HTTP (GitHub, LLM, link previews) goes through
  overridable classes. Tests either stub them or point them at a local stand-in server.
- **HTTP-level.** Tests send real requests through the whole filter chain and assert status, JSON and side effects in
  the database, the same way the Java MockMvc tests did.
- **Production wiring.** `tests/integration` boots `AppWiring` itself. `BootRoutesTest` fails as soon as a module's
  route falls through to the unknown-route fallback.
- **Runner.**
  - Each test file is compiled and run in its own JVM, `KOF_TEST_JOBS` at a time (default 3).
  - A machine-wide slot lock (`KOF_TEST_SLOTS`) keeps parallel checkouts from overloading the machine.
  - A suite that hangs is killed after `-Dkof.suite.timeout` seconds (default 900).

Test helpers live in `kernel.testkit`: `TestApp`, `TestClient`, `Check`, `MailCapture`, `FakeSmtpServer` and the
per-domain test kits. They are described in [`docs/KERNEL.md`](docs/KERNEL.md#testing-kerneltestkit).

## Writing Kof here

The rules are in [`AGENTS.md`](AGENTS.md); read it before your first change. The ones that bite most:

1. Java and third-party imports only inside `src/kernel/`.
2. Use `kernel.db`, never the stdlib `db.query` (it allows at most 4 bind parameters and one connection).
3. Type names are global: prefix them with the domain (`FeedPost`, `GroupMember`), never a bare `Item`.
4. Static fields share one namespace with the module: name them after their owner (`authUserSlot`, never `seen`).
5. Never name a variable `db`, `query`, `transaction`, `entity` or `unique`.
6. No `finally` after a rethrow: catch, release, rethrow.
7. Cross-package interfaces cannot be implemented yet: seams are concrete classes, subclassed with `extends`.
8. Write `(a as Long) * b`, never `a as Long * b`: the cast binds looser than you think.
9. Run `kof fmt` only on files that compile, and only on your own folders. On a broken tree it rewrites unrelated
   files.

Found a new compiler or runtime bug?

1. Write the smallest repro.
2. Add it to `docs/KOF_GAPS.md` with symptom, repro and workaround.
3. Put the workaround in the kernel when you can, and move on.

## Deploying

The service is one JVM process. Checklist for replacing the Java service:

- [ ] JDK 25 runtime; build the classes with `scripts/KofTool.java` and ship them with the `kofdeps` jars and `resources/`.
- [ ] Same env file as the Java service, plus `REDE_SECURITY_ENCRYPTION_KEY`.
- [ ] `MAIL_*` set; without them, no verification e-mail leaves the server.
- [ ] `resources/cosmetics/catalog.json` shipped next to the app.
- [ ] Only `PORT` published; the runtime's loopback port must stay private.
- [ ] Flyway runs at boot against the same `flyway_schema_history`; take a database backup first.
- [ ] Shadow traffic, or a staging run on a production copy, before the switch; keep the Java image ready to roll back.

## Documentation map

| File | What is inside |
|---|---|
| [`AGENTS.md`](AGENTS.md) | The contract: what must not change, Kof rules, definition of done, git rules |
| [`docs/KERNEL.md`](docs/KERNEL.md) | Kernel API reference: db, http, security, jobs, mail, storage, testkit |
| [`docs/PORTING_STATUS.md`](docs/PORTING_STATUS.md) | Per domain: endpoints, tests ported, deliberate differences; route parity and totals |
| [`docs/SEAMS.md`](docs/SEAMS.md) | Every cross-domain seam and how it is wired |
| [`docs/KOF_GAPS.md`](docs/KOF_GAPS.md) | Every compiler/runtime gap found, with repro and workaround |
| [`docs/PORTING_GUIDE.md`](docs/PORTING_GUIDE.md) | How a domain was ported (worktrees, module shape, tests) |

## Contributing

- Use one `git worktree` and branch per task (`port/<domain>`, `fix/<topic>`). Never run the suite in a checkout someone
  else is using.
- Use Conventional Commits in English. Keep them atomic. No AI attribution lines.
- Every behaviour change ships with its HTTP-level test and its docs.
- Security rules are non-negotiable ([`AGENTS.md` §7](AGENTS.md#7-security-rules-inherited-non-negotiable)): never
  weaken a control to make a test pass, keep PII out of logs, and read secrets only from env vars.

## License

[GNU GPL v3](LICENSE).
