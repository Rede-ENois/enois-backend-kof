# Porting status

| Domain | Endpoints ported / total | Tests ported / total | Gaps |
|---|---|---|---|
| shared/web + shared/security (request pipeline) + `apiv1` origin gate | `GET/POST /admin/panic` 2/2 (the `/v1` index and `/developers/origins` CRUD belong to `apiv1`) | 87 / 100 Java tests (149 Kof tests in `tests/security/`) | G28 to G35 |
| notifications, push, messaging, calls (slug `messaging`) | notifications 8/8, push 3/3, messaging 24/24 (`GET /conversations/stream` answers but cannot stream, G201), calls 13/13 | 117 / 122 Java tests (notifications 34/34, push 21/21, messaging 51/55, calls 11/12; 127 Kof tests in `tests/notifications`, `tests/push`, `tests/messaging`, `tests/calls`, `tests/kernel/WebPushAdapterTest.kf`) | G200 to G212 |

## Request pipeline (`kernel.security`)

Ported: current-user resolution (`Auth`, `SessionCookies`, CSRF), the filter chain in the Java order (table in
`docs/KERNEL.md`), the limiter primitives (`IpRateLimiter`, `UserRateLimiter`, `ActionThrottle`, `AuthThrottle`,
`NewAccountCooldown`, `BehavioralTimingGuard`, the five resilience4j limiters, `PanicModeService`), `AdminGuard`,
`ModeratorGuard`, `AdminRouteInterceptor`, `WriteRouteInterceptor`, `RequestOriginFilter` + `OriginAbuseGuard` +
`DeveloperOriginService.allowedOrigins/isBlocked/block/releaseExpired` (read side), CORS, security headers,
public-read cache (ETag, `Cache-Control`), duplicate-POST replay, access log + audit line.

### Pending ports (seams owned by other domains, wired with a default in `Main.kf`)

| Seam (class in `kernel.security`) | Default | Owner / what it needs |
|---|---|---|
| `SecurityModerators.isModerator(userId)` | nobody is a moderator (fail closed) | moderation: `ModeratorService.isModerator` (moderators table, V87) |
| `SecurityAutoReports.report(userId, reason, description)` | no-op | moderation: turn the `AutoReportEvent` into a `Report` (`UserRateLimiter` after 3 rejections/h) |
| `SecurityMonitoring` (`requestStarted`, `recordRequest`, `recordClientDisconnect`) | no-op | ops: `MonitoringService` for the admin panel |
| `OriginDirectory` | `JdbcOriginDirectory` (reads/blocks `developer_origins`, 30 s cache) | apiv1: `DeveloperOriginService` registration, `/developers/origins`, `/admin/developers/origins/*`, the `/v1` index (call `invalidate()` after changing the table) |

Also pending, not a seam: the callers of the primitives. `AuthThrottle`, `IpRateLimiter` actions used by the filter
only, `NamedRateLimiters.require(name)` (the `@RateLimiter` annotations), `UserRateLimiter`, `ActionThrottle`,
`NewAccountCooldown` and `BehavioralTimingGuard` are ready in `SecurityParts` and are called by the identity, feed,
messaging, moderation and risk ports. `IpBlockReader` and `SignupAttackGuard` are consumed by identity and owned by
moderation/risk: not part of this pipeline, not created here. `ContentDuplicationGuard` and `SuspiciousText` are
text/risk guards used by the feed port: not created here.

### Java tests that could not be ported (13 of 100)

| Java test | Why |
|---|---|
| `FallbackSurfaceTests.documentoLegadoRespondeComCorpo`, `familiaLegadaRespondeComCorpo` | `LegacyPack` (embedded decoy documents for `.env`, `.git`, wp-admin, with a 0.3-0.5 s delay and an origin auto-block after 5 hits) is not ported: it is a ~26 KB base64 honeypot, not part of the HTTP contract. Unknown paths answer `200` empty like every other one. Port it as a resource file if the security owners want the honeypot back |
| `FallbackSurfaceTests.literalCodificadoContinuaSendoRotaConhecida` | the runtime matches routes on the raw path: `/auth/%63onfig` is an unknown path (`200` empty), not the `/auth/config` route. Covered by `double slashes, encoded literals, case changes and matrix params never become a known route` (stricter, no guard can be skipped) |
| `FallbackSurfaceTests.caminhoAdminCodificadoNaoPulaOInterceptorSemController` | unit test of a Spring interceptor on a mock request. Same outcome at HTTP level: `/%61dmin/support` is never served (`encoded, matrix and prefixed spellings ...` in `OriginTest`, `double slashes ...` in `PipelineTest`) |
| `RequestPathTests.naoReescreveUriQueryOuCorpoAoLerOCaminho` | nothing rewrites the request in Kof; `RequestPath` is a pure function on strings |
| `RequestPathTests.matchingAdministrativoConsideraMatrizNosSegmentos`, `matchingNaoTransformaDadosCodificadosEmEstrutura`, `matchingMantemContextoESeparadoresDoRoteador`, `matchingPublicoPreservaSemicolonCodificadoComoDado` | Spring `PathContainer`/`PathPattern` semantics (matrix params, encoded separators). Guards here compare exact strings of known routes; the HTTP-level tests prove `/admin;v=1/support`, `/admin%2Fsupport`, `//`, `/%2561dmin` are unknown paths that no guard or handler sees |
| `PublicReadCacheHttpTests.theCachedListKeepsEachReadersOwnMembership` | communities domain (`joined` flag); the cache layer has no per-reader state to test |
| `V1ApiAliasTests.indiceDaVersaoListaORoteadorDeVerdade`, `oIndiceDiceQueNaoHaDocumentoOpenApi` | the `/v1` index controller belongs to the `apiv1` domain |
| `AuthThrottleTests.loginBruteForceNaMesmaContaFicaPreso` | needs `POST /auth/login` (identity). The throttle itself is covered by the 4 `AuthThrottleKeyTests` ports plus window/signup/message tests in `LimitersTest` |

Ported with a changed trigger (assertion kept, setup different): `AbuseGuardFilterTests` count 403s of a route
instead of 404s of unknown paths (unknown paths answer `200` here, as in Java behind the router, and never count);
the five `DeveloperOriginTests` assert the gate half (`ORIGIN_*`, CORS, block, auto-block) with rows seeded in
`developer_origins`: the `/developers/origins` CRUD and the admin block/unblock endpoints are the apiv1 domain's;
`AutomatedWritePathsTests` scans the routes registered in the app instead of the Java sources.
| shared services (idempotency, outbox, audit, cipher/password/TOTP, html/markdown, text/geo/search/url guards, blocks, sanctions, risk, cache) | no endpoints (library layer) | 99 / 114 Java tests (179 Kof tests in `tests/shared/`, 5 more in `tests/kernel/AfterCommitTest.kf`) | G41 to G50 |

## Shared services (`kernel.*`, tests in `tests/shared/`)

Ported (API in `docs/KERNEL.md`): `idempotency` (Idempotency-Key + payload hash, same table and codes),
`outbox` (worker every 5 s, handler registry by event type, `processed_events`), `audit`, `Db.afterCommit`
(`@TransactionalEventListener(AFTER_COMMIT)`), `SecretCipher` (byte-compatible with Java ciphertexts),
`Passwords` (PBKDF2, verifies Java hashes, common-password list), `Totp`, `Hashes`, `SafeHtml`
(jsoup, same allowlist), `MarkdownBio` (commonmark + GFM), `PlainText`, `InlineMedia`, `TextFieldLimit`,
`LikePattern`, `SuspiciousText`, `ContentDuplicationGuard`, `SafeUrl`, `SafeLinks`
(`SafeLinkRequestBodyAdvice` equivalent), `OutboundUrlGuard`, `CityState`, `BooleanQuery`, `BlockedUsers`,
`SanctionGate` + `SanctionGateReader`, `RiskEngine`, `TtlCache`/`Caches` (Caffeine replacement), all wired
by `SharedServices.create(platform)` in `Main.kf`.

Behaviour notes (deliberate differences from Java):

- Outbox: Java never retried or backed off (a failing handler is logged and the event is marked PROCESSED, `next_attempt_at` never moves); the port keeps exactly that and documents it. Each event runs in its own transaction (Java: one for the batch).
- `SafeHtml`: replacements are literal (Java's `Matcher.replaceAll(Function)` read `$`/`\` in the replacement as group references and could throw on a link containing `$1`).
- `Passwords.matches` answers `false` for a malformed stored hash (Java answered 500 on a bad base64 part). `Totp` takes epoch seconds instead of `Instant`.
- `ContentDuplicationGuard.require` is atomic (Java checked then wrote); `BooleanQuery` rejections are `400 BAD_REQUEST` like the `IllegalArgumentException` handler (`BooleanQuery.rejection(raw)` exposes the reason).
- Cache values are JSON Strings (see G43); idempotency actions return the body text and take the status as a parameter (G41).

### Pending ports (defaults wired in `kernel.SharedServices`)

| Seam | Default | Owner / what it needs |
|---|---|---|
| `RiskTimingSignals.looksAutomated(userId)` | `false` (no signal) | security: extend it with `BehavioralTimingGuard` (the rate-limit task owns the guard) |
| `RiskEscalation.escalate(userId, description)` | logs `risk_escalation_unhandled` | moderation: turn the case into a `Report` (USER, SPAM) like the `AutoReportEvent` listener |
| `SanctionGateReader` | reads `user_sanctions` directly | moderation: may extend it; the writes (restrict, ban, appeals) stay there |
| `BlockedUsers` | reads `user_blocks` and `user_mutes` directly | network: owns block/mute writes |
| `OutboxEventHandler` subclasses | none registered | notifications (`NotificationOutboxEventHandler`) and linkedin (`LinkedInShareOutboxEventHandler`) register theirs with `shared.outbox.register(type, handler)` |
| `AgeGate` / `AgePolicyReader` (`shared/age`) | not created | not in this task's list; needs `users.birth_date` and the parental consent table (profile/age domain) |
| `PanicMode`, rate limiters, `ClientIpResolver`, `PiiMask` | not here | security task (PiiMask already lives in `kernel.log`) |

### Java tests that could not be ported (15 of 114)

| Java test | Why |
|---|---|
| `TextFieldLimitTests` (9: company, event, freelance, service offer, game, micro-project, dispute, community, game collection) | MockMvc against domain controllers (`/empresas`, `/events`, `/freelances`, ...) that are not ported yet; the helper itself is covered by `TextTest` (400, field and Brazilian thousands separator). Each domain port must assert its own code (`COMPANY_FIELD_TOO_LONG`, ...) |
| `WriteGateCoverageTests` (5: restricted account in group post, group comment, private message; minor in group post; free account still writes) | need the groups and messaging endpoints and `AgeGate`; `SanctionGate` itself is covered by `ModerationGatesTest`. The coverage test must be re-created when groups and messaging are ported (call `SanctionGate.requireNotRestricted` in every write path) |
| `LinkSchemeAllowlistTests.companyWebsiteRejectsScriptSchemes` | company controller plus migration `V180` replayed on a planted `companies.website` row. `SafeUrl.requireHttpUrl` rejects every disguised URL (`SafeUrlTest`); the company port must assert the endpoint, and the V180 neutralisation belongs to the migration suite |

Ported with an adaptation, not weakened: `LinkSchemeAllowlistTests.markdownLinksInAnyBodyFieldRejectScriptSchemes`
runs against a probe route calling `SafeLinks.checkRequest()` (there is no feed endpoint yet);
`RiskEngineTests` use a stub timing signal (the guard belongs to the security port) and capture the
escalation text instead of reading the `reports` table; `IntelligentCacheTests` assert the same seven
behaviours on `TtlCache`/`Caches` (reuse, expiry loads nothing on its own, renew after expiry, a write
clears after commit, a failed write leaves the cache alone, one load for concurrent callers, closed list of
caches with their policy) because `EventService` is not ported.


## Notifications, push, messaging, calls (`notifications`, `push`, `messaging`, `calls`)

Wired in `Main.kf` in this order (notifications is the sink the other domains write to):
`NotificationsModule.install`, `PushModule.install`, `MessagingModule.install`, `CallsModule.install`.
`install(platform, shared, hooks, parts, ...)` takes `SecurityParts` as a fourth argument (the guide shows three):
messaging and calls need `parts.userLimiter` and `parts.timingGuard`. Tests install a module with `installWith`
and a swapped seam (`tests/*/` boot through `notifications.DomainTestKit`).

Ported: every endpoint (notifications `GET /notifications`, `/notifications/unread-summary`,
`POST /notifications/{id}/read`, `/notifications/read-all`, `GET`/`PUT /me/notification-preferences`,
`GET`/`POST /notifications/digest/unsubscribe`; push `GET /push/config`, `POST`/`DELETE /push/subscriptions`;
the 19 `/conversations/**` routes and the 5 `/e2e/**` routes; the 13 call routes), the outbox handler, the
weekly digest cron, the community apology worker, web push with VAPID (`kernel.push.WebPushAdapter`), the call
expiry worker and the `ConversationViewers.dropExpired` job, all on `kernel.jobs`.

### The Notifications API other domains call (`notifications.Notifications`)

Take it from the module: `var notifications = notificationsModule.notifications`. Every method writes inside the
caller's transaction (a nested `Db.transaction` joins it) and publishes the push event after the outermost
commit (`Db.afterCommit`), so a rolled back write sends nothing.

```
notifications.create(userId, kind, actorId, title, body, href, ctaLabel)            // simple notice
notifications.createWithPreview(..., ctaLabel, preview)                              // + the 140 char preview
notifications.createGrouped(userId, kind, groupKey, actorId, title, body, groupedBody: (Int) -> String, href, groupedHref, ctaLabel, preview)
notifications.createCounted(userId, kind, groupKey, actorId, title, body, countedBody: (Int) -> String, href, ctaLabel)  // "N novos", first one pushes
notifications.createCountedAndPushed(...)                                            // same, every increment pushes (messages)
notifications.markReadByHref(userId, href)    notifications.markRead(id, userId)    notifications.markAllRead(userId)
notifications.addListener(listener)           // NotificationListener.onCreated(event), what push uses
```

`NotificationOutboxEventHandler.forTypes(shared.outbox, notifications, sources, actors)` is registered by
`NotificationsModule.install` for `PostCommented`, `PostReacted` and `CommentReacted`. Other domains register their
own event types on `shared.outbox` as before.

### Pending ports (seams owned by other domains; every default reads the owner's tables read-only)

| Seam | Default | Owner / what it needs |
|---|---|---|
| `NotificationActors` (`notifications`) | reads `users`, `corporate_profiles` | profile and corporate: names, avatars, name style of the actor |
| `NotificationSources` | reads `posts`, `comments` | feed: the post and comment behind an outbox event |
| `NotificationCoins` | grants every reward, `hasReward(ref)` is false | coin: the daily/first notification rewards |
| `NotificationAccounts`, `DigestAccounts`, `DigestPersonalization` | read `users` and the digest sources | identity and feed: who gets the weekly digest and what it shows |
| `NotificationPlaceReader` | reads `communities`, `posts`, `groups`, `events` | communities, groups, events: the place a notice points to |
| `DigestMailer` | logs and answers `false` (nothing is sent) | identity: `EmailService` (the digest and the apology mail) |
| `PushPresence` (`push`) | reads `user_presence` | presence: who is online (no push to them) |
| `MessagingAgePolicy` | reads `users.birth_date` and `parental_links` | profile/age: `AgeGate` and `AgePolicyReader` (`BIRTH_DATE_REQUIRED`, `PARENTAL_CONSENT_REQUIRED`) |
| `MessagingConnections` | reads `user_connections` (ACCEPTED) | network: `ConnectionRepository` |
| `MessagingCorporate` | reads `corporate_profiles` (ACTIVE) | corporate: `CorporateProfileService` |
| `MessagingCoins` | `recordPresence` does nothing | coin: the daily presence streak |
| `CallGroups` (`calls`) | reads `group_members` | groups: `GroupService.roleOf` and `memberIds` |
| `CallProfiles` | reads `users.social_name`, `users.name` | profile: `displayName` |
| `CallClock` | the security clock (tests move it with `SecurityClock.advanceSeconds`) | none: kept as a seam for tests |
| call events (`CallService.publish`) | no listener | the event stream (G201); `CallChanged` has no consumer yet |

Seams are concrete classes with overridable methods (interfaces across packages do not work, G30/G42): the
owner subclasses the default and passes it in `NotificationsSeams` / `MessagingSeamSet` / `CallsSeamSet`.

Configuration: `VAPID_PUBLIC_KEY`, `VAPID_PRIVATE_KEY`, `VAPID_SUBJECT` (push is off without the keys),
`REDE_DIGEST_CRON`, `REDE_COMMUNICATIONS_APOLOGY_*`, `REDE_CALLS_JITSI_URL`, `REDE_CALLS_JITSI_JWT_SECRET`
(32 bytes or more), `REDE_CALLS_JITSI_JWT_ISSUER` (`rede`), `REDE_CALLS_JITSI_JWT_AUDIENCE` (`meet.jitsi`),
`REDE_CALLS_JITSI_TOKEN_TTL_MINUTES` (120). Without the Jitsi address and secret every call start is
`503 CALLS_NOT_CONFIGURED`.

### Java tests not ported (5 of 122)

| Java test | Why |
|---|---|
| `MessageStreamTests` (4: `newMessageIsSignalledToTheRecipientStream`, `readReceiptIsSignalledToTheOtherParticipant`, `streamsPerUserAreCapped`, `streamRequiresASession`) | the runtime cannot hold a response open (G201). `streamRequiresASession` is covered in spirit by `MessagesTest` ("the event stream needs a session and ends with a retry hint": 401 without a session, a closed `text/event-stream` body with `retry: 5000` otherwise); the three that read events from an open stream have no equivalent until the runtime streams |
| `CallMediaProbe.gravaTokensDosDoisLadosDaChamada` | a manual probe, disabled unless `-Dcall.probe.url` points to a real Jitsi stack; it needs a browser and external infrastructure, not a suite |

Ported with a changed setup: `GroupCreationQueryCountTests` (3) keep the behaviour (a large group with one
connected minor, an unconnected minor and a blocked member are decided as in Java) as HTTP tests; the Mockito
call counts (`verify(agePolicy, times(1)).minorIds(...)`) have no HTTP equivalent, so "one read per kind" is
guaranteed by the code (`MessagingService.createConversation` reads blocks and minors once) and not asserted.
`CallFlowTests.atenderERecusarAoMesmoTempoNaoDeixaDoisEstados` ran two threads against MockMvc: here the two
requests run one after the other in both orders (the compare and set in `CallsStore.advance` is what keeps one
state; the loser gets `200` or `409`). `MessageNotificationTests` stub the push sender with
`push.RecordingPushSender` and `inline = true` instead of mocking `PushSender` and `pushExecutor`.
`MessagePreviewOrderTests` ran on a fixed clock; here the assertion is the same (the second message is strictly
later than the first even inside one second) on the real clock.

Deliberate differences: the 100 conversation participants limit, the 10 second duplicate window and the 4 media
limit are the Java values; `PushService` is `PushSubscriptionService` (G206); a send with `"e2e": true` checks the
ciphertext (`EMPTY_MESSAGE`, `MESSAGE_TOO_LONG` over 8000) and the IV (`MISSING_IV`) before storing.
