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

### Filter chain

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
unknown-path fallback (like `FallbackSurfaceFilter`), order `1000` method check (405). The whole security
pipeline lives between them and around them, see "Filter order" under `kernel.security`. The V1 alias
needs no filter (routes are registered under both prefixes); guards compare `RequestPath.current()`.

### After hooks, request context

```kotlin
server.useAfter("access-log", (status: Int, body: String) -> { ... })    // every request, final status and body
Http.currentStatus()      // status the current response will carry (200 until status(...) is called)
Http.routePattern()       // "/feed/posts/:id", or "UNMATCHED" (what the access log calls http.route)
ResponseHeaders.set("X-A", "1")   ResponseHeaders.add("Vary", "Origin")   ResponseHeaders.get / has
RequestPath.current()     // raw path of the request without the /v1 alias: what every guard rule is written against
RequestPath.decode(raw)   // %XX once, '+' kept, malformed -> throws "REQUEST_PATH_MALFORMED"
Req.rawQuery()            // query string as received
```

An after hook runs whoever produced the response (a route, a filter, the 405/unknown-path answers) and
can only observe: a failing hook is logged and never changes the response. The runtime hands guards the
RAW path and matches routes on it literally: `/%61dmin/x`, `/admin;v=1/x`, `/auth//config` and `/Admin/x`
are unknown paths (200 empty, `/auth/%63onfig` included, see `docs/PORTING_STATUS.md`), so a guard never
sees a spelling that routes to a protected handler without matching its own rule.

`HttpServer.install` also (a) switches the runtime's own hardening headers and CSRF off
(`app.security(headers:false, csrf:false)`, G27: `kernel.security` writes the Java header set), and (b) moves
the `Authorization` header out of the request (G28: the runtime would answer 401 to it). `Req.bearerToken()`
still returns the Bearer token.

## kernel.security

Everything request-pipeline of `shared/web` and `shared/security`. A domain only calls `Auth` (below);
`Main.kf` calls `Auth.install(server, db, cfg)` (the full chain is `Security.install`, listed further down).

### Current user (`Auth`, `SessionCookies`)

```kotlin
import kernel.security.*

var userId = Auth.requireUser()          // String. 401 UNAUTHENTICATED "Sessao invalida ou expirada."
                                         //        403 EMAIL_NOT_VERIFIED (no confirmed e-mail and no second factor)
var viewer = Auth.viewerIdOrNull()       // String?. Public reads: anonymous / bad session / unverified -> null, never throws
Auth.sessionToken()                      // String?. X-Session-Token header, else Authorization: Bearer, else the enois_session cookie
Auth.resolve(token)                      // same rules for a token you already hold (CurrentUserResolver.resolve)
Auth.requireAdmin()   Auth.requireModerator()    // see "Guards"

SessionCookies.issue(token, expiresAtIso, refreshToken, refreshExpiresAtIso)   // two Set-Cookie headers on the response
SessionCookies.clear()                                                        // both cookies, Max-Age=0
SessionCookies.issueLines(...) / clearLines()                                  // the lines, for tests or custom responses
```

Contract (all as the Java service):

| | `enois_session` | `enois_refresh` |
|---|---|---|
| SameSite | Lax | Strict |
| Max-Age | seconds until the access expiry | seconds until the refresh expiry (0 when clearing) |
| Path / HttpOnly | `/` / yes | `/` / yes |
| Secure | `REDE_AUTH_COOKIE_SECURE` (default true; false only when `SPRING_PROFILES_ACTIVE=dev` is explicit) | same |

An explicit `X-Session-Token` always wins over the cookie. A write authenticated by cookie (`enois_session` or
`enois_refresh` present, no `X-Session-Token`) must carry `X-CSRF-Protection: 1`, else
`403 {"code":"CSRF_REQUIRED","message":"Requisicao recusada. Recarregue a pagina e tente de novo."}` (no
timestamp, `Cache-Control: no-store`, CORS reflected for trusted origins). `Authorization: Bearer` is accepted as
a token source after the header (the Java service reads only the header and the cookie; the contract in
AGENTS.md lists Bearer) and never exempts a cookie request from CSRF.

Session lookup is `select ... from auth_sessions where token = sha256(token)`, active when `revoked_at is null and
expires_at > now`, plus the deploy-window fallback on the clear token (never for a value shaped like a stored
hash). The verification check reads `users.email_verified_at / totp_enabled_at / email_otp_enabled_at /
federated_second_factor_at`; a missing user row passes (as in Java). One resolution per request is cached by
token digest (reset by `Auth.resetRequest`, called by the observability filter), so a write that went through
the write gate does not repeat the two queries in its handler.

### Filter order (Java -> Kof)

`Security.install(platform, hooks)` registers the whole pipeline. The Java order comes from `@Order`
(Spring filters), the MVC interceptors and the MVC CORS handling; the kernel's `-1000` and `1000` built-ins keep
their slots.

| Kof order | Name | Java | What it does |
|---|---|---|---|
| -1004 | `request-observability` | `RequestObservabilityFilter` (HIGHEST+2) | request id, `LogContext`, `X-Request-Id`, access line (an after hook) |
| -1003 | `panic-mode` | `PanicModeFilter` (+3) | 429 `PANIC_MODE` on writes while panic is on |
| -1001 | `path-guard` | `FallbackSurfaceFilter` (+4), malformed escape | `400` empty on a bad `%` escape |
| -1000 | `fallback-surface` | `FallbackSurfaceFilter` (+4) | unknown path: `200` empty (kernel built-in) |
| -990 | `origin-gate` | `RequestOriginFilter` + `OriginAbuseGuard` (+5) | `ORIGIN_*` 403s, preflight 204, third-party CORS |
| -980 | `session-csrf` | `SessionCookieFilter` (+6) | `CSRF_REQUIRED` on cookie writes |
| 0 | `abuse-guard` | `AbuseGuardFilter` (@Order 0) | timed denial for error scanners (after hook counts) |
| 1 | `global-rate-limit` | `GlobalApiRateLimitFilter` (1) | write ceiling per user / ip |
| 2 | `identity-rate-limit` | `IdentityRateLimitFilter` (2) | per-ip limit on `/auth/*` POSTs |
| 2 | `public-read-rate-limit` | `PublicReadRateLimitFilter` (2) | `ENUMERATION_GUARD` on people reads |
| 3 | `post-rate-limit` | `PostRateLimitFilter` (3) | POST ceiling per session digest / ip |
| 4 | `duplicate-post` | `DuplicatePostFilter` (4) | replays the answer of an identical in-flight POST |
| 5 | `security-headers` | `SecurityHeadersFilter` (no `@Order`: innermost) | the 8 headers, `no-store` for sessions |
| 5 | `public-read-cache-control` | `PublicReadCacheControlInterceptor` | `public, max-age=0, must-revalidate` on public GETs |
| 5 (transform) | `public-read-etag` | `ShallowEtagHeaderFilter` | weak ETag / 304 on public GETs |
| 6 | `cors` | Spring MVC CORS (`CorsConfig`, `DefaultCorsProcessor`) | preflight, credentialed grant, `Invalid CORS request` |
| 7 | `admin-route-guard` | `AdminRouteInterceptor` | `/admin/**` needs an admin (moderator paths: a moderator) |
| 8 | `write-gate` | `WriteRouteInterceptor` | every write needs a session unless it is a public flow |
| 1000 | `method-not-allowed` | MVC handler mapping 405 | kernel built-in |

Differences, all on purpose:

- Java's `V1AliasFilter` (`@Order 0`) runs after the origin gate, the panic filter and the CSRF filter, so
  those saw `/v1/auth/login`, `/v1/admin/...` raw: the panic exemption missed `/v1/auth/login`, and
  `/v1/admin/**` needed only a registered origin, not the front end's. Every guard here compares
  `RequestPath.current()` (alias stripped), so `/v1/...` and `/...` get exactly the same rules.
- The admin and write gates run only for a request that matched a route and method (Spring interceptors
  never see a 405), and never on a preflight.
- A path is "known" only when spelled exactly like a registered route (raw, case-sensitive, no decoding).
  Java decoded `/auth/%63onfig` into the `/auth/config` route; here it is an unknown path (`200` empty). The
  other spellings the Java tests lock (`/%61dmin/support`, `/admin;v=1/support`, `//`) are unknown paths in
  both. A guard can therefore never be skipped by an alternative spelling of a route.
- `FallbackSurfaceFilter` also served an embedded decoy pack (`LegacyPack`: `.env`, `.git`, wp-admin ...) with a
  delay and an origin auto-block; that honeypot is not ported (see `docs/PORTING_STATUS.md`).

### Wiring (`Security`, `SecurityHooks`)

```kotlin
var hooks = SecurityHooks.defaults(platform.db)     // Main.kf: replace a field when its domain lands
hooks.moderators = ModerationModerators(...)        // moderation: SecurityModerators.isModerator(userId)
hooks.monitoring = OpsMonitoring(...)               // ops: SecurityMonitoring (counters, events)
hooks.reports = ModerationAutoReports(...)          // moderation: SecurityAutoReports.report(userId, reason, description)
hooks.origins = DeveloperOrigins(...)               // apiv1: OriginDirectory (default: JdbcOriginDirectory on developer_origins)
var parts = Security.install(platform, hooks)       // filters, routes, statics; returns SecurityParts
parts.userLimiter.require(userId, UserRateLimiter.createPost())    // limiter instances for the domains
Security.parts()                                    // the same SecurityParts from a domain module (after Security.install)
```

The seams are classes with a safe default, not interfaces: a Kof interface declared in a package cannot be
implemented (KOF_GAPS G30). A domain `extends` the class and overrides its methods.

`Security.install` also registers `GET /admin/panic` and `POST /admin/panic` (`{"active":true}` ->
`{"active","envLocked","message"}`, admin only, exempt from the panic block itself).

### Guards (`Auth.requireAdmin`, `AdminGuard`, `ModeratorGuard`)

```kotlin
Auth.requireAdmin()        // userId; 403 FORBIDDEN "Acesso restrito a administradores." unless users.is_admin
Auth.requireModerator()    // userId; admin or moderator; 403 FORBIDDEN "Acesso restrito a moderadores."
parts.admin.isAdmin(userId)   AdminGuard.isReservedUsername(name)   AdminGuard.reservedUsernames()
```

Admin is the immutable `users.is_admin`; `REDE_ADMIN_BOOTSTRAP_ENABLED=true` + `REDE_ADMIN_EMAILS` adds an
e-mail allowlist for TESTS ONLY. `/admin/**` is gated centrally: moderators also pass `/admin/appeals`,
`/admin/support` (not `/admin/support/github`), `/admin/suggestions`, `/admin/emails`, `/admin/blocked-ips`,
`/admin/monitoring` and `/admin/users/{id}/(sanction|sanitize|ips)`.

### Limiters

All in memory, per pod (N replicas = N x the ceiling), sliding windows on `SecurityClock` (tests move time with
`SecurityClock.advanceSeconds`). A rejected attempt is never counted.

```kotlin
parts.ipLimiter.tryAcquire(IpRateLimiter.login(), ip): Bool          // signup login password email 2fa contribution refresh
parts.userLimiter.require(userId, UserRateLimiter.createPost())      // 429 RATE_LIMIT_EXCEEDED; 3 rejections/h -> hooks.reports
parts.actionThrottle.requireAllowed("report", userId, 5, 3600000L)   // 429 ACTION_THROTTLED
parts.authThrottle.requireLoginAllowed(email, ip)   recordLoginFailure(email, ip)   clearLogin(email, ip)
parts.authThrottle.requireSignupAllowed(ip, fingerprint)             // 429 LOGIN_THROTTLED (+Retry-After) / SIGNUP_THROTTLED
parts.newAccountCooldown.require(userId)                             // 429 ACCOUNT_TOO_NEW
parts.timingGuard.recordAction(userId)   looksAutomated(userId)      // 10 actions, stddev < 500 ms, log only
parts.namedLimiters.require("auth")                                  // resilience4j: auth twofa refresh search email-sending
                                                                     // 429 RATE_LIMITED + Retry-After 60
```

Env (defaults are the `application.properties` values; Spring-relaxed names for the ones without a placeholder):

| Limiter | Variables |
|---|---|
| IpRateLimiter | `SIGNUP_RATE_LIMIT` 10, `LOGIN_RATE_LIMIT` 60, `PASSWORD_RATE_LIMIT` 5, `EMAIL_RATE_LIMIT` 5, `TWO_FACTOR_RATE_LIMIT` 20, `CONTRIBUTION_RATE_LIMIT` 5, `REFRESH_RATE_LIMIT` 120; windows `REDE_SECURITY_RATE_LIMIT_<SIGNUP\|LOGIN\|PASSWORD\|EMAIL\|2FA\|CONTRIBUTION\|REFRESH>_WINDOW_MINUTES` 60/15/15/15/15/60/15 |
| UserRateLimiter | `REDE_RATE_POST_LIMIT` 10, `REDE_RATE_COMMENT_LIMIT` 30, `REDE_RATE_JOB_APPLY_LIMIT` 100, `REDE_RATE_MESSAGE_LIMIT` 60, `REDE_RATE_GITHUB_SYNC_LIMIT` 3, `REDE_CALL_START_LIMIT` 20; `..._WINDOW_MINUTES` 60/60/30/1/60/60 |
| AuthThrottle | `REDE_AUTH_THROTTLE_LOGIN_MAX_FAILURES` 5, `REDE_AUTH_THROTTLE_SIGNUP_PER_HOUR` 10 (explicit `SPRING_PROFILES_ACTIVE=dev`: 100 / 100000) |
| NewAccountCooldown | `REDE_SECURITY_NEW_ACCOUNT_COOLDOWN_SECONDS` 30 (0 off) |
| named (resilience4j) | `RESILIENCE4J_RATELIMITER_INSTANCES_<AUTH\|TWOFA\|REFRESH\|SEARCH\|EMAIL_SENDING>_LIMIT_FOR_PERIOD` 300/60/120/120/200 and `_LIMIT_REFRESH_PERIOD` 1m/1m/1m/1m/15m |
| GlobalApiRateLimitFilter | `GLOBAL_RATE_LIMIT_PER_MINUTE` 300 (0 off), `REDE_RATE_GLOBAL_SHARED_MULTIPLIER` 50 |
| PostRateLimitFilter | `POST_GUARD_ENABLED` true, `POST_USER_RATE_LIMIT` 120, `POST_IP_RATE_LIMIT` 300 |
| PublicReadRateLimitFilter | `REDE_RATE_PUBLIC_READ_PER_MINUTE` 600 |
| AbuseGuardFilter | `REDE_SECURITY_ABUSE_MAX_ERRORS` 0 (off), `_WINDOW_SECONDS` 180, `_FIRST_BLOCK_MINUTES` 15, `_MAX_BLOCK_MINUTES` 360 |
| DuplicatePostFilter | `REDE_SECURITY_DUPLICATE_POST_ENABLED` true |
| Panic mode | `PANIC_MODE` (`yes\|true\|on\|1`: hard override, the panel cannot switch it off) |
| Origins and CORS | `CORS_ALLOWED_ORIGINS` (prd/qa/dev profile defaults as in Java), `REDE_TRUSTED_ORIGINS`, `REDE_ORIGINS_ENFORCE` true, `REDE_ORIGINS_MAX_FAILURES` 60, `REDE_ORIGINS_WINDOW_SECONDS` 300, `REDE_ORIGINS_BLOCK_MINUTES` 30; `*` or `scheme://*` is a boot error |
| Cookies | `REDE_AUTH_COOKIE_SECURE` |

Rate limiter answers are written by hand like in Java: `{"code":"RATE_LIMITED","message":"..."}` with no timestamp,
`Retry-After`, and the CORS headers of a trusted origin (so the browser shows the 429 instead of a network error).
Limiter keys never hold a token in clear (digests) and the limiters' own warnings carry no addresses or tokens.

### Access log, audit and request context

`RequestObservability` writes one `http_request requestId=... method=... path=... status=... durationMs=...
clientIp=... userId=... deviceId=...` line per request (INFO; ERROR for 5xx; DEBUG for `/livez`, `/readyz`,
`/actuator/health*`), `slow_request` WARN from 2 s, and `admin_action actor=... action=POST /admin/x/:id path=...
status=...` on the `audit` logger for every `/admin/**` mutation. Handlers read `LogContext.get("userId")`,
`requestId`, `clientIp`, `deviceId`, `http.method`, `http.path`. Tests turn on `RequestObservability.startCapture()`
and read the lines with `drainCapture()`.

### Test support (`SecurityApp`, `SecurityFixtures`)

```kotlin
var app = SecurityApp.boot("name", mapOf("LOGIN_RATE_LIMIT", "3"), (s: HttpServer) -> wire(s))   // enforcement off
SecurityFixtures.login(app.db(), "user_a", "tok-a-1234567890")        // verified user + live session
SecurityFixtures.user(db, id, verified, admin)   session(db, id, token, ttlSeconds)   revoke(db, token)
Check.filterError(res, 429, "RATE_LIMITED")      // filter answers have code + message and NO timestamp
```

One `SecurityApp` per test file: `Security.install` sets process-wide statics (`Auth`, `SessionCookies`).

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

## kernel.cache

A tiny in-process TTL cache replaces Caffeine (`@Cacheable` lists and hot-path maps); no dependency.
String keys and String values: cache the JSON text of a response and decode at the call site (generic
class values come back as `Object` without a cast, and casts to domain types do not compile, G28).

```kotlin
import kernel.cache.*

var caches = Caches.create(platform.cfg)             // the closed list of the Java CacheConfig
var ranking = caches.get("publicRanking")             // unknown name throws CACHE_UNKNOWN
var body = ranking.getOrLoad("top", () -> json.encode(loadRanking()))   // one load per expired key
ranking.put(k, v)  ranking.get(k): String?  ranking.evict(k)  ranking.clear()
ranking.evictAfterCommit(database, k)   ranking.clearAfterCommit(database)    // CacheInvalidator
ranking.add(k, v): Bool                               // atomic first-writer-wins (duplicate guards)
ranking.hits()  misses()  size()
var own = TtlCache("name", 20000L, 500)               // ttl millis, max entries
```

Same semantics as the Caffeine setup: expire-after-write (nothing is scheduled: the next caller that needs
a stale entry pays the load), a size cap (stale entries go first, then the ones expiring first), and one
load when many callers hit the same expired key (a loader failure reaches all of them and caches
nothing; do not call another `getOrLoad` from inside a loader). Per pod: invalidating does not reach the
other pods, the TTL is the guarantee. Caches: `publicProfiles` (20 s, 5000), `publicRanking` (20 s, 64),
`communitiesList`, `eventsList`, `jobsList` (20 s, 500), `communityStats` (10 m, 4), `externalJobs` (5 m,
16), `pagePreviewCards` (1 h, 16), `gifSearch` (10 m, 200), `githubRepositories`, `githubReadme` (3 m,
200). `REDE_CACHE_DYNAMIC_TTL` (default `20s`) feeds the 20 s ones; `REDE_CACHE_<NAME>_TTL` (`500ms`,
`5s`, `10m`, `1h`, `2d`, bare number = ms) and `REDE_CACHE_<NAME>_MAX_ENTRIES` override one cache
(`REDE_CACHE_JOBS_LIST_TTL`).

## kernel.text, kernel.geo, kernel.search

```kotlin
import kernel.text.*

Base64Url.encode(text)  Base64Url.decode(encoded)   // URL-safe Base64 without padding (opaque cursors); decode throws on bad input

PlainText.defuse(raw): String?                 // bidi/zero-width removed, <=5 combining marks, runs capped at 12 ("travazap")
TextFieldLimit.check("COMPANY_FIELD_TOO_LONG", "nome", value, 160)   // 400 "O campo nome aceita no máximo 160 caracteres."
LikePattern.contains(q)  LikePattern.startsWith(q)  LikePattern.escape(t) // null for blank; SQL must say `escape '!'`
InlineMedia.idsIn(content)  InlineMedia.validate(content, mediaIds)       // 400 INVALID_INLINE_MEDIA for foreign markers
Texts.stripAccents(s)  Texts.squash(s)
Regexes.replaceAll(pattern, input, (m: Matcher) -> String)               // literal replacements
```

```kotlin
import kernel.geo.*
var place = CityState.of(city, state)          // CityState(city, state, cityKey) or null; 400 CITY_STATE_INCOMPLETE / INVALID_STATE / CITY_TOO_LONG
CityState.requireState("mg") == "MG"           CityState.key("São Paulo") == "sao paulo"   CityState.states()  // the 27 UFs
```

```kotlin
import kernel.search.*
var q = BooleanQuery.parse(raw)                // never fails on bad syntax; 400 BAD_REQUEST past 64 terms / 12 levels
q.isEmpty()  q.root(): BooleanNode             // kind MATCH_ALL | TERM | PHRASE | AND | OR | NOT, text, children, describe()
BooleanQuery.rejection(raw): String            // the reason a query is refused, "" when fine
```

Syntax: loose terms (AND), `AND/E`, `OR/OU`, `NOT/NAO/NÃO`, `-term`, `+term`, `"phrase"`, parentheses; NOT > AND > OR.
`BooleanNode` is a class with a `kind` string (the Java sealed records cannot be built across packages, G28).

## kernel.url and kernel.security guards

```kotlin
import kernel.url.*
import kernel.security.*

SafeUrl.requireHttpUrl(raw, "site")                    // 400 INVALID_URL; blank passes; max 500 chars, host, no credentials
SafeUrl.requireHttpUrlList(list, field)  SafeUrl.requireHttpUrlsJoined(text, separatorRegex, field)
SafeUrl.requireSafeMarkdownLinks(text, field)          // 400 UNSAFE_LINK: markdown/reference/html link schemes
SafeUrl.isSafeLinkTarget(target)                       // no scheme, or http/https/mailto (whitespace/control/format chars ignored)
SafeLinks.checkRequest()                               // SafeLinkRequestBodyAdvice: every string of a JSON body, decoded
SafeLinks.checkBody(text)                              // the same on a text; >2 MB -> 400 BAD_REQUEST; malformed -> left to the DTO parser
OutboundUrlGuard.safe(url): Bool                       // SSRF: http/https, ports 80/443, no local names, DNS only to public addresses
SuspiciousText.fromConfig(cfg).matches1(text)  .matchesAny(listOf(a, b))        // CONTENT_SWEEP_PATTERNS
ContentDuplicationGuard.fromConfig(cfg).require(userId, text)   // 409 DUPLICATE_CONTENT; REDE_RATE_DUPLICATE_WINDOW_MINUTES (60, 0 = off)
guard.isDuplicate(userId, text)                        // pure query; `require` is atomic
```

`SafeLinks.checkRequest()` is the handler/filter-level equivalent of the Java `@ControllerAdvice`: call it
before parsing a JSON DTO (JSON content types only; raw payloads a handler verifies as is, such as a
webhook HMAC, must not go through it). The Kof JSON reader behind it (`JsonStrings`) collects decoded
string values with their property name because Kof cannot walk a Jackson tree.

## kernel.blocks, kernel.sanctions, kernel.risk

Read-only ports of the shared readers, on their own tables, plus the risk engine.

```kotlin
import kernel.blocks.*
BlockedUsers(database).hiddenIdsFor(viewerId): HashSet<String>   // blocks in both directions + unexpired mutes
.blockedBetween(userId)   .hiddenBetween(a, b)                    // blocks only (network module)
BlockedUsers.none()                                               // no database: nothing hidden
```

```kotlin
import kernel.sanctions.*
var reader = SanctionGateReader(database)      // user_sanctions: the latest ACTIVE row of the account
reader.restricted(id)  reader.banned(id)  reader.bannedAmong(listOf(...))  reader.activeReason(id): String?
SanctionGate(reader).requireNotRestricted(userId)      // 403 ACCOUNT_RESTRICTED in every write path
```

`banned` = active SUSPENDED, BAN or PERMABAN; `restricted` = any active sanction. The moderation domain
owns the writes and may extend `SanctionGateReader` (override a method) before wiring it in `Main.kf`.

```kotlin
import kernel.risk.*
var engine = RiskEngine.fromConfig(cfg, RiskSubjectReader(db, sanctionReader), RiskAssessmentWriter(db),
                                   timing, duplicationGuard, escalation)
var a = engine.assess(userId, "publish", content): RiskAssessment?    // null without signal; never throws
a.level  a.score  a.signals  a.decision  a.ruleVersion  a.action  a.id
```

Signals `ROBOTIC_CADENCE`, `DUPLICATE_CONTENT`, `NEW_ACCOUNT`, `ACTIVE_SANCTION` (`RiskSignals.*`), weights
3/2/1/3, thresholds MEDIUM 2 / HIGH 5 / CRITICAL 8, decision ALLOW, MONITOR, ESCALATE or RESTRICT (RESTRICT
only for CRITICAL with `REDE_RISK_ENFORCE=true`; default is observation mode). Env:
`REDE_RISK_WEIGHTS_*`, `REDE_RISK_THRESHOLDS_*`, `REDE_RISK_NEW_ACCOUNT_HOURS` (24), `REDE_RISK_ENFORCE`.
Assessments are stored in `risk_assessments`; a non-LOW level opens a moderation case once per hour per
account through `RiskEscalation.escalate(userId, description)` (default: log only). The cadence signal
comes from `RiskTimingSignals.looksAutomated(userId)` (default: false): wire the `BehavioralTimingGuard`
of the security module there. Levels, signals and decisions are String constants (enums do not cross
packages safely, G43).

## SharedServices (composition)

`SharedServices.create(platform)` builds everything above in one call (fail-fast config first, then the
outbox worker) and `Main.kf` calls it after `Platform.create`:

```kotlin
var shared = SharedServices.create(platform)
shared.idempotency  shared.outbox  shared.audit  shared.cipher  shared.caches  shared.blockedUsers
shared.sanctionReader  shared.sanctionGate  shared.suspiciousText  shared.duplication  shared.risk
shared.jobs  shared.stop()
```

`TestApp.bootWith/bootWire` now stop the platform when the `wire` callback throws (the open pool kept the
test process from exiting).
