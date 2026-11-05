# Porting status

| Domain | Endpoints ported / total | Tests ported / total | Gaps |
|---|---|---|---|
| shared/web + shared/security (request pipeline) + `apiv1` origin gate | `GET/POST /admin/panic` 2/2 (the `/v1` index and `/developers/origins` CRUD belong to `apiv1`) | 87 / 100 Java tests (149 Kof tests in `tests/security/`) | G28 to G35 |
| notifications, push, messaging, calls (slug `messaging`) | notifications 8/8, push 3/3, messaging 24/24 (`GET /conversations/stream` answers but cannot stream, G201), calls 13/13 | 117 / 122 Java tests (notifications 34/34, push 21/21, messaging 51/55, calls 11/12; 127 Kof tests in `tests/notifications`, `tests/push`, `tests/messaging`, `tests/calls`, `tests/kernel/WebPushAdapterTest.kf`) | G200 to G212 |
| games, dailygames (slug `games`) | games 42/42, dailygames 13/13 | 41 / 41 Java tests (games 28/28, dailygames 13/13; the `null` event list assertion of `BlocksEngineTest` has no Kof counterpart; 52 Kof tests in `tests/games`, `tests/dailygames`, `tests/kernel/GamesAdaptersTest.kf`) | G260 to G265 |


> Cross-domain seams: since the tidy-up round every seam whose owner is ported is switched in `src/app/AppWiring.kf` to a
> bridge that calls the owner's API. `docs/SEAMS.md` is the inventory (seam, caller, owner, status) and supersedes the
> "pending port" tables below for those seams; the defaults described below remain only as the test defaults of each
> domain suite. Left: the moderation seams and the OPEN rows of SEAMS.md.

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

## media

| Domain | Endpoints ported / total | Tests ported / total | Gaps |
|---|---|---|---|
| media (uploads, assets, `/storage` proxy, S3 and ImageKit modes, sanitiser, workers, migration) | 6 / 6 | 69 / 76 Java tests (88 Kof tests in `tests/media/`) | G160 to G169 |

Endpoints: `POST /media/uploads`, `GET /media/{id}`, `DELETE /media/{id}`, `GET /media/migration`,
`GET /storage/{key}` (Range, `Cache-Control` immutable) and `PUT /storage/{key}` (the owner's session, the
exact key of the asset, the declared size).

Ported: assets and deletion jobs on the same tables, upload validation (types, purposes, 500 MB), the S3
mode (`REDE_MEDIA_STORAGE=s3`: URL factory, signer that goes through the app when moderation is on, gateway)
and the ImageKit mode (the default: uploads answer 503 `UPLOADS_DISABLED`), the metadata sanitiser (JPEG with
physical EXIF rotation, PNG, GIF, WebP, video and audio through ffmpeg on `ProcessRunner`), image-content
moderation (classifier and reviewer seams), width and height (on upload and the backfill job),
`MediaDeletionWorker`, `MediaMigrationService` + worker + `MediaLazyCopyTrigger`, `LazyUrlMigrationService`
(SSRF guarded by `OutboundUrlGuard`), `MediaResilience` (retry 3 x 250 ms, circuit breaker, bulkhead of 4 on the
storage gateway: a small helper with no kernel dependency but `Gate`/`Permits`), the S3 REST client with
Signature V4 (`kernel.storage.S3Rest`, G160).

### Large bodies and binary data (read this)

The Kof web runtime reads every request body as a UTF-8 String and writes every response body as a String, so
the Java `PUT/GET /api/storage/{key}` (raw image/video bytes, up to 500 MB, Range) cannot be an ordinary route
(measured, G161). The workaround is a kernel adapter, `kernel.http.BinaryLane` + `BinaryFront`: when a module
claims a route prefix (`BinaryLane.claim("/storage/")`), `Platform.start` moves the web runtime to an internal
loopback port and serves the public port with a byte-level front that forwards every other request unchanged.
For a claimed `PUT` the front asks the route to authorise (the whole security pipeline runs, no body read yet),
then spools the body to a temp file and calls the route again with a ticket; for a claimed `GET` the route
registers a stream and the front sends the bytes. Consequences for operators: the service is one hop heavier
(loopback), the internal port must not be published, `REDE_BINARY_MAX_BODY_BYTES` caps one upload (default
520 MB), and an upload is spooled to disk (`java.io.tmpdir`), never held in memory. Nothing else changes: the
gateway still sees one port.

### Pending ports (seams)

| Seam (class in `media`) | Default | Owner / what it needs |
|---|---|---|
| `MediaImageClassifier` (`available`, `pornographicScore`) | not available: with `REDE_MEDIA_NSFW_ENABLED=true` (the default) an image upload answers 503 `IMAGE_MODERATION_UNAVAILABLE` | media: the ONNX OpenNSFW model (`OnnxImageContentClassifier`) needs a runtime that is not reachable from Kof yet. Run with `REDE_MEDIA_NSFW_ENABLED=false` only if moderation happens elsewhere |
| `MediaImageReviewer.review` | no answer (fails closed, 503) | moderation: `ModerationImageContentReviewer` |
| `MediaPdfCleaner.clean` | passes the bytes through | media: PDFBox (G164): PDFs keep author and title meanwhile |
| `MediaObjectStore`, `MediaStorageGateway`, `MediaUploadSigner` | S3 (`MediaS3ObjectStore`, `MediaS3Gateway`, `MediaS3UploadSigner`) or ImageKit | tests use `MediaLocalObjectStore` or a fake |
| S3 credentials | `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN` | the web-identity (IRSA) provider is not ported |

What other domains call (on `MediaModule.service`, wired in `Main.kf`): `visibleByIds(ids): Map<String, MediaSummaryView>`
(feed, groups, profile cards), `validateOwnedBy(ownerId, ids)` (post and comment creation),
`requestPostMediaDeletion(ownerId, postId, ids)` (post deletion), and `MediaModule.onUrlAccess(url)` (profiles,
covers and logos call it when they serve a legacy ImageKit URL). Each of those domains owns its seam class and
subclasses it over these methods.

Deliberate differences from Java:

- ImageKit mode without `IMAGEKIT_PRIVATE_KEY`: deletion jobs use the no-op gateway and a warning is logged (Java called
  the ImageKit API with an empty key and failed forever).
- A JPEG rotated by its EXIF orientation is re-encoded at the ImageIO default quality (G163).
- The `{*key}` wildcard is registered once per depth (1 to 10 segments), the router matches by segment count.
- Retry waits and the circuit breaker's open state (60 s, the library default) are fixed values, not Spring properties.

### Java tests that could not be ported (7 of 76)

| Java test | Why |
|---|---|
| `OnnxImageContentClassifierTests` (6: animated GIF budget, frame sampling, partial-frame compositing, disposal method, NHWC buffer, centre crop) | the classifier is the ONNX Runtime model, pending (see the seam table). Port them with the classifier |
| `MediaMetadataSanitizerTests.pdfDocumentInformationIsCleared` | PDF cleaning is a seam without PDFBox (G164). The pass-through default is asserted by `empty, unknown and unreadable data come back unchanged` |

Ported with a changed trigger: `MediaControllerTests.deletesMediaReferencedByDeletedPost` calls
`requestPostMediaDeletion` (what the feed calls on post deletion) because the feed endpoint is not part of this
domain; the `/storage` tests use real bytes through the binary lane; `MediaStorageProxyTests` and the S3 tests run
with fakes behind the `MediaObjectStore` seam, like the Java ones.

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

Groups: `groups.GroupNotifications` (its own seam) inserts into `notifications` directly, so a group notice sends no
push. `notifications.GroupNotificationsBridge` subclasses it and routes `create`/`createCounted` through
`Notifications` (push after commit, preferences, same group-key counter). `Main.kf` passes it with
`GroupsModule.installWith(..., GroupNotificationsBridge(platform.db, notificationsModule.notifications), ...)`.
The `GroupNotifier` outbox handler (`GroupPostPublished`) does not overlap with
`NotificationOutboxEventHandler` (`PostCommented`, `PostReacted`, `CommentReacted`).

### Pending ports (seams owned by other domains; every default reads the owner's tables read-only)

| Seam | Default | Owner / what it needs |
|---|---|---|
| `NotificationActors` (`notifications`) | reads `users`, `corporate_profiles` | profile and corporate: names, avatars, name style of the actor |
| `NotificationSources` | reads `posts`, `comments` | feed: the post and comment behind an outbox event |
| `NotificationCoins` | grants every reward, `hasReward(ref)` is false | coin: the daily/first notification rewards |
| `NotificationAccounts`, `DigestAccounts`, `DigestPersonalization` | read `users` and the digest sources | identity and feed: who gets the weekly digest and what it shows |
| `NotificationPlaceReader` | reads `communities`, `posts`, `groups`, `events` | communities, groups, events: the place a notice points to |
| `DigestMailer` | sends through the shared `MailService` (SMTP, `email_log`, List-Unsubscribe) | none: wired in `AppWiring` |
| `PushPresence` (`push`) | reads `user_presence` | presence: who is online (no push to them) |
| `MessagingAgePolicy` | reads `users.birth_date` and `parental_links` | profile/age: `AgeGate` and `AgePolicyReader` (`BIRTH_DATE_REQUIRED`, `PARENTAL_CONSENT_REQUIRED`) |
| `MessagingConnections` | reads `user_connections` (ACCEPTED) | network: `ConnectionRepository` |
| `MessagingCorporate` | reads `corporate_profiles` (ACTIVE) | corporate: `CorporateProfileService` |
| `MessagingCoins` | `recordPresence` does nothing | coin: the daily presence streak |
| `CallGroups` (`calls`) | reads `group_members` | groups: `GroupService.roleOf` and `memberIds` |
| `CallProfiles` | reads `users.social_name`, `users.name` | profile: `displayName` |
| `CallClock` | the security clock (tests move it with `SecurityClock.advanceSeconds`) | none: kept as a seam for tests |
| call events (`CallService.publish`) | `call` events on the inbox stream (after commit) | none |

Seams are concrete classes with overridable methods (interfaces across packages do not work, G30/G42): the
owner subclasses the default and passes it in `NotificationsSeams` / `MessagingSeamSet` / `CallsSeamSet`.

Configuration: `VAPID_PUBLIC_KEY`, `VAPID_PRIVATE_KEY`, `VAPID_SUBJECT` (push is off without the keys),
`REDE_DIGEST_CRON`, `REDE_COMMUNICATIONS_APOLOGY_*`, `REDE_CALLS_JITSI_URL`, `REDE_CALLS_JITSI_JWT_SECRET`
(32 bytes or more), `REDE_CALLS_JITSI_JWT_ISSUER` (`rede`), `REDE_CALLS_JITSI_JWT_AUDIENCE` (`meet.jitsi`),
`REDE_CALLS_JITSI_TOKEN_TTL_MINUTES` (120). Without the Jitsi address and secret every call start is
`503 CALLS_NOT_CONFIGURED`.

### Java tests not ported (1 of 122)

| Java test | Why |
|---|---|
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
## feed (`src/feed`, tests in `tests/feed/`)

**Ported: 43 / 43 endpoints, 161 / 170 Java tests (163 Kof tests: 2 are Kof-only, `GET /feed/saved` and a trending-cursor check). Gaps G140 to G150.**
Identical paths, status codes, JSON field order, pt-BR codes/messages and `Idempotency-Key` routes.

Endpoints: post core (`POST /feed/posts` for every type, `GET|PATCH|DELETE /feed/posts/{id}`, restore, bulk-delete,
comments, comment pins and reactions, post reactions, saves, shares, poll vote, `GET /feed/saved`) plus, in this pass:
`GET /feed` (tabs ALL, FOR_YOU, UNSEEN, TRENDING with the Base64Url cursor, INTERACTED, FOLLOWING, DISCUSSIONS, RECENT,
PROJECTS, NEWS, TUTORIALS, OPPORTUNITIES, REVIEWS, FUN; date-window pagination and the "voce esta em dia" marker),
`GET /users/{username}/posts` (with repost merge), `POST /feed/seen`, `POST|DELETE /feed/posts/{id}/repost`,
`POST|GET|DELETE /feed/scheduled` with `feed-scheduled-publish` (3 attempts, batches of 20), post seals
(`/feed/posts/seals`, `/{postId}/seals`, `/{postId}/seals/people`), `GET /feed/corporate`,
`GET /corporate/{u}/posts`, post notes (`/feed/posts/{id}/notes`, `GET|PATCH /admin/notes`), accepted answers,
`GET /pages/{postId}` (HTML with the CSP headers) and `GET /pages/{postId}/og.png` (the share card, drawn by `kernel.image.PageCards`
with Java2D and the bundled Liberation font, cached in `pagePreviewCards`, streamed through a GET route claim of the binary lane).
Jobs on `kernel.jobs` (`REDE_FEED_WORKERS_ENABLED`, default true): `feed-moment-expiry`, `feed-scheduled-publish`.
Moderation use cases are exposed on `FeedModule.moderation` (`removeAsModerator`, `quarantine`, `release`,
`removeCommentAsModerator`, `purgeAllByAuthor`); the purge also clears `post_reposts`, `poll_votes`, `poll_options` and
`comment_media`, which the Java list missed.

Deliberate differences:
- `GET /pages/{postId}/og.png` leaves the runtime as a stream (`X-Kernel-Stream`, `BinaryLane.claimDownload`), because a
  handler writes a String as UTF-8 (G145): `GET /pages/{postId}` stays an ordinary route. The gradient is painted pixel by pixel
  (`GradientPaint` takes floats, see KOF_GAPS), so the PNG is not byte-identical to the Java one.
- `FeedDistributionService` and the in-memory feed cache are not ported: in Java `fromCache` is dead code and the cache
  is write-only, so nothing reads it.
- `GET /feed/posts/seals` is registered before `/feed/posts/:postId` because routes match in registration order (G147).
- Counters move with atomic `update ... set n = n + 1`.

Tests not ported (6 of 170, with reason): the actor-style notification test; the BanCleanupService test (moderation port); the coin-ledger
reaction test (`FeedRecordingCoins` records the answer reward in the feed suite; the production wiring pays through `CoinFeedCoins`); the media-embedding Mockito `verify`
test; two identity-presentation tests that need the full profile cosmetics wiring (all four are unblocked by the wired suites, see `docs/SEAMS.md`, not ported yet).
Test wiring: `feed.FeedTestSupport` (limits relaxed, duplicate filters off, outbox worker parked with
`REDE_OUTBOX_WORKER_DELAY_MS`, `FeedTestSupport.finish()` in the last test of each file stops the shared jobs so the
process exits: the Kof runtime waits for spawned tasks at exit, which the runner fix on main does not cover, G150), fixtures
through SQL where the owner is not ported. Test helper names must not shadow kernel functions (`status`) or hit
the parse failure of `audited` (G148, G149).

### Seams owned by the feed (`FeedSeams`, defaults in `FeedModule.install`, production in `AppWiring`)

All switched except `FeedHoneypot` (moderation): see `docs/SEAMS.md`. `FeedModule.installSeams(platform, shared, hooks, seams)`
takes every seam in one `FeedSeams` holder; `install` / `installWith` keep the table-level defaults for the feed suite.

Defaults are kept on purpose: switching them is a one-line `installWith` change once the owner exposes the class, and
the feed suite keeps passing on the table-level defaults.

Exposed for others: `FeedModule.service`, `.store`, `.reader`, `.moderation`, `.scheduled`, `.notes`, `.seals`.
Kernel changes: `Security.parts()` (earlier pass) and `kernel/text/Base64Url.kf` (trending cursor); see `docs/KERNEL.md`.
The G144 root fix lives in the test runner on main; the feed makes no scheduler change.

## profile (profile, network, preferences, presence)

Slug `profile`, branch `port/profile`. One module entry: `ProfileModule.install(platform, shared, hooks)` (one line in `Main.kf`, after `Security.install`); it also installs network, preferences and presence.

| Domain | Endpoints ported/total | Kof tests | Java tests ported/total |
|---|---|---|---|
| profile (`src/profile`) | 33/33 route+method pairs (35 Java mappings, `/ranking` and `/profile/ranking` are one mapping, the two public lists live in network) | `ProfileApiTest`, `ProfileFieldsTest`, `ReputationTest`, `ProfileThrottleTest` | 84/87 |
| network (`src/network`) | 16/16 (14 Java mappings + `/users/{u}/connections` and `/followers`, which Java serves from `profile`) | `NetworkTest` | 16/16 (all adapted, see below) |
| preferences (`src/preferences`) | 5/5 | `PreferencesTest` | 23/27 |
| presence (`src/presence`) | 4/4 | `PresenceTest` | 3/3 |

Total: 58 of 58 endpoints, 126 of 133 Java tests ported (the rest has a reason below).

### Read API other domains use

| Class | Use |
|---|---|
| `ProfileDirectory` | read-only: `findById`, `findByUsername`, `existsByUsername`, `exists`, `findAllByIds(ids)` (3 batch queries, never one per row), `findNewest`, `search`, `findAdmins`, `displayName(id)`, `nameStyle(profile)`. Feed, groups, communities, messaging... resolve authors through it. |
| `ProfileSlots` | cosmetic-slot writes for the cosmetics/shop port: `updateAvatarFrame`, `equipNameStyle` (clears font and color: zero neighbour fields), `updateNameStyle`, `updateContributorTagColor`, `updateProfileCosmetics` (a banner or banner HTML clears `banner_item`), `updateGardenStyle`, `updateStatus`, `updateBadges` (keeps the single `badge` column in sync) |
| `ProfileReputation` | `countsFor(userId)`, `reputationOf(userId)`, `refreshRankingColumn()`; the job runs on `kernel.jobs` (`REDE_REPUTATION_REFRESH_DELAY_MS` 1800000, `REDE_REPUTATION_REFRESH_INITIAL_DELAY_MS` 60000) |
| `NetworkService` | `friendIds`, `friendsOfFriends`, `userTags`, `connections` (recommendation and feed ranking) |
| `PreferencesService` | `likedTopics`, `blockedTopics` (feed personalization) |
| `PresenceService` | `publicStatus`, `allowPush` (messaging/push gating) |
| `ProfileModule` | the instance returned by `install` exposes all of the above (`directory`, `slots`, `reputation`, `network`, `preferences`, `presence`) |

### Seams owned by this slice (concrete classes, default reads the owner's tables read-only, marked `// pending-port: <owner>`)

| Seam | Default | Owner / what to do |
|---|---|---|
| `ProfileNotifier.notify` | one insert into `notifications` (admin promotion, connection requests/acceptances) | notifications: extend and call `NotificationService.create` (the push event after it is also pending) |
| `ProfileBadgeOwnership` | `cosmetic_grants` + PURCHASE `coin_entries` (`cosmetico:<user>:<item>`); cannot check the catalog kind, so any owned `emblema-` id passes | cosmetics: `OfficialBadgeReader` over the catalog |
| `ProfileParentalLinks.activeForMinor` | `parental_links` ACTIVE row | age |
| `ProfileForeignCounts` | `socialPosts` (posts), `uniqueEngagers` (reactions + comments), `communitiesJoined`, `eventsAttendedTotal`, `mentoringAsMentee`, `confirmedReportFacts` (reports), `deniedNotes`/`approvedNotes` (post_notes), `jobAbandons` | feed, communities, events, mentoring, moderation, jobs: each owner overrides its method(s) |
| `PreferencesThemeGallery` | `theme_gallery` PUBLISHED rows | themes (gallery) |

Cross-domain duties of the neighbours (not seams of this slice): the moderation port must clear the `publicRanking` cache and evict the public profile entries (`Caches.get("publicProfiles")`) when it sanctions a user; `BlockedUsers` (kernel) stays the single read of blocks and mutes, this slice owns the writes.

### Differences from the Java service (on purpose or forced)

- `LazyUrlMigrationService` (media) is not called: media URLs are served as stored. Pending with the media port.
- Dates that Java computed with the server clock in `America/Sao_Paulo` use UTC-3 (`Dates.todayBrazil`): Brazil has no daylight saving time since 2019.
- `GET /users/search` without `q` is a 500, like Java (an uncaught missing-parameter exception).
- Appearance JSON decoding is tolerant of the whole document (a broken document is an empty look, unknown keys are ignored), like `ProfileAppearanceJsonTests`.
- The idempotency body hash is the JSON of the decoded DTO, not the raw request text (same retry semantics: equal bodies replay, different bodies are a conflict).
- Network list and suggestion views carry `connections=0` and `followers=0` (Java never filled them for lists); `/network/users` keeps the Java order, the `HashSet` iteration order of the ids (`kernel.text.HashOrder`).
- The profile update throttle is `REDE_PROFILE_UPDATES_PER_HOUR` (default 30), recommendations `REDE_PROFILE_RECOMMENDATIONS_PER_DAY` (default 20).
- Preference validation codes keep the accented upper-case spelling the front end matches (`INVALID_MÓDULO`).

### Java tests not ported (7 of 133)

| Java test | Why |
|---|---|
| `NameplateInListsTests` (3: groups, feed comments, community members) | need the groups, feed and communities endpoints. Adapted instead: `NetworkTest` "the people lists carry the nameplate of each person" (network and public lists, authors loaded in one batch query). Re-port the three when those domains land. |
| `PersonalizationSecurityTests.blockedTopicDoesNotHideThePostByDirectLink` | needs the feed post endpoint (direct link). The topic rules it protects are covered by the preferences tests; re-port with feed. |
| `PersonalizationSurfaceAuditTests` (3) | audit the personalization hooks of feed, search and recommendations responses; need those domains. |

Ported with an adaptation, not weakened: tests that watch the feed, groups or sanction endpoints read the same effect through `BlockedUsers.hiddenIdsFor` or insert the fixture row by SQL (gallery themes, sanctions, posts); admin fixtures use `SecurityFixtures.user(..., admin = true)`; `ReputationServiceTests` seed the tables the default `ProfileForeignCounts` reads instead of mocking repositories; `ProfilePublicCacheTests` observe the cache through direct SQL changes versus API edits; `ProfileUpdateThrottleTests` run on a separate boot with `REDE_PROFILE_UPDATES_PER_HOUR=3`; `ProfileAppearanceServiceTests.unknownProfileIsNotFound` calls the service (a session cannot outlive its user).

### Kernel changes made by this slice

`kernel.time.Dates` (new), `kernel.text.Texts` (`isBlank`, `hasText`, `trimIfText`), `kernel.text.Nulls` (new), `kernel.text.HashOrder` (new), `kernel.security.Totp` (otpauth label encoded by hand, same output: scout fix for two suites that failed with a VerifyError on this JDK, G127). No other existing kernel behaviour changed. Documented in `docs/KERNEL.md`; gaps G120-G126 in `docs/KOF_GAPS.md`.
## Groups wave: groups, communities, communityprojects, studypairs

| Domain | Endpoints ported / total | Tests ported / total | Gaps |
|---|---|---|---|
| groups | 31 / 31 (`GroupController` 14, `GroupContentController` 17) | 52 / 52 Java tests, plus 4 of the 5 shared `WriteGateCoverageTests` (57 Kof tests in `tests/groups/`) | G180 to G182 |
| communities | 21 / 21 | 18 / 19 Java tests (22 Kof tests in `tests/communities/CommunitiesTest.kf`) | G190 to G193 |
| communityprojects | 13 / 13 | 1 / 1 Java tests (3 Kof tests in `tests/communityprojects/`) | G194, G195 |
| studypairs | 7 / 7 | 30 / 30 Java tests (31 Kof tests: 25 in `StudyPairFlowTest.kf`, 6 in `StudyPairConcurrencyTest.kf`) | G196 |

`Main.kf` installs the four modules after `Security.install` (`GroupsModule`, `CommunitiesModule`,
`CommunityProjectsModule`, `StudyPairsModule`).

### groups

Ported: create / edit (SafeHtml cover, blank clears an image, null keeps), discovery and page by slug or id (public:
presentation only), join (OPEN becomes a member, APPROVAL a pending request, one pending per person), leave, owner
transfer, member removal, request list / approve / reject (atomic: the second decision is 409), platform state
(RESTRICTED, SUSPENDED, ACTIVE; admin only, audited, owner notified), close by the owner, topics (create, edit,
archive, reorder), the private feed (publish with the ECA and sanction gates, list, pin / unpin / pinned, comments with
replies and edits, reactions, local moderation removal), the new-post fan-out on the outbox worker (one counted
notification per member while unread), and the permission table (`GroupPermissions`, byte-identical rules).

Deliberate differences from Java:

- `groups.member_count` is no longer reset to 0 by `save(group)`: the Java merge of a detached entity wrote 0 on every
  edit, status change and transfer (nothing reads the column, the views count rows). Updates here leave it alone and the
  counter never goes below zero.
- Idempotency hashes are over the raw body text (plus ids), not over the Jackson tree of the DTO: they only need to be
  stable inside this service.
- An unknown `joinMode` is `400 BAD_REQUEST` (what Jackson answered for an unknown enum constant).

#### Pending ports (seams owned by groups, defaults wired by `GroupsModule.install`)

| Seam (class in `groups`) | Default | Owner / what it needs |
|---|---|---|
| `GroupProfileLookup` (`find`, `findAll`, `nameOf`) | reads `users` (name, social name, nickname, avatar, badges, frame, name style) | profile: `displayWithNickname`, `allBadges`, `NameStyleView` |
| `GroupAgeGate.requireCanWrite` | reads `users.birth_date` and `parental_links` (ACTIVE), Sao Paulo date | profile/age: `AgeGate` (`BIRTH_DATE_REQUIRED`, `PARENTAL_CONSENT_REQUIRED`) |
| `GroupMediaLookup.visibleByIds` | reads `media_assets` (`delete_status = 'NONE'`) | media: `MediaSummaryView` |
| `GroupNotifications` (`create`, `createCounted`) | inserts / updates `notifications` like `NotificationService`, no push | notifications: push, preferences |
| `GroupCoins.recordPresence` | no-op | coin: daily presence streak |

What groups exposes: `GroupsModule.reports` (`GroupReportReader.read("GROUP_POST" | "GROUP_COMMENT", id)` gives text and
author for the moderation panel), `GroupsModule.groups` / `.feed` services, `GroupNotifier` (registered on the outbox
for `GroupPostPublished`), `GroupPermissions`, `GroupsTestKit` (test fixtures).

#### Java tests not ported as such (adapted, assertions kept)

| Java test | Adaptation |
|---|---|
| `GroupNotificationsTests` (10) | they read `GET /notifications` (notifications domain): the same facts are asserted on the `notifications` rows, and the outbox worker is drained by hand (`processPending`) instead of waiting for its timer |
| `GroupReportsTests` (1) | the report endpoints are the moderation domain's: asserted on `GroupReportReader`, the part groups owes the panel |
| `GroupFeedTests.publicacaoDeGrupoNaoVazaParaOFeedPrincipal` | `/feed` is the feed port's: asserted structurally (the text lives only in `group_posts`, never in `posts`) |
| `GroupCommunityIsolationTests` (1) | the community post is seeded in `posts` (`POST /feed/posts` is the feed port's); both feeds are read over HTTP |
| `GroupPlatformTests`, `GroupNotificationsTests` | the platform admin is a `users.is_admin` row instead of the `group-admin@test.com` allowlist |
| `WriteGateCoverageTests` (5, from shared) | the 4 group tests are ported in `GroupWriteGateTest.kf` (plus `BIRTH_DATE_REQUIRED`); the private-message one belongs to messaging |

### communities

Endpoints ported 21/21 (`CommunityContractController`). Tests 18/19 Java tests ported (22 Kof tests). Ported: community
CRUD (create/patch with SafeHtml banner, optional description, city/state, ownership rules), join/leave (owner transfer
required, last member deletes), transfer, delete (owner or admin), members (user ids only for signed-in viewers),
favorites, /mine, /local, search/filters (topic, q, city, state, cursor), private channels (members only, limit 30, topic
taxonomy, unique slugs), community and channel feeds, pinned post, and the feed-side readers `CommunityDirectory`
(`PostCommunityReader`) and `CommunityChannelDirectory` (`CommunityChannelReader`).

Deliberate differences: the `communitiesList` cache is not ported (same results without it); `limit` is clamped to 1..100
(Java was unbounded).

| Seam (owned by communities) | Default | Owner / what it needs |
|---|---|---|
| `CommunityProfileLookup` (cards, placeOf) | reads `users` read-only | profile: displayWithNickname and NameStyleView parity |
| `CommunityFeedLookup` (postRef, communityFeed, channelFeed, post) | reads `posts` read-only, minimal post JSON | feed: real PostView and FeedPage |
| `CommunityCoins.recordPresence` | no-op | coin: CoinService.recordPresence |

Ported in `tests/integration/CommunitySeamsTest.kf` (was: not ported, 1 of 19): `CommunityChannelTests.channelRulesAreEnforcedByTheBackend` exercises `POST /feed/posts`
(`CHANNEL_REQUIRES_COMMUNITY`, `TOPIC_FROM_CHANNEL`, `CHANNEL_NOT_FOUND` on publish): feed port. The feed-side
assertions of `channelsAreVisibleOnlyToCommunityMembersAndStayOutOfEveryFeed` (`GET /feed/posts/{id}` 404 for channel
posts, `/feed`, `/users/x/posts`) also belong to the feed port; the community-side half is ported. Pin and local tests seed
`posts` and `users.city` by SQL instead of `POST /feed/posts` and `PATCH /me/profile`.

### communityprojects

Ported: catalogue (search by title/description/tags, order recent or title, offset cursor), creator list and page by
`/:username/:slug`, `/me/community-projects`, submit, edit (slug rules), resubmit, delete, moderation queue, approve,
reject, admin suspend and unsuspend. Difference on purpose: catalogue paging reads limit+1 rows from the offset (Java
returned a short second page).

| Seam (owned by communityprojects) | Default | Owner |
|---|---|---|
| `CommunityProjectProfiles` | reads `users.username` | profile |
| `CommunityProjectModerators` | reads `moderator_applications` APPROVED | moderation |

### studypairs

Ported: requests and FIFO matching with atomic claim, per-user row lock, DB-backed invariants (V228 unique indexes),
check-ins (one per ISO week, editable), end, anonymous search, popular goals, weekly reminder job (Thursday 18:00
America/Sao_Paulo, `REDE_STUDY_PAIRS_REMINDER_CRON`, claimed in `study_pair_reminders`). All 30 Java tests ported.

| Seam (owned by studypairs, `StudyPairSeams.kf`) | Default | Owner |
|---|---|---|
| `StudyPairProfiles` | reads `users` | profile |
| `StudyPairAgePolicy` | reads `users.birth_date` (Sao Paulo date) | profile |
| `StudyPairPreferences` | parses `user_preferences.disabled_modules` | preferences |
| `StudyPairNotifier` | single insert into `notifications`, no push | notifications |

Tests changed trigger, assertion kept: preferences seeded in `user_preferences` instead of `PUT /me/preferences`; the
push-off test checks only the in-app row; the reminder schedule test uses `Cron.next` plus the registered job instead of
reflection on `@Scheduled`. The topic list is copied from `ContentTaxonomy` into `StudyPairRules.topics()` (and into
`CommunityRules.topics()`): preferences owns it upstream.
## gifs

| Domain | Endpoints ported / total | Tests ported / total | Gaps |
|---|---|---|---|
| gifs (`src/gifs/`, tests in `tests/gifs/`) | 1 / 1 (`GET /gifs/search`) | 12 / 12 Java tests (18 Kof tests: 6 extra for provider URLs, failure mapping, limit floor and malformed limit, term normalisation, failure not cached, key availability, community provider) | G170 to G172 |

Ported: `GifSearchService` (first available provider that answers wins, Tenor before GIPHY, a failing provider hands over to the next, all failing rethrows `502 GIF_PROVIDER_ERROR`, no key anywhere answers `available: false`), the cache `gifSearch` (`term|limit`, 10 min, failures not cached), the Tenor and GIPHY payload mappers, `CommunityGifProvider`.
Env: `REDE_GIFS_TENOR_KEY`, `REDE_GIFS_GIPHY_KEY` (cache TTL: `REDE_CACHE_GIF_SEARCH_TTL`).

| Seam (class in `gifs`) | Default | Owner / what it needs |
|---|---|---|
| `GifHttp.get(url)` | `kof.http` GET, 8 s timeout (any failure is a 502) | tests subclass it; nothing else |
| `GifCommunityReader.search(term, limit)` | finds nothing | feed: `CommunityGifAdapter` (comments with a `.gif` URL matching the term). Java never registers `CommunityGifProvider` as a bean, so it is not wired here either; wire it (third provider) only if the feed port wants the "Comunidade" source |

Behaviour notes: the Java `Math.clamp(limit, 1, 50)` and the trim + lower-case of `q` are kept; a malformed `limit` answers `400 BAD_REQUEST` (Spring's argument mismatch). The Java suite had 5 MockMvc + 3 service + 3 mapping + 1 unavailable = 12 tests; all are ported with the same assertions.
## linkedin

| Domain | Endpoints ported / total | Tests ported / total | Gaps |
|---|---|---|---|
| linkedin (share on LinkedIn) | 2 / 2 (`GET`, `PUT /me/integrations/linkedin`) | 15 / 15 Java tests (11 Kof tests in `LinkedInApiTest`, 9 in `LinkedInServiceTest`: one per Java test plus extras: bad body 400s, encrypted-at-rest row and unlink, the real HTTP client against a local stub) | G176 to G178 |

`LinkedInModule.install(platform, shared, hooks)` registers the routes and the `PostPublished` handler
(`shared.outbox.register`). The token is stored with `shared.cipher` (nothing is stored without the key).
`service.remember(userId, memberSub, accessToken, expiresAtIso)` and `service.remove(userId)` are for identity's OAuth link,
login and unlink (the Java callback code is not in this domain).

Seams (defaults in `LinkedInModule.install`):

| Seam | Default | Owner / what it needs |
|---|---|---|
| `LinkedInPostLookup.findById` | reads `posts` (id, author_id, content, status, type, author_identity) read-only | feed: `// pending-port: feed`; extend it when the feed store exists |
| `LinkedInShareClient.share` | `LinkedInHttpShareClient` (POST `https://api.linkedin.com/v2/ugcPosts` via `kernel.http.Outbound.attempt`) | tests extend it with a stub; the endpoint is a constructor argument |
| `LinkedInClock.nowIso` | `Time.nowIso()` | tests extend it to fix the clock (Java `Clock.fixed`) |

Kernel: outbound POST with status goes through the shared `kernel.http.Outbound.attempt` (G178). Base URL of the share link: `REDE_FRONTEND_BASE_URL` (default `https://enois.ia.br`, the Java `rede.frontend.base-url`).

## emotes

| Domain | Endpoints ported / total | Tests ported / total | Gaps |
|---|---|---|---|
| emotes (`src/emotes/`) | 3 / 3 (`GET /emotes`, `GET /emotes/index`, `GET /emotes/image/{provider}/{id}` through the binary lane) | 55 / 55 Java tests (67 Kof tests in `tests/emotes/`, 6 in `tests/kernel/HttpFetchBytesTest.kf`) | G173 to G175 |

Ported: the sticker catalog built in memory (`EmoteCatalogService`: last good copy per source, priority merge,
popular rank, animated flag, name policy and the blocked-artwork gate), the four live sources (BTTV global, FFZ
global, FFZ animated listing, FFZ popular listing) behind the `EmoteFeed` seam, the embedded snapshot
(`resources/emotes/catalogo.json`, copied verbatim; override the path with `REDE_EMOTES_CATALOG_FILE`), the image
cache with the CDN fetch behind the `EmoteImageFetcher` seam, the boot build and the 3-hourly refresh on
`kernel.jobs` (`REDE_EMOTES_REFRESH_ENABLED`, `REDE_EMOTES_REFRESH_CRON` default `0 0 */3 * * *`,
`REDE_EMOTES_POPULAR_PAGES` 3, `REDE_EMOTES_ANIMATED_PAGES` 2), and the two JSON reads with `ETag`, `Cache-Control`
and `304`.

Behaviour notes:

- Image route pending: the runtime cannot send raw bytes (G175). `EmotesModule.image(provider, id, variant)` returns
  the `EmoteStoredImage(bytes, contentType)` or null (404) with the Java rules (blocked artwork, animation known
  from the catalog, cache, two tries, static fallback). The route must answer the content type of the image,
  `X-Content-Type-Options: nosniff` and `Cache-Control: max-age=604800, public, immutable`.
- The image cache is a plain in-process map with a 48 MB budget (oldest entries go first) and a 7 day expiry, not
  Caffeine. `EmoteCatalog.etag()` is a hash of the content plus the build second (the Java value was
  `hashCode()` based); only the `W/"..."` shape is part of the contract.
- A refresh that starts while another one runs is skipped (`kernel.concurrent.Gate.tryEnter`); Java's `synchronized`
  made it wait and then repeat the same work.
- `OutboundUrlGuard` is not used: every upstream address is a constant plus an id validated against
  `[A-Za-z0-9]{1,40}` (as in Java), so no user text becomes a host.
- `popularRank` is `-1` inside the `Emote` record for "none" (a nullable `Integer` in Java) and `null` in the JSON.

### Pending seams

| Seam | Default | Notes |
|---|---|---|
| `EmoteFeed` (provider JSON GET) | real HTTP through `kernel.http.Outbound.getBytes` | tests subclass it |
| `EmoteImageFetcher` (CDN image GET) | real HTTP, 4 s connect / 6 s read, `image/*` only, 1 MB cap | tests subclass it |
| binary route `GET /emotes/image/{provider}/{id}` | not registered | media port (binary lane) calls `EmotesModule.image` |

### Java tests that could not be ported as written (all 55 have a Kof counterpart)

| Java test | Adaptation |
|---|---|
| `EmoteCatalogSchedulerTest.erroQueNaoEExcecaoNoBootNaoEscapaDaThread` | Kof throws only Strings (no `Error`): asserts the failing boot build is logged, not counted as a failed job run, and the job survives |
| `EmoteCatalogSchedulerTest` (4) | the Java boot thread and `@Scheduled` are the kernel jobs `emotes-boot` (one run, then a 10 year period) and `emotes-refresh` (cron); the mock service is a subclass overriding `refresh()` |
| `EmoteControllerTest.imagemVemDoCacheComCacheLongo`, `imagemDeFigurinhaAnimadaPedeOArquivoEmMovimento`, `imagemDeFigurinhaDesconhecidaNaoTentaOArquivoAnimado`, `imagemDeProvedorDesconhecidoResponde404` | asserted on `EmotesModule.image` (content type, URLs fetched, null for 404); the status and the `Cache-Control`/`nosniff` headers wait for the binary route |
| `EmoteSourcesTest`, `EmoteImageCacheTest`, `EmoteImagesTest` | JSON is passed as text instead of a Jackson tree; the stubbed CDN is an `EmoteImageFetcher` subclass |

## identity (identity, age, onboarding)

Slug `identity`, branch `port/identity`, gaps G100 to G109. Code in `src/identity`, `src/age`, `src/onboarding`; tests in
`tests/identity` (one H2 app per file, real migrations, no network).

- **Endpoints: 47 of 47** (`/auth/**` 33 including the 8 OAuth routes, `/identity/**` 6, `/age/parental/**` 5,
  `/me/onboarding/**` 3), same paths, status codes, JSON and pt-BR codes and messages.
- **Tests: about 90 of the 98 Java `@Test`s ported** (167 Kof tests in `tests/identity`, the rest are extra edge cases and
  the kernel adapters: Tokens, Outbound, Jwt). Each Java test name appears in the Kof test name.
- **Jobs on `kernel.jobs`:** `identity-session-rehash` (every 60 s, SessionTokenHashMigration) and
  `identity-pending-signup-cleanup` (15 s then 180 s, PendingSignupCleanupWorker).

### Kernel files added (no existing kernel file changed in behaviour)

`kernel/security/Tokens.kf` (random tokens, HMAC-SHA256, base64), `kernel/security/Jwt.kf` (RS256 verify against a JWKS,
RS256 and ES256 signing, plain `java.security`, no third-party jar), `kernel/http/Outbound.kf` (one HTTP call with timeouts
and any method), `kernel/url/UrlCodec.kf`. The jose4j/nimbus jars were not needed.

### Seams owned by this slice (concrete classes with overridable methods, defaults wired in `Main.kf`)

| Seam | Default | Replaced by |
| --- | --- | --- |
| `IdentityUsers` (profile reads and writes of `users`) | direct SQL on `users` | profile |
| `IdentityMailer` (mail) | renders the templates with the kernel `HtmlTemplate` (byte for byte what Thymeleaf renders, proven by golden files) and sends through the shared `MailService` | none |
| `IdentityTurnstileTransport` | `Outbound.postForm` to siteverify, fail-closed | tests stub it |
| `IdentityIpBlocks`, `IdentitySignupGuard` | read `blocked_ips` (5 s cache); per-pod name pattern and cooldown guard | moderation |
| `IdentityNotifier` | logging no-op (new device, parental events) | notifications |
| `IdentityOAuthTransport` | `Outbound` to the providers and their JWKS | tests stub it |
| `IdentityOAuthLinks` | logging no-op for the LinkedIn posting token and the GitHub identity and token | linkedin, contributions |
| `IdentityVerificationProvider` list | gov.br (only active with `REDE_IDENTITY_GOVBR_*`), so the verification is unavailable by default | a legitimate private provider |
| `IdentityEligibility` (JobPublishingPolicy) | reads `users.reputation`, rule `> 150` and, when enforced, a verified identity | jobs |
| `OnboardingActions` | liked topics and skills merged by SQL; community, group and connection joins only report what is already in place (logged `pending-port`) | preferences, communities, groups, network |
| `AgePolicyReader` and `AgeGate` | owned here: other domains (feed, messaging) call `requireDeclared` / `requireCanWrite` | n/a |

### Seams expected from other domains

`/me/age-state` and `/me/birth-date` stay in profile (already ported). Feed and conversations must call `AgeGate`. The
onboarding joins need the real communities, groups and network services (`OnboardingActions` subclass).

### Java tests not ported

- `AgePolicyTests.regularizationUnlocksWriting` and `strangerCannotMessageMinorButConnectionCan`: need `/feed/posts` and
  `/conversations`. The gate itself is covered with a probe route in `ParentalTest` and by `minorIds` in the policy reader.
- `AuthProfileFlowTests` profile and feed parts, `AccountHardening` rename-to-admin (profile PATCH).
- `PasswordChangeEndsSessionTests` end-to-end keypair and `TwoFactorFlowTests` `/notifications`: replaced by probe routes.
- `AuthThrottleKeyTests`: already ported in the security `LimitersTest`.
- `OnboardingFlowTests.completeFollowsTheManualJoinRules`, `connectionRequestsSkipInvalidTargetsAndAreNotDuplicated`,
  `manualJoinOfUnknownCommunityIs404`: need communities, groups and network. Ported with seeded rows: only what is already
  in place counts as joined, self and unknown ids are skipped, an approval group is never joined.
- `SessionTokenHashingTests.savesOnlyHashesAndStillLooksUpByRawToken`: covered at HTTP level (the table keeps only hashes).

### Differences from the Java service

- The POST `/auth/oauth/{provider}/callback` (Apple form_post) keeps the Java behaviour: a refusal is the JSON error, only
  the GET callback redirects.
- OAuth account creation sets no terms acceptance and no birth date (as Java); `users.create` and
  `createFederated` write every column default explicitly because the Kof insert has no JPA defaults.
- Provider env names: property style (`REDE_OAUTH_GOOGLE_CLIENT_ID`) first, then the short ones the Java profiles read
  (`GOOGLE_CLIENT_ID`).
## Leaf domains: ops, apiv1, stats, search, themes, projects, notices, releasenotes, suggestions, blog

Slug `leaves`, branch `port/leaves`. Modules installed in `Main.kf`: `OpsModule` and `ApiV1Module` BEFORE `Security.install` (the pipeline captures `hooks.monitoring` and `hooks.origins` by value), the other eight after it.

| Domain | Endpoints ported/total | Kof tests | Java tests ported/total |
|---|---|---|---|
| ops (`src/ops`) | 4/4 (`GET /admin/monitoring/overview`, `/users`, `/events`, `GET /admin/emails`) | `tests/ops/*` (19), `tests/kernel/{DayLog,HostResources,RequestMetrics,EventBuffer,Numbers,ZoneDates}Test` | 12/12 |
| apiv1 (`src/apiv1`) | 7/7 (`GET /v1`, `GET/POST/DELETE /developers/origins`, `GET /admin/developers/origins`, `POST .../{id}/block`, `.../unblock`) | `tests/apiv1/ApiV1Test` (9) | 27/27 (gate-only tests live in `tests/security/OriginTest` and `IdentityRateLimitTest`, the rest in `tests/apiv1`) |
| stats | 1/1 | `StatsTest` (2) | 2/2 |
| search | 1/1 | `SearchTest` (7) | 5/6 (the `/mentors` search belongs to the mentoring domain) |
| themes | 8/8 | `ThemeTest` (9) | 7/7 |
| projects | 5/5 | `ProjectsTest` (10) | 9/9 |
| notices | 3/3 | `NoticeTest` (8) | 8/8 |
| releasenotes | 3/3 | `ReleaseNoteTest` (6) | 6/6 |
| suggestions | 5/5 | `SuggestionFlowTest` (9), `SuggestionIssueClientTest` (6) | 12/12 |
| blog | 12/12 | `BlogFlowTest` (9), `BlogNewsletterTest` (7) | 14/14 |

Total: 49 of 49 endpoints, 102 of 103 Java tests ported.

### Pending seams (concrete classes, safe default, `// pending-port: <owner>`)

| Seam | Owner | Default |
|---|---|---|
| `ProjectsProfiles` (`idByUsername`) | profile | reads `users` read-only (same SQL; `ProjectsModule.withProfiles` takes a profile subclass) |
| `SuggestionsGithubToken` | support | `GITHUB_ISSUES_TOKEN` from the environment |
| `BlogFeedPointers` (`publish`, `delete`) | feed | mints the post id and logs `blog_feed_pointer_pending`; the feed owner writes the BLOG pointer post (tag `blog`, visible only in "Para voce" of subscribers) |
| `BlogNotifier` (`notifyNewPost`) | notifications | logs `blog_notification_pending`; the owner writes the `NEW_BLOG_POST` notification |
| `BlogCoins` (`recordPresence`) | coin | no-op |
| `BlogEmailSender` (`sendHtml`) | sends through the shared `MailService` (named sender, Reply-To, List-Unsubscribe) | none |
| `BlogModule.withSeams` | feed, notifications, coin, identity | wiring point for the four blog seams above; `BlogService.authorsFollowedBy` is what the feed adds to "Para voce" |
| ops hooks | kernel | `OpsMonitoring` replaces `hooks.monitoring`; `OpsLogTap` replaces the Java logback appender and `GlobalExceptionHandler` calls (`Log.installTap`) |
| apiv1 hooks | kernel | `DeveloperOriginService` calls `hooks.origins.invalidate()` after every table change |

### Decisions and deliberate differences

- **No OpenAPI document.** The Java `V1ApiController` note says "a API nao publica documento OpenAPI (nao existe /openapi.json)". The note text is kept verbatim and `GET /openapi.json` answers 200 with an empty body (the unknown-path rule); asserted in `ApiV1Test`.
- **`GET /v1` index** is built from `server.routes`: `/v1`-prefixed aliases are skipped, `:id` is shown as `{id}`, sorted by path then method.
- **ops, capture**: Kof has no logback; `Log` has a tap (`Log.installTap`) that feeds WARN/ERROR lines of every logger and the `audit` logger. `kernel.http` `unhandled_exception` and 5xx `api_error` lines become EXCEPTION events with the request (method, path, requestId, user) from `LogContext`. Loggers `ops.*`, `kernel.monitoring*` and `kernel.http.access` are not captured. The "stack trace" of an exception event is the redacted thrown text (Kof exceptions are strings).
- **ops, file reader**: the Java `FileEventSink.readFileBackward` processed the block head as a whole line and carried the wrong end, losing one event per 64 KiB block boundary. `DayLog` carries the cut head into the next (earlier) block instead (tested across block boundaries with multibyte text). Everything else (UTC day files, 7-day retention, 16384 line cap, 500 recent, queue 5000, 1000 events/min cap, flush 500 ms draining 200) is unchanged.
- **ops, jobs** on `kernel.jobs`: `monitoring-flush` (500 ms), `monitoring-sample-resources` (60 s, 5 s initial delay), `monitoring-prune-minutes` (300 s), `monitoring-purge-old` (3600 s, 60 s initial delay). Env: `REDE_MONITORING_FILE_DIR`, `REDE_MONITORING_RETENTION_DAYS`, `REDE_MONITORING_MAX_EVENTS_PER_MINUTE`.
- **ops, `/admin/emails`** keeps the Java rules: moderator or admin, TWO_FACTOR rows hidden, recipient masked (`***`), subject and error scrubbed of addresses. The writer (`EmailLogStore.append`) is what the identity port's e-mail sender calls.
- **blog, newsletter** runs on the shared outbox (event `BLOG_POST_PUBLISHED`, worker every 5 s) instead of a Java executor, so nothing is sent if the publish transaction reverts. Rules unchanged (first publish only, verified e-mails only, never the author, Reply-To the author, `List-Unsubscribe`). Needs `REDE_SECURITY_ENCRYPTION_KEY` (otherwise logged and skipped, as in Java). The unsubscribe token is the standard-base64 `cipher.encrypt(blogId:userId)` made URL-safe without padding and converted back before decrypting, so tokens issued by the Java service keep working. The template `resources/templates/email-blog-post.html` is rendered by the kernel `HtmlTemplate` (Thymeleaf subset: `th:text`, `th:href`).
- **themes**: the JSON literal `null` as a package is a 400 (Java answered 500).
- **blog tests**: the Java feed and notification assertions of `BlogFlowTests` are asserted against fakes of the `BlogFeedPointers`/`BlogNotifier` seams (a pointer per post, one `NEW_BLOG_POST` per subscriber with href `/blog/<username>/<postId>`); the real `/feed` and `/notifications` checks move to the feed/notifications ports. The Mockito spy assertions of `BlogDirectoryTests` ("no per-blog query") cannot be written over HTTP; the directory instead uses bulk queries (`bannedAmong`, one grouped post count, one author batch) and the behaviour (counts, banned author left out) is asserted.
- **suggestions**: the moderator approve/reject path is covered in `tests/security` (`SecurityModerators` defaults to nobody here).

### Kernel files added or changed by this slice

`kernel/http/Req.kf` (`queryAll`, `queryParam`, `formDecode`, raw-query decoding), `kernel/http/OutboundHttp.kf` (later merged into `Outbound.kf`), `kernel/text/{Regexes,Texts,Contrast,HtmlTemplate,Numbers}.kf`, `kernel/url/OriginNormalizer.kf`, `kernel/time/ZoneDates.kf`, `kernel/log/Log.kf` (`LogTap`), `kernel/db/Db.kf` (`poolStats`), `kernel/monitoring/{DayLog,HostResources,RequestMetrics,EventBuffer}.kf`. Gaps found: G220 to G230 in `KOF_GAPS.md`.

## jobs, importresume, importlinkedin

Slug `jobs`, branch `port/jobs`. Modules installed in `Main.kf`: `ProfileModule` now comes BEFORE identity (the identity job eligibility rule reads the live reputation of the profile domain through `IdentitySeams.reputations = JobsIdentityReputation(...)`); then, after messaging/calls, `JobsModule.installWith(...)`, `LinkedinImportModule.install(platform, shared, profiles)` and `ImportResumeModule.install(jobs, linkedinImport)`. Jobs on `kernel.jobs`: `external-jobs-boot-seed`, `external-jobs-refresh` (cron), `linkedin-contact-invites` (the `LinkedinContactInviteWorker`).

| Domain | Endpoints ported/total | Kof tests | Java tests ported/total |
|---|---|---|---|
| jobs (`src/jobs`) | 20/20 | `tests/jobs/*` (108, 17 files; includes the eligibility policy, `OpenJobApiSource` over a stub transport, `UrlCanonical`, `HtmlEntities`, `Db.requiresNew`) | 94/94 methods (one loses two assertions, see below) |
| importlinkedin (`src/importlinkedin`) | 6/6 (the two uploads `POST /me/import/linkedin` and `/contatos` go through the binary lane) | `tests/importlinkedin/*` (+ `LinkedinUploadRoutesTest`) | 20/20 (`LinkedinImportUploadLimitTests` ported over the lane) |
| importresume (`src/importresume`) | 2/2 (`POST /me/import/resume` and `POST /me/import/resume/prefill/{jobId}`, multipart through the binary lane) | `tests/importresume/ResumeImportServiceTest`, `ResumeUploadRoutesTest` | 9/9 |

### The four uploads on the binary lane

The four endpoints are `POST multipart/form-data` and share path prefixes with ordinary routes, so they are claimed by
METHOD and exact path (`BinaryLane.claimRoute`, `docs/KERNEL.md`, "Method + path claims"); `PUT .../contatos/auto-convite`,
`GET .../contatos`, `POST .../texto` stay ordinary routes and are exercised by `LinkedinUploadRoutesTest`. Each handler
authenticates before the body is read (`Auth.requireUser`, then `BinaryUploads.receive`), the front streams the body
through `MultipartParser` into temp files and the lane deletes them after the answer.

- `POST /me/import/linkedin` -> `LinkedinImportService.parseArchive(file)`; `POST /me/import/linkedin/contatos` ->
  `parseContacts(file)` then `LinkedinContactInviteService.importContacts`; `POST /me/import/resume` ->
  `ResumeImportService.parse(file, name, type)`; `POST /me/import/resume/prefill/{jobId}` ->
  `ResumePrefillService.prefill(user, jobId, extractText(file, name, type))`.
- Limits: `REDE_IMPORT_UPLOAD_MAX_BYTES` (default 16 MB) caps the request and its file part (`413 FILE_TOO_LARGE` from the
  front). Spring allowed 520 MB and the services then refused above 5 MB (LinkedIn) / 10 MB (resume) with a `400
  FILE_TOO_LARGE`: here a file between 16 MB and 520 MB answers 413 instead of 400, with the same code, and 520 MB never
  reaches the disk of an authenticated user. The 5 MB / 10 MB service rules are unchanged (`400 FILE_TOO_LARGE`).
- Differences from Spring: a missing `file` part is `400 FILE_REQUIRED` (Spring answered 500 through the generic handler),
  a body that is not multipart is `415 UNSUPPORTED_MEDIA_TYPE`, a chunked body is `411 LENGTH_REQUIRED`, a broken multipart
  body is `400 MALFORMED_MULTIPART`. One upload goes through the filter chain twice (authorize and commit).
- The Java `LinkedinImportUploadLimitTests` run in `LinkedinUploadRoutesTest` over a real socket with the 8 MB cap of the Java
  test profile (`ImportTestKit` sets `REDE_IMPORT_UPLOAD_MAX_BYTES=8388608`): the 3 MB zip reaches the route (401 without
  a session), the 8.45 MB one gets `413 FILE_TOO_LARGE`, with and without a session. In Spring the limit was checked before
  authentication; here too (the declared length), while the file itself is only read after the session is accepted.
- Lane gaps found: G300 to G303 (`docs/KOF_GAPS.md`).

### Seams replaced by real module APIs

| Seam (Java dependency) | Now |
|---|---|
| `ReputationService` (job gate, eligibility) | `ProfileJobReputation` over `ProfileReputation` of the profile module; identity's `IdentityReputation` is `JobsIdentityReputation` (Main.kf) |
| profile reads (author, candidate portrait, experience years) | `ProfileDirectory`, `ProfileExtensionStore` |
| direct message to the poster, application status notice | messaging service, `Notifications` of the notifications module |
| connection requests of the LinkedIn contact invites | `NetworkService.requestConnection/state` |
| contact lookup | `ProfileDirectory.search/findByEmail/findAllByIds` |
| outbound calls to job sources | `kernel.http.Outbound` through `JobSourceTransport` |

### Pending seams (concrete classes, safe default, `// pending-port: <owner>`)

| Seam | Owner | Default |
|---|---|---|
| `JobCompanies` (`company`, `roleOf`, `requireRecruiter`, `slugsOf`, `followerIds`) | companies | reads `companies`, `company_memberships`, `company_follows` read-only with the owner's SQL |
| `JobCorporate` (`requireActive`) | corporate | reads `corporate_profiles` read-only |

### Test notes

- `JobCompanyPageTest.onlyThePageTeamPostsForItAndTheJobPointsBackToThePage` seeds the company rows directly (the companies endpoints are not ported) and drops two assertions that read companies endpoints: `GET /empresa/{slug}` (jobs of the page, `stats.openJobs`) and `GET /empresas/diretorio` (`openJobs`). They move to the companies port.
- `JobCorporateApplicationTest` replaces `/me/business-profile` calls with the `corporate_profiles` row the corporate domain leaves.
- The Java Mockito tests (`JobServiceTests`, `ExternalJobSubmissionServiceTests`, `ExternalJobRefreshSchedulerTest`) run the real services over H2; "never saved / never delivered" is read from the tables and the captured mailer.
- The Java `ExternalJobImportServiceTests`, `GlobalDedupeTests` and `CommunitySubmissionImportGuardTests` registered stub `JobImportSource` beans; here `JobTestSource` instances are set before the app of the file boots.
- Gaps found: G280 to G284 (`docs/KOF_GAPS.md`).
## games and dailygames

Ported: the store catalogue (submit, review, publish, edit, slug change, suspend, favorites, trending, stats,
analytics, boost), developer pages and follows, reviews, ratings and comments, collections, the identity token
that games use to talk to the platform (`POST /games/:gameId/identity`, validated once by `POST /games/tokens/validate`), the spend confirmation, the share to
the feed, the URL guard, and the three daily games (words, maze, blocks) with the prize settlement. Every code
and pt-BR message is the Java one. The daily maze and blocks are generated from `java.util.Random` through
`kernel.text.JavaRandom`, so the same stored seed gives the same maze, the same bag of pieces and the same replay:
`tests/dailygames/DailyMazeTest.kf` and `DailyBlocksEngineTest.kf` compare against values produced by running the
Java `MazeRules` and `BlocksEngine`.

The cron `DailyGameRewardsScheduler` runs on `kernel.jobs` (`daily-game-rewards`, 00:20 America/Sao_Paulo, look-back
7 days).

### Seams owned by this slice (pending-port)

| Seam | Owner to come | Default |
|---|---|---|
| `GamesCoins` | coin | runs the ledger SQL the Java `CoinService` runs for `grant` (hash-chained entry, optimistic balance update, treasury `coin_tesouraria`, rate from `coin_rate_history`, encrypted message, idempotent by `kind:ref`); `recordPresence` is a no-op (the streak belongs to coin) |
| `GamesFeed` (`publishShare`) | feed | age gate and sanction gate through the real modules, then inserts the INSIGHT post with its tags and media; it omits the feed side effects (mentions, fan-out, counters) |
| `GamesHosts` (`classify`) | none | real DNS classification; tests override it with a DNS-free stub (names are public, literal IPs are classified for real) |

Profile, notifications, age and sanctions are called through their real module APIs (`ProfileDirectory`,
`Notifications`, `AgeGate`, `SanctionGate`), not through seams.

### Decisions and deliberate differences

- **followers of a developer**: `followersOf` returns the follower ids (`follower_id`); the Java query selected the followed id, so the new-update notification reached the developer instead of the followers.
- **play counter** is incremented atomically in SQL (`plays = plays + 1`), not read-modify-write.
- **identity token** is claimed with one atomic `UPDATE ... WHERE used_at IS NULL`, so two parallel validations cannot both succeed.
- **blocks window**: the 409 `GAME_FINISHED` past 600 s is thrown inside the transaction like Java, so the TIMED_OUT mark it tried to write is rolled back; the state still reports TIMED_OUT by replay.
- **coin default** skips a credit whose idempotency key already exists instead of failing.
- **tests**: wallets are seeded with a `coin_accounts` row (the Java airdrop belongs to coin); settlement rows are read from `coin_entries`.
- **`BlocksEngineTest`**: Java also passes a `null` event list; Kof lists are never null, the other five assertions are kept. Golden tests (bag sequences, scripted replays WON and LOST) were added.
- **router order**: literal routes are registered before the `:slug` ones, because the Kof router takes the first registered match (Spring prefers the literal one by itself).

### Kernel files added by this slice

`kernel/text/JavaRandom.kf`, `kernel/time/IsoWeeks.kf`, `kernel/url/HostAddresses.kf`, `kernel/url/UrlParts.kf`
(documented in `docs/KERNEL.md`), proven by `tests/kernel/GamesAdaptersTest.kf`. `src/Main.kf` wires `GamesModule` and
`DailyGamesModule` and keeps the `ProfileModule` result.

## economy (coin, cosmetics, marketplace, services)

Slug `economy`, branch `port/economy`, gap numbers G240 to G248. Modules: `CoinCore.create(platform, shared, parts)` before notifications, then `CoinModule.install(...)` after it (the disputes notify); `CosmeticsCore.create(platform)` before profile (its badge ownership replaces a profile seam), then `CosmeticsModule.install(...)`; `MarketplaceModule.install(...)` and `ServicesModule.install(...)` last. All wired in `Main.kf` (the boot was smoke tested with `scripts/kof-run`: it reaches "listening").

| Domain | Endpoints ported/total | Kof tests (`tests/<domain>`) | Java tests ported/total |
|---|---|---|---|
| coin (`src/coin`) | 16/16 | 63 tests in 10 files: `CoinFlowTest`, `CoinExtractTest`, `CoinTransferGuardTest`, `CoinDisputeFlowTest`, `CoinEconomyServiceTest`, `CoinEconomyCalculatorTest`, `CoinEconomyEndpointTest`, `CoinStreakTest`, `CoinStreakPresenceTest`, `CoinBridgesTest` | 62/62 behaviours (the parameterised and the date-window Java tests are merged: 62 Java methods become 59 Kof tests, plus 4 new: bridges and the failing-presence case) |
| cosmetics (`src/cosmetics`) | 22/22 | 67 tests in 8 files | 59/59 methods (8 new tests for paths the Java tests never reached) |
| marketplace (`src/marketplace`) | 11/11 | 16 tests in 4 files | 15/15 (+1 new: sanitize) |
| services (`src/services`) | 21/21 (14 in `/servicos`, 7 in `/services`) | 12 tests in 2 files | 12/12 |

Total: 70 of 70 endpoints, 148 of 151 Java behaviours ported as 158 Kof tests; the 3 left are `CoinTestSupportTests` (below).

### coin

- The ledger is the truth: kinds are strings, `grant` checks the balance (400 `INSUFFICIENT_SPARKS`), chains the hash `sha256(prev|account|amount|kind|ref|idem)`, and the balance moves with the same atomic statement as Java (`update coin_accounts set balance = ?, version = version + 1 where account_id = ? and version = ?`, else 409 `COIN_CONCURRENCY`). The idempotency key is `kind:ref`, unique per account.
- Jobs on `kernel.jobs`: ledger reconcile `0 17 4 * * *` (UTC, like the JVM zone of Java), economy recalculation `0 10 */3 * * *` and monthly round `0 40 3 1 * *`, both in `COIN_ECONOMY_ZONE` (America/Sao_Paulo). All three are overridable with the Java env names (`COIN_ECONOMY_*`, `-` disables a cron).
- Economy defaults come from `application.properties` (scarcity weight 0.5), not from `docs/COIN_ECONOMY.md` (1.5): same as the Java runtime. One publication per period (24 h by default), the monthly round recalculates from zero.
- Transfers: dedupe window `REDE_COIN_TRANSFER_DEDUPE_SECONDS` (10), throttles `REDE_COIN_TRANSFER_PER_MINUTE` (10) and `REDE_COIN_TRANSFER_PER_HOUR` (60), new-account cap 500 sparks per UTC day (403 `NEW_ACCOUNT_LIMIT`).
- Presence (`CoinService.recordPresence`) runs after the commit of the caller's transaction, in its own, and never throws into the action.
- Fixed while testing: the elapsed fraction of the economy period divided by the period in milliseconds and then by 1000 again (the ported test `after a whole period the step is full again` caught it).

#### Seams replaced in other domains (Main.kf)

| Seam | Replaced by |
|---|---|
| `CommunityCoins`, `GroupCoins`, `BlogCoins`, `MessagingCoins` (`recordPresence`) | `CoinCommunityCoins`, `CoinGroupCoins`, `CoinBlogCoins`, `CoinMessagingCoins` (`src/coin/CoinBridges.kf`), tested in `CoinBridgesTest` |
| `NotificationCoins` (`hasReward`, `reward`: the apology) | `CoinNotificationCoins` |
| `ProfileBadgeOwnership` | `CosmeticsBadgeOwnership` (an `emblema-*` badge needs ownership and a catalog BADGE id; the old default accepted any owned `emblema-` id) |

#### Seams owned

| Seam | Owner | Default |
|---|---|---|
| `CoinDisputeModeration` (`report`, `applyForReport`, `restrictUser`) | moderation | writes `reports` (throttle `report`, 409 `ALREADY_REPORTED`) and `user_sanctions` directly with the Java rule (a USER report of a scam restricts the receiver) |
| `CosmeticsContributors.isVerified` | contributions | reads `user_seals` (ACTIVE) and `github_identities` |
| `ServiceLinkGuard` | games (`GameUrlGuard`) | the same rule (https only, no credentials, public host, codes `INVALID_GAME_URL`) |

### Deliberate differences from the Java services

- Coin: a duplicate idempotency key propagates 409 and rolls the transaction back (Java found the existing entry); the dispute decision is an atomic claim (`where state = 'OPEN'`, else 409 `DISPUTE_ALREADY_DECIDED`; Java never checked the state, so a decided dispute could be decided again); request bodies that Java answered with 500 (null pointer) answer 400 `BAD_REQUEST`.
- Escrow refund reuses the release reference (`ESCROW_RELEASE` kind), so release and refund exclude each other in the ledger itself.
- Cosmetics: submit of a community cosmetic is an atomic claim (`where status = 'DRAFT'`), an edit only applies while DRAFT or REJECTED, the report counter is `reported = reported + 1` in SQL, a concurrent second look purchase is 409 by the ledger key (the wallet is charged once either way). `PUT /me/status` answers the profile view through `ProfileViews.publicView`. Profile slots are written group by group through `ProfileSlots` (a look change never rewrites a neighbour field; an equipped seasonal name style clears font and color).
- Marketplace: confirm and refund are atomic claims (`update ... where state = 'HELD'`, 409 `PURCHASE_NOT_HELD`) on top of the `for update` row locks. The Spring rollback test with a spy became a CHECK constraint that makes the REFUNDED write fail once (same observable: money and state roll back, the retry works). Jobs: `marketplace-release-expired` (hourly), `marketplace-sanitize` and `marketplace-gallery-import` (initial 90 s, hourly).
- Services: accepting, refunding and choosing a proposal are atomic claims on the state, and accept/refund check HELD before moving money; publishing an offer locks the seller's `users` row so the 5 open offers cap holds under concurrency; delivery note and proposal message get 1000 characters with `SERVICE_FIELD_TOO_LONG`. An unresolvable host and a private host share one message in the link guard, and the tolerant re-encoding of links with special characters is not ported. The chat opens a real SERVICE conversation through `MessagingService` and needs the sender to have a birth date (the messaging age rule).

### Java tests not ported (3 of 151)

- `CoinTestSupportTests` (3): test of `retryOnCoinConcurrency`, a helper that exists only because all Java test classes share one H2 and one treasury row. Each Kof test file boots its own database.
- Moderation endpoints used by the services tests (`/moderation/services/*`) belong to the moderation domain: the tests drive `ServiceOfferService.approve/reject/suspend`, the methods that domain will call. Moderation of community cosmetics (PENDING_MODERATION to PUBLISHED) is moved by SQL in the tests.
- The feed projections checked by two cosmetics tests (frame and name style on a post/comment) and the `/feed/posts` calls of the streak tests: the feed is not ported, so the streak tests call `CoinService.recordPresenceNow`, the exact call the feed makes.

### Kernel files added or changed by this slice

`kernel/jobs/ProcessLock.kf` (new: the `synchronized` of Java), `kernel/time/ZoneDates.kf` (`localToInstant`, `dayOfWeek`, `weekStart`), both with tests in `tests/kernel`. Config: `COSMETICS_CATALOG` (default `resources/cosmetics/catalog.json`; the deploy must ship the file next to `resources/templates`), `REDE_COSMETICS_EVENTS_{DUEL,HUNT}_{STARTS,ENDS}_AT`, `REDE_MARKETPLACE_*`, `COIN_ECONOMY_*`. Test support in `src/economy/` (`EconomyTestKit`, `CosmeticsTestKit`, `MarketTestKit`, `ServicesTestKit`). Gaps found: G240 to G248 in `KOF_GAPS.md`.

## Mail and event streams (feat/mail-sse)

- **Mail**: `kernel/mail/SmtpTransport` is the only file that touches jakarta.mail / angus-mail (2.0.5, the family of spring-boot-starter-mail). `MAIL_HOST` (localhost), `MAIL_PORT` (587), `MAIL_USERNAME` (suporte@enois.ia.br, also the From), `MAIL_PASSWORD`; STARTTLS enabled and required, auth on, 5 s timeouts, as in Java (`MAIL_SMTP_STARTTLS_ENABLE`, `MAIL_SMTP_STARTTLS_REQUIRED`, `MAIL_SMTP_TIMEOUT_MS` override them for local servers). `ops.MailService` is the one service every sender uses (`sendHtml`, `sendBulk` with sender name, Reply-To and `List-Unsubscribe` + `List-Unsubscribe-Post: List-Unsubscribe=One-Click`): it records one `email_log` row (SENT, or FAILED with the cause cut at 500; the 2FA subject redacted) and never throws. Messages are multipart/alternative: a plain-text part derived from the HTML (Java sent HTML only) and the HTML part. Senders switched: identity (verification, reset, 2FA, parental consent, e-mail change, signup notice, generic HTML), age, jobs (application delivery and status e-mails), the blog newsletter, the weekly digest. Not ported because the domains are not: the support e-mails (named sender "Suporte Enois", attachment) and moderation notices.
- **Tests**: `MailServiceTest` and `MailSendersTest` (17) run the real transport against `kernel.testkit.FakeSmtpServer` (loopback, AUTH PLAIN, DATA capture); domain suites use `MailTestKit.capturing(platform)` (`MailCapture`). `EmailTemplateParityTest` compares the five templates with goldens made by Thymeleaf 3.1.5. `EmailServiceListUnsubscribeTests` is ported in `MailServiceTest`.
- **Event stream**: `GET /conversations/stream` (and `/v1`) runs on `app.sse` (see G312 to G314). Events `conversation` `{"conversationId"}` (send, read receipt, reaction) and `call` `{"callId","state","conversationId"?,"groupId"?}`, published after commit; 5 streams per user (the oldest is closed), 30 minutes per stream, heartbeat every `REDE_MESSAGING_STREAM_HEARTBEAT_MS` (25000) as a named `ping` event. Session via `X-Session-Token`, bearer or cookie; a refusal is the bare status. In-memory registry: one backend instance, like Java. `MessageStreamTest` (8 of the 4 Java tests plus heartbeat, alias, cookie, reaction) and `CallStreamTest`.

## contributions, contributors, githubprofile, support

| Domain | Endpoints ported/total | Java tests ported/total |
|---|---|---|
| contributions | 17/17 | 18/20 (see below) |
| contributors | 6/6 | 7/7 |
| githubprofile | 4/4 | 6/6 |
| support | 9/9 + the webhook | 12/12 (the 6 route-authorization tests as one HTTP suite) |

**contributions**: public seals and evidence, criteria, the account link state and "verify contributions" (per-user
limit `UserRateLimiter.syncGithub()`), the admin queue of evidence (review with the status transition rules, seal
grant and revoke, recalculation, the repositories switch, the manual sync with `dryRun`/`full`/`repositories`), the
open pull requests queue and its review (the service token when the person has no write token of their own), the sync
(on link, on demand, and on `kernel.jobs` when `GITHUB_SYNC_ENABLED=true`, cron `GITHUB_SYNC_CRON`, default
`0 */10 * * * *` like `application.properties`; the annotation default of Java is 6 h but the property wins). The sync
keeps the Java rules: a merged PR is born VALIDATED, an issue only counts with a qualifying label or after a human
review, a human review is never overwritten, a "Revert ..." PR flags evidence N, the detail budget bounds the calls,
the repositories of the organization are discovered (enabled on birth, an existing row is never touched).

**contributors**: the public landing form (per-IP limit, public write), the confirmation of verified contributors
(idempotent, the handle comes from the link), the account state, the admin queue and the panel (verified people
appear on their own). `VerifiedContributors` (the Java `VerifiedContributorReaderAdapter`) lives in contributions.

**githubprofile**: the repositories of the link, the README preview and import (rendered by
`kernel.html.MarkdownBio`, sanitised by `SafeHtml`), the project import (same limits as the manual form), the cache
(`githubRepositories`, `githubReadme` through `kernel.cache`; a failure and a missing README are never cached).

**support**: tickets, throttle, triage, official reply (e-mail, in-app notice, thread, GitHub comment), the thread, the
GitHub mirror (issue on open, close/reopen on status, comment on reply, signed webhook back), the encrypted settings.

### Seams filled in `AppWiring`

| Seam | Filled by | Test |
|---|---|---|
| `identity.IdentityOAuthLinks` (GitHub side) | `ContributionsOAuthLinks` (identity, write token only with `repo`/`public_repo` and the cipher on, sync after the commit) | `tests/contributions/ContributionsSeamsTest.kf` |
| `cosmetics.CosmeticsContributors.isVerified` | `ContributionsCosmeticsContributors` (`VerifiedContributors.find`) | same file |
| `suggestions.SuggestionsGithubToken` | `SuggestionsSupportToken` (reads the support settings on every use) | `tests/support/SupportSeamsTest.kf` |
| support: who answers on GitHub | `SupportLinkedPeople` (login and write token from contributions) | same file |

Seams owned by this slice: `GithubGateway` (the GitHub reader of contributions), `GithubProfileGateway`,
`SupportGithubGateway`, `SupportGithubPeople` (all base classes with inert defaults and a real client, G30).

### Decisions and deliberate differences

- **webhook**: 503 without a secret, 401 for a missing/wrong signature (constant-time compare of `sha256=<hex>`), 200 for
  everything else including a signed malformed body; the 2 MiB ceiling is a filter at order -975 (`WEBHOOK_TOO_LARGE`, no
  timestamp, like the Java filter). Bodies are UTF-8 text (G161): GitHub sends UTF-8 JSON.
- **support mail**: through the shared `ops.MailService.sendBulk`: the sender name is "Suporte Énóis" and the team mail has the
  contact of the requester as Reply-To, like `EmailService`. The Java `fetchImage` (the attachment of the team mail) was dead
  code and is not ported.
- **GitHub rate limit message**: `Outbound` hides response headers, so `remaining=?` is always `?`.
- **org repository filter**: `private` is a Kof keyword (G325), so the redundant `private` check of the listing is dropped;
  the request already asks `type=public`. The user repository listing has the same reason.
- **sync on link** runs on its own task with a `Gate` (Java: a single-thread executor); the suites run it inline.
- **optional booleans** (`dryRun`, `full`, `enabled`, `acceptedTerms`) are `Troolean` (G140).
- **`/admin/support/github;v=1`** is not an unknown path in Kof: it matches `PATCH/POST /admin/support/:id` as an id, so a
  GET answers 405 and never reaches the settings handler (the other spellings of the Java matrix are unknown paths, 200 empty).
- **sealed enums** travel as Strings; an unknown value in a body or query is a plain 400 like the Jackson/Spring conversion.
- **not ported as separate tests**: `GitHubOAuthLinkTests.githubLoginIsRejected...` is `tests/identity/OAuthTest.kf`
  (`githubOnlyLinksAndNeverSignsIn`); `linkWithoutOAuthConfigFailsClosed` is covered by the identity OAuth suite on main
  (the `OAUTH_NOT_CONFIGURED` 501 of `IdentityOAuth`); the contributor tag colour test of `VerifiedContributorPanelTests`
  is `tests/cosmetics/CommunityCosmeticsFlowTest.kf` plus the cosmetics seam test above.

### Kernel changes of this slice

`Hashes.hmacSha256Hex`, `Outbound.patch` (Apache `HttpPatch`: `HttpURLConnection` cannot PATCH), `ZoneDates.formatLocal`
(documented in `docs/KERNEL.md`, tests in `tests/kernel`), `ProfileStore.updateBioHtml`.

### Gaps

G320 to G324 (Apache client interop) and G325: `private` is a Kof keyword and cannot be a record member; also seen again:
G204/G304 (a field named `http` is read as the package, `VerifyError`/`COMPUTE_FRAMES` crash), G12.
## orgs: corporate, companies, mentoring, freelances, events

Slug `orgs`, branch `port/orgs`, gap range G340 to G359. Test fixtures: `app.OrgsTestKit` (src/app) boots the exact production wiring (`AppWiring.install`) once per test file, so every orgs test also proves the wiring and the seams.

| Domain | Endpoints ported/total | Kof tests | Java tests ported/total |
|---|---|---|---|
| companies (`src/companies`, includes the microprojects) | 19/19 (`/empresas`, `/empresas/diretorio`, `/setores`, `/mine`, `PATCH /empresas/{id}`, `follow` POST/DELETE, `members` GET/POST, `POST .../microprojetos`, `GET /empresa/{slug}`, `GET /microprojetos`, `GET|PUT|DELETE /microprojetos/{id}`, `proposals`, `.../select`, `.../complete`) | `tests/companies/*` (16) | 12/12 methods + the 2 assertions `JobCompanyPageTests` left for this port + the company cases of `TextFieldLimitTests` and `LinkSchemeAllowlistTests` |
| corporate (`src/corporate`) | 10/10 (`GET|POST|PATCH /me/business-profile`, `POST .../name`, `.../username`, `GET .../import-preview`, `POST .../import`, `.../activate`, `.../deactivate`, `GET /corporate/{username}`) | `tests/corporate/*` (33, 3 of them cover the bridges) | 31/31 methods |

### corporate notes

- `CorporateProfile.create/withName/withUsername` threw `IllegalArgumentException` (400 `BAD_REQUEST`, or `INVALID_USERNAME` for the nametag change): `CorporateRules` throws a marker the service maps the same way.
- The unique `@` is the database index; a constraint violation is `USERNAME_TAKEN` only when another account holds that `@`, any other refused value stays the generic `409 CONFLICT` (the Java persistence test asserted "not an ApiException"; here it is "not USERNAME_TAKEN").

### Seams replaced by the corporate port

| Seam | Now |
|---|---|
| `FeedCorporate` (feed) | `CorporateFeedBridge` through `FeedModule.installWithCorporate` |
| `MessagingCorporate` (messaging) | `CorporateMessagingBridge` in `MessagingSeamSet.corporate` |
| `JobCorporate` (jobs) | `CorporateJobsBridge` in `JobSeamSet.corporate` |

`NotificationActors` and `FeedAuthors.corporateByIds` still read `corporate_profiles` read-only with the same columns (same answers; not swapped).

### companies notes

- The Java `companies` package also holds the microprojects marketplace; both are ported (`CompanyService`, `MicroProjectService`, `CompanyDirectoryService`). The directory reads open jobs and external job names from `jobs.JobCompanyDirectory`.
- The `COMPANY_NEW_OPPORTUNITY` follower notice, the microproject notices (`MICROPROJETO`) and the moderation notice go through `Notifications.create`; the proposal opens a `FREELANCE` conversation through `MessagingService.freelanceConversationBetween` and posts the message; the completion bonus (+200 sparks, 3 a month, per project) goes through `CoinService.reward` and never fails the acceptance.
- Moderation is not ported: `CompanyService.closeByModeration`, `contentOf` and `ownerOf` are the three methods the Java `CompanyModerationAdapter` (`CompanyReportReader`, `CompanyRemovalPort`) calls; the moderation port subclasses its own seams over them. `CompanyReportTests` belong to moderation.
- `MicroProjectEditTests`/`CompanyFlowTests`/`CompanyPagesTests` run over the production wiring; `JobCompanyPageTests` post their rows with the seeded table (a real `POST /jobs` needs the live reputation of the profile domain, which the production wiring computes), so `CompanyJobsTest` seeds the open job linked to the page.
- The V180 neutralisation of `companies.website` and the V219 backfill are replayed over planted rows (`CompanyLinkSchemeTest`, `CompanyPagesTest`).
- A `listAll` public list applies its limit before dropping closed pages (as Java); the `PATCH` keeps blank texts as sent and `null` keeps the stored value (`Company.update`).

### Seams replaced by the companies port

| Seam | Now |
|---|---|
| `JobCompanies` (jobs) | `CompanyJobsBridge` in `JobSeamSet.companies` over `CompanyService` (page, role, recruiter gate, slugs, followers) |

### freelances

Branch `port/orgs-freelances`, package `freelances` (`src/freelances`), module `FreelancesModule.install(platform, shared, profiles, age.gate, corporate, messagingModule)` in `AppWiring`.

| Item | Result |
|---|---|
| Endpoints ported/total | 7/7: `GET /freelances` (public, offset cursor, `q`), `GET /me/freelances`, `POST /freelances`, `PATCH /freelances/{id}`, `DELETE /freelances/{id}`, `POST /freelances/{id}/close`, `POST /freelances/{id}/proposals` |
| Java tests ported/total | 7/7: `FreelanceFlowTests` (4), `FreelanceEditDeleteTests` (2), the freelance case of `TextFieldLimitTests` (1). `SuspiciousContentTargetsTests` and `ServicesFlowTests` only mention the table name or the word and belong to moderation and services |
| Kof tests | `tests/freelances/*`: 7 ported plus 11 added in `FreelanceRulesTest` (session guard, view and owned flag, every validation code, lifecycle errors, cursor, search escaping, creation throttle, age gate, link check, proposal guards with the block list) |

Seams: none owned. Every collaborator is the real module API from `AppWiring`: `ProfileDirectory` (usernames), `AgeGate.requireCanWrite`, `CorporateService.requireActive`, `MessagingService.freelanceConversationBetween/sendMessage`, `SharedServices.blockedUsers`; the creation throttle (10 per hour per account) is an own `ActionThrottle`, like the other modules. Test fixtures: `app.FreelanceTestKit` (src/app).

Deliberate differences from the Java service:

- The list cursor is a plain SQL `limit/offset`. The Java adapter paged by `offset / size` and skipped `offset % size` rows of that page, so an offset that is not a multiple of the page size returned a short page and no `nextCursor` (cursors issued by the service are always aligned, so the contract the app sees is the same).
- Edit and close are atomic claims on the status (`update ... where status = 'OPEN'`): two racing requests cannot both win, the loser gets the same 409 the sequential case gets.
- `POST .../proposals`: the conversation and the message run in one transaction, as in Java; a missing body is `400 BAD_REQUEST` and a JSON `null` body is `400 EMPTY_PROPOSAL`.
- The body is checked by `SafeLinks.checkRequest()` (the Java `SafeLinkRequestBodyAdvice`), so a scope or a proposal with an unsafe Markdown link is `400 UNSAFE_LINK`. The domain has no URL field of its own.
- The Java `countOpen` repository method had no caller and is not ported. `freelances` is also named in the Java attack-purge and content-sweep targets: those jobs belong to security and moderation.

No kernel change, no new compiler gap.

### events

Package `events` (`src/events`): `EventsModel` (records and the pure date rules `EventRules`), `EventsStore`, `EventsService`, `EventsRecurrenceService` (+ `EventSanitizationWorker`), `EventsRoutes`, `EventsModule`, `EventsBridges`. Fixtures: `app.EventsTestKit` (on top of `OrgsTestKit`).

| | Ported/total |
|---|---|
| Endpoints | 8/8: `GET /events`, `GET /events/{id}`, `POST /events`, `PATCH /events/{id}`, `DELETE /events/{id}`, `PATCH /events/{id}/recurrence`, `POST /events/{id}/attendees`, `DELETE /events/{id}/attendees` |
| Java tests of the domain (`events/**`) | 30/30 methods: viewer attendance 3, edit 4, city filter 3, sanitization 3, schedule 4, recurrence 9, sanitization window 4 |
| Java tests elsewhere that hit events | `TextFieldLimitTests` event case 1/1 (`EventFieldLimitTest`), `IntelligentCacheTests` events cases 3/7 (`EventListCacheTest`), `LinkSchemeAllowlistTests` has no event case |
| Kof tests | 43 in `tests/events` (10 files): the 34 ports above plus 9 extras (attendance codes and idempotent replay, response shape, edit extras, every field ceiling, stream link rules, banned host, the two seams) |

- `IntelligentCacheTests` not ported (4 of 7): the TTL expiry, renewal and concurrent-load cases and the closed list of caches test `TtlCache`/`Caches`, not events; `tests/shared/TtlCacheTest.kf` covers them. The events cases (list served from cache, a write clears it, a refused write leaves it alone) run through HTTP with the cache on (60 s).
- `NotificationContractControllerTests` event cases (place and day of an event notice, "events today") live in `tests/notifications`; they run unchanged on the events-backed reader, and `EventSeamsTest` also drives them from the events side.
- Admin allowlist: Java `EventScheduleTests` added `rede.admin.emails`; the Kof test uses `users.is_admin` (the production rule, the allowlist is tests-only).

Differences and decisions:

- `Event` is an immutable `EventRecord`; recurrence is a String (NONE, WEEKLY, BIWEEKLY, MONTHLY) because enums do not cross packages. The date rules (ISO and strict dd/MM/yyyy, absurd window of 5 years ahead and 2 behind, expiry in UTC, monthly anchor math) are pure functions of ISO text and epoch millis in `EventRules`, tested with explicit instants; no Java date API is needed.
- A missing NOT NULL column (title, date, time, format, host) is `409 CONFLICT` after every other check, as the Java database refused it.
- The list cache (`eventsList`, `REDE_CACHE_EVENTS_LIST_TTL`) stores the JSON of an `EventListPage` (visible events, how many the database returned and the last `created_at`), so the cursor still comes from the database page; every write clears it after commit (the sanitisation job too, which Java did not).
- Event links: `streamUrl` keeps the Java https-only rule (`INVALID_STREAM_URL`) and every JSON body goes through `SafeLinks.checkRequest` (`UNSAFE_LINK`, the Java request-body advice). `cover` is stored as sent, as in Java (V169 and V180 only rewrote old rows).
- Jobs on `kernel.jobs`: `event-recurrence` (cron `REDE_EVENTS_RECURRENCE_CRON`, default `0 20 * * * *`, zone `REDE_EVENTS_RECURRENCE_ZONE`, switch `REDE_EVENTS_RECURRENCE_ENABLED`) and `event-sanitization` (fixed delay `REDE_EVENTS_SANITIZE_DELAY_MS`, default one hour, first run at boot).
- The recurrence job asks identity (`IdentityStore.credentialByUser`) and the sanction reader whether the host is still active, and writes `EVENT_NEXT_OCCURRENCE` through `Notifications.create`.

Seams replaced:

| Seam | Now |
|---|---|
| `ProfileForeignCounts.eventsAttendedTotal` (profile reputation) | `EventsForeignCounts` (overrides only that method), passed in `AppWiring` instead of `ProfileForeignCounts(platform.db)`. A `TODO(orgs merge)` comment in `AppWiring` says to chain it with the mentoring subclass |
| `NotificationPlaceReader.eventDatesByIds` / `attendingEvents` (notifications) | `EventsNotificationPlaces` in `NotificationsSeams.placeReader` |

Seams owned: none. Remaining reads of `events` tables outside the domain: none (`communities`, `posts` and `groups` readers of the notification place reader stay with their owners).

Kernel changes: `DbParams.bindIntOrNull` and `bindLongOrNull` bound a PRESENT value through `Integer.valueOf(Integer)` (`NoSuchMethodError`, G353); they copy the value into a plain local first, with a test in `tests/kernel/DbTest.kf`.

Gaps: G353. A failing test makes the test JVM hang at exit (existing G105/G124): kill the java child to get its output.
### mentoring

`src/mentoring` (`MentoringModel`, `MentoringRooms`, `MentoringDialIn`, `MentoringStore`, `MentoringService`, `MentoringViews`, `MentoringRoutes`, `MentoringModule`, `MentoringTestKit`), installed in `AppWiring` after coin and profile; route in `BootRoutesTest` (`GET /mentors/sessions/mine`).

| Item | Result |
|---|---|
| Endpoints ported/total | 17/17: `GET /mentors`, `GET /mentors/{id}`, `GET /mentors/{id}/slots`, `POST /mentors`, `PATCH|DELETE /mentors/{id}`, `POST|DELETE .../slots`, `POST|GET .../sessions`, `GET|PUT .../availability`, `GET /mentors/sessions/mine`, `POST .../sessions/{id}/complete`, `POST .../sessions/{id}/cancel`, `GET .../room`, `GET .../sessions/{id}/dial-in` |
| Java tests ported/total | 24/24 methods: `MentorProfileTests` 2, `MentorRoomTests` 6, `MentorSessionCompletionTests` 4, `MentorSparksPaymentTests` 6, `MentorAgendaTests` 4 (all in `tests/mentoring`), plus the `/mentors` half of `CatalogSearchTests` (2 methods: the mentors search and the wildcard test, `MentorCatalogTest`; the `/blogs` half is in `tests/blog`). `TextFieldLimitTests` and `LinkSchemeAllowlistTests` have no mentoring case |
| Kof tests | 43 in 6 files (24 ports, 13 extra: delete/FK parity, idempotency replay and conflict, validation, slot ownership, Sao Paulo slot generation, inbox order, orphan escrow refund, room sanitising, Jitsi API parsing, nearest-slot and rating order, profile seam; 6 `finish`) plus `tests/kernel/DbParamsNullableTest` |
| Seams replaced | `ProfileForeignCounts.mentoringAsMentee` by `MentoringProfileCounts` (subclass, only that count; AppWiring passes it instead of `ProfileForeignCounts`). The `/mentors` search test that `tests/search` waited for |
| Seams owned | `MentoringDialInGateway` (base class, answers nothing; `JitsiDialInClient` asks `api.jitsi.net`, `REDE_MENTORING_JITSI_API_BASE`, tests point it at a closed loopback port). Coin (`CoinService` escrow), profile (`ProfileDirectory`) are called directly |
| Kernel changes | `DbParams.bindLongOrNull/bindIntOrNull` fixed for non-null values (G348), with `tests/kernel/DbParamsNullableTest` |
| Gaps | G348 |

Notes:

- Booking a slot, completing, cancelling and settling a session, and the mentor's completed counter are atomic claims (`update ... where available = true` / `status = 'SCHEDULED'` / `settled_at is null`); Java read and wrote whole rows. The completed counter is `sessions_count + 1` in SQL, counted once whoever completes the session (read, worker or mentor).
- Java parity kept on purpose: `DELETE /mentors/{id}` of a mentor that already has slots, availability or sessions is `409 CONFLICT` (foreign keys of V5/V203); the settlement job refunds the mentee when the profile is gone (only reachable with FKs off, covered by a test).
- `GET /mentors` is served with one query per page for the next free slot (Java asked per mentor). `limit < 1` is `400 BAD_REQUEST` (PageRequest); the expertise-only search sorts `rating desc, created_at desc` (Java left ties undefined).
- A missing `expertise` list, a missing or malformed `startsAt`/`endsAt` answer `400 BAD_REQUEST` (Java: a null pointer / not-null column).
- Jobs: `mentoring-complete-finished` (`REDE_MENTORING_SESSION_COMPLETION_[INITIAL_]DELAY_MS`, 120000/300000) and `mentoring-settle-expired` (600000/3600000). Config: `REDE_MENTORING_JITSI_BASE_URL` (default `https://meet.jit.si`).
