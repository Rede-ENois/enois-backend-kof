# Kernel API

The platform layer in `src/kernel/**`. Domain code (`src/<domain>/`) codes against this document and
never imports Java or third-party packages. Everything below is covered by `tests/kernel/`.

Run things with the scripts (the stock `kof test` / `kof run` cannot see the kofdeps jars or `src/`,
see `docs/KOF_GAPS.md` G9/G10):

```bash
scripts/kof-test                       # whole suite
scripts/kof-test tests/kernel          # one folder or file
PORT=8081 scripts/kof-run              # boot the app (in-memory H2 unless DB_* is set)
kof fmt src -w && kof fmt tests -w
```

## Conventions that bite

- Exceptions are Strings. A domain error is `throw Errors.api(404, "CODE", "mensagem pt-BR")`.
- Function names are one flat namespace: kernel utilities are `static` methods of classes
  (`Config`, `Time`, `Req`, `Cookies`, `Http`, `Errors`, ...). Domain functions need unique names.
- Do not name a variable `db` (it shadows the stdlib `db` namespace inside lambdas): use `database`
  or `store`. Call your own methods with `this.` when the name matches a stdlib builtin
  (`query`, `transaction`, `status`, ...).
- No generics on class methods and no generic function types: no `transaction<T>`; see `Db` below.
- Reserved words: `long int bool double fn` cannot be method names.
- Instants are ISO-8601 UTC strings (`2026-11-04T16:05:00.123456Z`), dates `yyyy-MM-dd`.

## kernel.config

```kotlin
import kernel.config.*

var cfg = Config.env()                          // process environment
var test = Config.of(mapOf("DB_URL", "..."))    // overrides on top of the environment
cfg.getStr("FRONTEND_URL", "http://localhost:5173")
cfg.getInt("DB_POOL_MAX", 30)     cfg.getLong(k, 1L)     cfg.getBool(k, false)
cfg.required("REDE_SECURITY_ENCRYPTION_KEY")    // throws "CONFIG_MISSING: ..." (fail fast at boot)
cfg.requiredInt(k)   cfg.lookup(k): String?   cfg.has(k)
```

Blank values count as unset. Bad numbers/booleans throw `CONFIG_INVALID: KEY must be ...`.
Env names mirror the Java app (`application*.properties`).

## kernel.error

```kotlin
import kernel.error.*

throw Errors.api(409, "EMAIL_TAKEN", "E-mail ja cadastrado.")     // ApiException(status, code, message)
throw Errors.apiRetry(429, "RATE_LIMITED", "...", 30L)            // + Retry-After: 30
throw Errors.badRequest()      // 400 BAD_REQUEST  "Requisicao invalida."
throw Errors.conflict()        // 409 CONFLICT     "Operacao conflita com o estado atual dos dados."
Errors.hasCode(e, "CONFLICT")  // in a catch (String e): was it that ApiError?
Errors.parse(e): ApiError      // record ApiError(status, code, message, retryAfterSeconds)
```

Anything else thrown (a plain String, a Java exception) is an unexpected failure: logged, answered as
`500 {"code":"INTERNAL_ERROR","message":"Erro interno inesperado."}` with no internals.

## kernel.db

```kotlin
import kernel.db.*

var database = platform.db        // Db (HikariCP + JDBC). Domain stores receive it by constructor.
```

Binds are positional and unlimited, built with `DbParams`:

```kotlin
DbParams().bindLong(id).bindStr(name).bindInt(n).bindBool(true).bindDouble(1.5)
          .bindInstant("2026-11-04T16:05:00Z")      // stored as the UTC TIMESTAMP, like Instant in Java
          .bindInstantMillis(ms)  .bindDate("2026-11-04")
          .bindLongOrNull(x)  .bindIntOrNull(x)  .bindStrOrNull(x)  .bindInstantOrNull(iso)  .bindDateOrNull(d)
          .bindNullBool()                           // Bool? has no Kof type: SQL NULL for a boolean column
```

Statements:

```kotlin
database.execute(sql, params): Int                       // rows affected
database.insertReturningId(sql, params): Long            // generated auto-increment key
database.queryList(sql, params): List<DbRow>
database.queryOne(sql, params): DbRow                    // exactly one row or throws
database.queryOptional(sql, params): DbRow?
database.queryLong(sql, params): Long                    // first cell, e.g. count(*) (0 when no row)
```

Rows are snapshots; map them with the list functions:

```kotlin
var posts = database.queryList("select id, text, created_at, edited_at from posts where user_id = ?",
                               DbParams().bindStr(userId))
                    .map((r: DbRow) -> FeedPost(r.getStr("id"), r.getStr("text"), r.getInstant("created_at"), r.getInstantOrNull("edited_at")))
```

`DbRow` getters (column labels are case-insensitive): `getStr getLong getInt getDouble getBool
getInstant getDate` (throw when NULL) and `getStrOrNull getLongOrNull getIntOrNull getInstantOrNull
getDateOrNull`, plus `isNull(col)` / `has(col)`. A boolean-nullable column: `r.isNull(c)` then `getBool`.
Binary columns are not supported yet (rows are text snapshots).

Transactions bind one connection to the current virtual thread; stores called inside reuse it. Nested
`transaction` calls join the outer one. A thrown String rolls back and is rethrown.

```kotlin
database.transaction(() -> {
    var row = database.queryOne("select balance from wallets where id = ? for update", DbParams().bindStr(w))
    database.execute("update wallets set balance = ? where id = ?", DbParams().bindLong(row.getLong("balance") - 5L).bindStr(w))
})
var newId = 0L                                  // value out: capture it ...
database.transaction(() -> { newId = database.insertReturningId(sql, p) })
var id = database.txLong(() -> database.insertReturningId(sql, p))   // ... or txLong / txStr / txBool
database.inTransaction(): Bool
```

After-commit hooks (`@TransactionalEventListener(AFTER_COMMIT)`): `database.afterCommit(() -> { ... })`
inside a transaction runs the callback only after the outermost commit (dropped on rollback, in
registration order, after the connection is back in the pool, so it may use the database again).
Outside a transaction it runs immediately. A callback that throws is logged (`after_commit_failed`)
and does not stop the others nor undo the commit.

Constraint violations (unique, FK, NOT NULL, data too long) become `Errors.conflict()` (409 CONFLICT),
like `DataIntegrityViolationException`. Other SQL failures are logged and thrown as `SQL_ERROR: ...`
(500 at the edge). Connections are always returned to the pool, including on failure.

Settings (`DbSettings`): `DB_URL` wins; else `DB_HOST` (+`DB_PORT` 3306, `DB_NAME` socialcoiso,
`DB_USER` socialcoiso, `DB_PASSWORD` required) builds
`jdbc:mariadb://host:port/name?sslMode=DISABLED&serverTimezone=UTC`; with neither, the Java dev/test
URL `jdbc:h2:mem:rede;MODE=MySQL;DB_CLOSE_DELAY=-1` (user `sa`). Pool: `DB_POOL_MAX` (30),
`DB_POOL_MIN_IDLE` (10), 10 s connection timeout, 10 min max lifetime.

H2 stores quoted `flyway_schema_history` lower-case: query it as `"flyway_schema_history"`. Write
domain SQL unquoted and in MariaDB syntax that H2 MySQL mode also accepts.

### Migrations

`Migrations.migrate(cfg, url, user, password): MigrationSummary(applied, pending, failed, last)` runs
at boot inside `Platform.create`: repairs FAILED markers, then migrates. Profile from
`SPRING_PROFILES_ACTIVE` (default `dev`): `qa`/`hml`/`prd` use `out-of-order=true`,
`validate-on-migrate=false`; dev and tests are strict. Overrides: `SPRING_FLYWAY_OUT_OF_ORDER`,
`SPRING_FLYWAY_VALIDATE_ON_MIGRATE`. Location: `MIGRATIONS_DIR` (default
`filesystem:resources/db/migration`, relative to the working directory). All 215 migrations apply on
H2 unchanged.

## kernel.http

`Platform` wires everything; `Main.kf` and tests create it, register routes on `platform.server`,
then start it.

```kotlin
var platform = Platform.create(Config.env())    // config -> pool -> Flyway -> HttpServer + /health + /version
FeedRoutes.register(platform.server, feedService)
platform.start(8081)                            // installs the filter chain, blocks
```

`/health` answers `{"status":"UP"}`; `/version` the Java `VersionController` shape
(`APP_VERSION`, `APP_BUILD_TIME`, details with header `X-Version-Details` = `REDE_VERSION_DETAILS_TOKEN`).

### Routes

```kotlin
server.get("/feed/posts/:id", () -> { ... return json.encode(view) })      // also post/put/patch/delete
server.post("/feed/posts", () -> { ...; return status(201, json.encode(view)) })
```

Handlers return the body String (JSON is detected by a leading `{` or `[`); use `status(code, body)`
for other statuses. A thrown String is turned into the JSON error. A handler whose body only throws
cannot be typed: write `String f() { throw ... }` and call it. Every route is also served under
`/v1` (the `V1AliasFilter` alias; the gateway strips `/api`, so Kof sees `/feed/...` and
`/v1/feed/...`). The `/v1` index itself belongs to the `apiv1` domain.

Error and envelope shapes:

```text
{"code":"X","message":"...","timestamp":"2026-11-04T19:36:45.975826Z"}      error (status from the ApiError)
{"success":true,"data":{...},"timestamp":"..."}                              apiSuccess(dto)
{"success":true,"timestamp":"..."}                                           apiSuccessEmpty()
{"success":false,"error":{"code":"X","message":"..."},"timestamp":"..."}     status(400, apiFailure("X","..."))
```

Unknown path -> `200` with an empty body (FallbackSurfaceFilter). Known path, other method ->
`405 METHOD_NOT_ALLOWED` ("Metodo nao suportado para este recurso."). Trailing slashes and empty
segments are unknown paths.

### Request helpers (`Req`)

```kotlin
Req.pathParam("id")                              // param("id") also works unqualified
Req.queryStr("q", "")   Req.queryInt("limit", 20)   Req.queryLong(k, 0L)   Req.queryBool(k, false)
//   absent -> default; malformed -> throws 400 BAD_REQUEST
Req.bodyText()          Req.headerOrNull("x-session-token"): String?
Req.cookie("enois_session"): String?   Req.cookies(): Map<String, String>   Req.bearerToken(): String?
Req.clientIp()          // ClientIpResolver rules: TRUSTED_PROXY_IPS, loopback/private ranges, Cloudflare
Req.peerAddress()       // raw TCP peer
```

JSON bodies: `json.decode<T>` needs a concrete type, so write one parser per DTO and map failures to 400:

```kotlin
FeedPostBody parsePostBody() {
    try { return json.decode<FeedPostBody>(Req.bodyText()) } catch (String e) { throw Errors.badRequest() }
}
```

JSON output matches Jackson defaults used by the Java app: record component names in declaration
order, nulls kept, unknown input properties ignored. Only `apiSuccess` omits nulls (NON_NULL).

### Cookies

```kotlin
Cookies.set("enois_session", token, 3600L, true, "Lax")      // name, value, maxAge s, secure, SameSite (HttpOnly, Path=/)
Cookies.clear("enois_session", true, "Lax")                  // Max-Age=0
Cookies.add(Cookies.build(name, value, maxAge, httpOnly, secure, sameSite, path))
```

Any number of cookies per response (the runtime keeps one value per header name, see G13).

### Filter chain (hook for the security task)

```kotlin
server.use("session", 100, () -> {
    var token = Req.bearerToken()
    if (token == null) { return Http.next() }              // continue
    // ... throw Errors.api(401, "UNAUTHENTICATED", "Sessao invalida ou expirada.")   // reject
    return Http.next()
})
```

A filter returns `Http.next()` to continue, or a response (`Http.respond(status, body)`), or throws
an ApiError. Lower order runs first; equal orders keep registration order. Built-ins: order `-1000`
unknown-path fallback (like `FallbackSurfaceFilter`, before everything), order `1000` method check.
Use any other integers: below `-1000` runs before the fallback (observability), between the two for
security filters. The V1 alias needs no filter (routes are registered under both prefixes).

## kernel.jobs

```kotlin
var jobs = Scheduler()
jobs.fixedRate("refresh", 5000L, 60000L, () -> refresh())    // name, initial delay ms, period ms (start to start)
jobs.fixedDelay("sweep", 0L, 30000L, () -> sweep())          // delay after each run ends
jobs.cron("digest", "0 0 9 * * MON", "America/Sao_Paulo", () -> digest())   // Spring 6-field cron; "-" disables
jobs.stop()   jobs.isStopped()   jobs.runCount("refresh")   jobs.failureCount("refresh")
```

Each job is one virtual-thread loop: never overlaps itself, a throwing job is logged
(`job_failed`) and keeps its schedule, `stop()` ends every loop within ~50 ms. Single process only
(no cross-pod lock). `Cron.parse(expr).next(afterMillis, zone)` computes fire times.

## kernel.log and PII

```kotlin
var log = Log("feed.service")
log.info("post created")    log.warn(..)  log.error(..)  log.debug(..)
log.infoWith("login", mapOf("user", userId))     // ...With variants take extra fields
PiiMask.email(value)  PiiMask.text(freeText)     // "***", like shared PiiMask
```

One JSON object per line on stdout (`ts, level, logger, message, ...fields`), `LOG_LEVEL` (default
INFO). Message and field values pass through `PiiMask.text`: still never log secrets or tokens.

## kernel.time

`Time.nowIso()`, `Time.nowMillis()`, `Time.toMillis(iso)`, `Time.fromMillis(ms)`,
`Time.plusSeconds(iso, s)`, `Time.todayIso()`, `Time.fromDbTimestamp(raw)`.

## Testing (`kernel.testkit`)

```kotlin
import kernel.*
import kernel.testkit.*

test "feed lists posts" {
    var app = FeedTestHolder.app()               // see below: one booted app per test file
    var res = app.client.getWith("/feed/posts", listOf("Authorization: Bearer " + token))
    Check.status(res, 200)
    Check.jsonEq(res, "items.0.text", "hello")
    Check.apiError(app.client.get("/feed/posts/x"), 404, "POST_NOT_FOUND")
}
```

- `TestApp.shared()` boots (once per test file) the kernel only: fresh in-memory H2 with ALL
  migrations, ephemeral port, no domain routes. `TestApp.bootWire(name, (p: Platform) -> { ... })`
  boots an app and lets you register domain routes (`p.server`, `p.db`) first;
  `TestApp.bootWith(name, overrides, wire)` also overrides config (`Map<String, String>`).
  Cache the app in a static holder, since a test file is one process:

  ```kotlin
  class FeedTestHolder {
      static TestApp? cached = null
      static TestApp app() {
          var cur = FeedTestHolder.cached
          if (cur != null) { return cur }
          var created = TestApp.bootWire("feed", (p: Platform) -> FeedRoutes.register(p.server, FeedService(FeedStore(p.db))))
          FeedTestHolder.cached = created
          return created
      }
  }
  ```

- `app.client` is a `TestClient`: `get`, `getWith(path, headers)`, `postJson`, `putJson`, `patchJson`,
  `remove`, and `send(method, path, headers, cookies, body)` with headers as `"Name: value"` lines
  and cookies as `"a=b; c=d"`. `client.withJar()` keeps cookies across calls. Raw sockets, so every
  method and header (`Origin`, `Cookie`, `Idempotency-Key`, `X-Forwarded-For`) works.
- `TestResponse`: `status`, `body`, `header(name)`, `headersOf(name)`, `setCookies()`,
  `cookie(name)`, `cookieLine(name)`, `json(path)`, `jsonStr(path): String?`, `jsonHas`, `jsonIsNull`,
  `jsonSize` (paths with dots: `data.items.0.id`).
- `Check.status(res, 200)`, `Check.eqStr(label, expected, actual)`, `Check.eqInt`, `Check.isTrue`,
  `Check.jsonEq(res, path, expected)`, `Check.apiError(res, status, code)`; `JsonPath` is the same
  reader for plain strings. `assert(cond, "literal")` only takes literal messages.
- Fixtures: unique prefixes per test (the database is shared by the tests of a file). Seed with
  `app.db().execute(...)`.
- Time-based code: schedulers/jobs are instances you create in the test and `stop()`.

## kernel.idempotency

`Idempotency-Key` on writes, same `idempotency_keys` table and codes as the Java
`IdempotencyApplicationService`. Route handlers call one helper:

```kotlin
import kernel.idempotency.*

var idem = Idempotency(platform.db)
server.post("/feed/posts", () -> {
    var hash = Idempotency.hash(Req.bodyText())            // SHA-256 hex of the payload text
    // user scope, method, route as the Java side wrote it ("/api/..."), hash, success status, action
    return idem.handle(userId, "POST", "/api/feed/posts", hash, 201, () -> json.encode(createPost(userId)))
})
```

`handle` reads the `Idempotency-Key` header and answers `status(successStatus, body)`. `execute(scope,
method, route, key: String?, hash, status, action): IdempotencyReply(status, body)` is the same without
HTTP. The action returns the JSON body text; the success status is a parameter (every Java command has a
fixed status, and a lambda cannot return a type from another package, G28).

The call is one transaction (like `@Transactional`): marker, the action's own writes and the stored
response commit together; a throwing action leaves no marker, so the client can retry with the same key.

| Situation | Answer |
|---|---|
| missing / blank key | 400 `IDEMPOTENCY_KEY_REQUIRED` "Idempotency-Key obrigatoria." |
| same key + hash, completed | stored status and body, action not run |
| same key, other hash (checked first) | 409 `IDEMPOTENCY_PAYLOAD_CONFLICT` |
| marker `PROCESSING` / `FAILED` | 409 `IDEMPOTENCY_IN_PROGRESS` / `IDEMPOTENCY_FAILED` |
| lost insert race (unique violation) | replay or reject against the winner's row |

Keys are scoped by user, method, route and key; rows live 24 h (`expires_at`).
`Idempotency.hash(json.encode(dto))` hashes a DTO; hashes only need to be stable within this service.

## kernel.outbox, kernel.audit, kernel.id

```kotlin
import kernel.outbox.*

var outbox = Outbox(platform.db)
outbox.register("NOTIFICATION_REQUESTED", NotificationOutboxHandler(...))   // by event type, in order
outbox.schedule(jobs, platform.cfg)             // @Scheduled: every REDE_OUTBOX_WORKER_DELAY_MS (5000)
database.transaction(() -> {
    // ... business write ...
    outbox.append("NOTIFICATION_REQUESTED", aggregateId, payloadJson)    // exists only if it commits
})
outbox.processPending(): Int                    // one worker pass (tests call it directly)
```

A handler extends `OutboxEventHandler` (a base class: `implements` across packages does not compile,
G28) and overrides `handle(eventType, aggregateId, payload)`. Same tables (`outbox_events`,
`processed_events`) and delivery rules as the Java `OutboxWorker`: up to 50 PENDING events due
(`next_attempt_at <= now`), oldest first; every handler registered for the type is called; a throwing
handler is logged (`outbox_handler_failed`) and neither stops the others nor keeps the event pending: the
event is marked PROCESSED anyway. That is Java's behaviour, so there is no retry and no backoff
(`next_attempt_at` is never moved); an event with no handler is PROCESSED too. Each event runs in its own
transaction. Domains register their own handlers (`NotificationOutboxEventHandler`,
`LinkedInShareOutboxEventHandler`).

After-commit hooks (`Db.afterCommit`, see kernel.db) are the `@TransactionalEventListener(AFTER_COMMIT)`
equivalent.

```kotlin
import kernel.audit.*
var audit = Audit(platform.db)
audit.write(actorId, "USER_BANNED", targetId, "{\"reason\":\"spam\"}")      // metadata may be null
```

`audit_logs` is append-only and joins the caller's transaction. `Ids.uuid()` / `Ids.prefixed("risk_")`
(`kernel.id`) mint the string ids of those tables.

## kernel.security: hashes, secrets, passwords, TOTP

```kotlin
import kernel.security.*

Hashes.sha256Hex(token)                       // lower-case hex of the UTF-8 bytes (only hashes are persisted)

var cipher = SecretCipher.fromConfig(platform.cfg)   // REDE_SECURITY_ENCRYPTION_KEY (32 bytes, base64)
cipher.encrypt(secret)  cipher.decrypt(stored)  cipher.isEnabled()  cipher.requireEnabled()
SecretCipher.generateKeyBase64()
```

`SecretCipher` is byte-compatible with the Java class: AES-256-GCM, `base64(iv12 || ciphertext || tag16)`
(tested against a ciphertext produced by the Java algorithm). The key is required at boot outside the
`dev` profile (`SPRING_PROFILES_ACTIVE`; override `REDE_SECURITY_ENCRYPTION_KEY_REQUIRED`), failing with
`CONFIG_MISSING`/`CONFIG_INVALID`. Without a key `encrypt/decrypt` throw `503 SECURITY_KEY_NOT_CONFIGURED`.
A wrong key or corrupted value throws `SECRET_CIPHER_FAILURE` (a 500 at the edge).

```kotlin
Passwords.hash(password)                       // "120000:base64(salt):base64(key)", PBKDF2WithHmacSHA256
Passwords.matches(password, stored)            // verifies Java hashes; malformed -> false, constant-time compare
Passwords.validateStrength(password)           // 400 WEAK_PASSWORD: 8..128 chars, not in the common list
Passwords.isCommon(password)                   // resources/security/common-passwords.txt (SECURITY_RESOURCES_DIR)
```

```kotlin
var secret = Totp.generateSecret()                         // base32, 32 chars
Totp.verifyDefault(secret, code, epochSecond)              // +-1 step; spaces in the code are ignored
Totp.matchingStep(secret, code, epochSecond, 1): Long      // the step, or -1: persist it to refuse replays
Totp.codeAt(secret, step)   Totp.otpauthUri(issuer, account, secret)
```

TOTP is RFC 6238 (HMAC-SHA1, 6 digits, 30 s) and passes the RFC vectors. Times are epoch seconds
(`Time.nowMillis() / 1000L`), not `Instant`.

Java checked exceptions (`GeneralSecurityException`, `SQLException`) are not caught by `catch (String)`:
catch them by type (see `SecretCipher`).

## kernel.html: sanitising and Markdown

Third-party jars (versions of the Java `pom.xml`): jsoup 1.23.2, commonmark 0.31.0 with the GFM tables
and strikethrough extensions.

```kotlin
import kernel.html.*

SafeHtml.sanitizePageHtml(raw): String?       // null when nothing useful is left (blank, only <script>...)
SafeHtml.sanitizeProfileHtml(raw)  sanitizeProjectHtml(raw)  sanitizeBlogHtml(raw)
SafeHtml.requirePageHtml(raw)      requireProfileHtml(raw)   requireBlogHtml(raw)    // 400 INVALID_*_HTML instead of null
SafeHtml.maxPageHtml() 200000   maxProfileHtml() 20000   maxProjectHtml() 200000   maxBlogHtml() 20000
```

Port of `shared/html/SafeHtml`, same allowlist (HTML, SVG with SMIL, `data-enois-embed`), same limits
(raw input 400000, CSS 64000, the length limit applies to the cleaned result) and codes
(`PAGE_HTML_TOO_LONG`, `PROFILE_HTML_TOO_LONG`, `PROJECT_HTML_TOO_LONG`, `BLOG_HTML_TOO_LONG`,
`CSS_TOO_LONG`). `<style>` blocks are extracted, cleaned (no `@import`, `expression(`, `behavior:`,
`image-set(`, `javascript:`; `url()` only for `data:`; CSS escapes decoded before checking) and prepended;
only https provider embeds survive as `iframe`; links get `target="_blank" rel="noopener noreferrer"`;
`<use>`/`<mpath>` only reference `#fragment`s. Every scan is linear (cost tests). One deliberate fix: the
Java `Matcher.replaceAll(Function)` read `$` and `\` in the replacement as group references; here
replacements are literal (`kernel.text.Regexes`).

```kotlin
MarkdownBio.render(markdown, owner, repo, branch): String   // README -> bio HTML (MarkdownBioRenderer)
```

Relative links/images become absolute (blob/raw), the result goes through `requireProfileHtml`; an
oversized README is `400 README_TOO_LONG`.

`Regexes.replaceAll(pattern, input, (m: Matcher) -> String)` is the regex replace with a callback
(literal replacements); `Regexes.add(sb, text)` appends to a `StringBuilder` (see G30).
