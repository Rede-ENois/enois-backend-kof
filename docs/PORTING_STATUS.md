# Porting status

| Domain | Endpoints ported / total | Tests ported / total | Gaps |
|---|---|---|---|
| shared/web + shared/security (request pipeline) + `apiv1` origin gate | `GET/POST /admin/panic` 2/2 (the `/v1` index and `/developers/origins` CRUD belong to `apiv1`) | 87 / 100 Java tests (149 Kof tests in `tests/security/`) | G28 to G35 |

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

Not ported (1 of 19): `CommunityChannelTests.channelRulesAreEnforcedByTheBackend` exercises `POST /feed/posts`
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
| `BlogEmailSender` (`sendHtml`) | identity (EmailService) | cannot send: records a FAILED `email_log` row `EMAIL_SENDER_NOT_WIRED` |
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

`kernel/http/Req.kf` (`queryAll`, `queryParam`, `formDecode`, raw-query decoding), `kernel/http/OutboundHttp.kf`, `kernel/text/{Regexes,Texts,Contrast,HtmlTemplate,Numbers}.kf`, `kernel/url/OriginNormalizer.kf`, `kernel/time/ZoneDates.kf`, `kernel/log/Log.kf` (`LogTap`), `kernel/db/Db.kf` (`poolStats`), `kernel/monitoring/{DayLog,HostResources,RequestMetrics,EventBuffer}.kf`. Gaps found: G220 to G230 in `KOF_GAPS.md`.
