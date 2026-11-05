# Cross-domain seams: inventory and handoff

Domains were ported in parallel, so a caller that needed another domain got a caller-owned seam (a concrete class,
G30/G42) whose default reads or writes the owner's tables. The owners now exist: `src/app/AppWiring.kf` passes
subclasses (bridges) that call the owner's real API, so business rules live in one place. The defaults stay in the
code because the per-domain suites boot their own small app with them; production never uses them for a switched seam.

Status values: SWITCHED (this branch, `AppWiring` passes a bridge), WIRED (switched before this round),
KEPT (not switched, reason given), OPEN (owner exists, not switched yet, handoff).

Where a bridge lives: in the owner package when the import graph allows it, in `src/app` when it would create a cycle
or needs several owners. Tests that prove the wiring boot `AppWiring.installAll` (`src/app/WiredTestKit.kf`,
`tests/integration/*SeamsTest.kf`).

## Inventory

| Seam | Caller | Owner | Status |
|---|---|---|---|
| `ProfileNotifier` (profile, network) | profile | notifications | SWITCHED `ProfileNotificationsBridge` (profile is built before notifications, so the bridge is bound right after install) |
| `FeedNotifier` | feed | notifications | SWITCHED `FeedNotificationsBridge` |
| `IdentityNotifier` | identity | notifications | SWITCHED `IdentityNotificationsBridge` (kind SEGURANCA; `notifySecurity` gained `actorId`: the user for a new device, `sistema` for the TOTP reset, as in Java) |
| `StudyPairNotifier` | studypairs | notifications | SWITCHED `StudyPairNotificationsBridge` |
| `BlogNotifier` | blog | notifications | SWITCHED `BlogNotificationsBridge` (NEW_BLOG_POST) |
| `GroupNotifications` | groups | notifications | WIRED `GroupNotificationsBridge` |
| `NotificationActors` | notifications | profile, corporate | SWITCHED `ProfileNotificationActors` |
| `NotificationAccounts`, `DigestAccounts` | notifications | profile | SWITCHED `ProfileNotificationAccounts`, `ProfileDigestAccounts` |
| `DigestPersonalization` | notifications | preferences | SWITCHED `PreferencesDigestPersonalization` |
| `NotificationSources` | notifications | feed | SWITCHED `FeedNotificationSources` (feed store) |
| `NotificationCoins` | notifications | coin | WIRED `CoinNotificationCoins` |
| `NotificationPlaceReader` | notifications | communities, groups, events | PARTLY: events WIRED (`EventsNotificationPlaces`); communities and groups lookups OPEN (`communitiesByIds`, `communitiesOfPosts`, `groupsBySlugs` still read the tables) |
| `PushPresence` | push | presence | SWITCHED `PresencePushBridge` (`PushModule.withPresence`) |
| `FeedAuthors` | feed | profile, corporate, contributions | SWITCHED `ProfileFeedAuthors` (`src/app/FeedBridges.kf`; new `ContributionsStore.activeSealUserIds`, `CorporateService.byUserIds`) |
| `FeedMedia` | feed | media | SWITCHED `MediaFeedBridge` (ownership, visible cards, `requestPostMediaDeletion` now feeds the deletion jobs) |
| `FeedCommunities` | feed | communities | SWITCHED `CommunityFeedCommunities` |
| `FeedAgeGate` | feed | age | SWITCHED `AgeFeedGate` (a post or comment now needs a declared birth date and, for a minor, parental consent) |
| `FeedCoins` | feed | coin | SWITCHED `CoinFeedCoins` (presence streak and the `resposta:{postId}` answer reward, 20 faiscas at the current rate) |
| `FeedCorporate` | feed | corporate | WIRED `CorporateFeedBridge` |
| `FeedGraph` | feed | network | SWITCHED `NetworkFeedGraph` |
| `FeedBlogs` | feed | blog | SWITCHED `BlogFeedBlogs` (blog store) |
| `FeedReaderPrefs` | feed | preferences | SWITCHED `PreferencesFeedReader` |
| `FeedHoneypot` | feed | moderation | SWITCHED `ModerationHoneypot` (built before the feed, bound to the sanction service when moderation is installed; the hidden field bans through `banAuthor`) |
| `FeedModeration` GROUP_POST / GROUP_COMMENT removal | feed | groups | N/A: the Java `ReportedContentRemover` only removes POST and COMMENT; group reports are read (`GroupReportReader`) and decided without removal |
| `GamesFeed` | games | feed | SWITCHED `FeedGamesFeed` (a share is `FeedService.publish`: gates, limiters, mentions, counters, `PostPublished`) |
| `GamesCoins` | games, dailygames | coin | SWITCHED `CoinGamesCoins` (reward, purchase, scaled reward, rate, presence streak) |
| `BlogFeedPointers` | blog | feed | SWITCHED `FeedBlogPointers` (BLOG pointer post with tag `blog`; delete is the feed soft delete) |
| `BlogProfiles` | blog | profile | SWITCHED `ProfileBlogLookup` |
| `BlogCoins` | blog | coin | WIRED `CoinBlogCoins` |
| `LinkedInPostLookup` | linkedin | feed | SWITCHED `FeedLinkedInPosts` |
| `CommunityFeedLookup` | communities | feed | SWITCHED `FeedCommunityLookup` (`src/app/FeedBridges.kf`: real `FeedPage` and `PostView`, pin rule on the feed store) |
| `CommunityProfileLookup` | communities | profile | SWITCHED `ProfileCommunityLookup` |
| `CommunityCoins` | communities | coin | WIRED `CoinCommunityCoins` |
| `GroupProfileLookup` | groups | profile | SWITCHED `ProfileGroupLookup` |
| `GroupAgeGate` | groups | age | SWITCHED `AgeGroupGate` |
| `GroupMediaLookup` | groups | media | SWITCHED `MediaGroupLookup` |
| `GroupCoins` | groups | coin | WIRED `CoinGroupCoins` |
| `GroupReportReader` | groups | moderation | WIRED: moderation reads GROUP_POST / GROUP_COMMENT reports through `GroupsModule.reports` (`ModerationTargets`) |
| `ProjectsProfiles` | projects | profile | SWITCHED `ProfileProjectsLookup` |
| `CommunityProjectProfiles` | communityprojects | profile | SWITCHED `ProfileCommunityProjectLookup` |
| `CommunityProjectModerators` | communityprojects | moderation | SWITCHED `ModerationProjectModerators` (`src/app/ModerationBridges.kf`, approved application through `ModerationModeratorStore`) |
| `StudyPairProfiles` | studypairs | profile | SWITCHED `ProfileStudyPairLookup` |
| `StudyPairAgePolicy` | studypairs | age | SWITCHED `AgeStudyPairPolicy` |
| `StudyPairPreferences` | studypairs | preferences | SWITCHED `PreferencesStudyPairs` |
| `CallGroups` | calls | groups | SWITCHED `GroupsCallGroups` |
| `CallProfiles` | calls | profile | SWITCHED `ProfileCallLookup` |
| `MessagingAgePolicy` | messaging | age | SWITCHED `AgeMessagingPolicy` |
| `MessagingConnections` | messaging | network | SWITCHED `NetworkMessagingConnections` |
| `MessagingCorporate` | messaging | corporate | WIRED `CorporateMessagingBridge` |
| `MessagingCoins` | messaging | coin | WIRED `CoinMessagingCoins` |
| `ProfileParentalLinks` | profile | age | SWITCHED `AgeProfileParentalLinks` |
| `PreferencesThemeGallery` | preferences | themes | SWITCHED `ThemesPreferencesGallery` (`ThemeModule.withService`) |
| `ProfileBadgeOwnership` | profile | cosmetics | WIRED `cosmeticsCore.badges` |
| `ProfileForeignCounts`: events, mentoring | profile | events, mentoring | WIRED `OrgsForeignCounts` |
| `ProfileForeignCounts`: confirmedReportFacts | profile | moderation | SWITCHED `ModerationForeignCounts` (`ModerationStore.confirmedFactsAbout`); a sanction also clears `publicRanking` and `publicProfiles` through `ModerationProfileCaches` |
| `ProfileForeignCounts`: socialPosts, uniqueEngagers, deniedNotes, approvedNotes, communitiesJoined, jobAbandons | profile | feed, communities, jobs | OPEN: the Java profile adapter ran these as native queries too (no owner API with the same shape); only worth switching with owner methods |
| `OnboardingActions` | onboarding | preferences, profile, communities, groups, network | SWITCHED `AppOnboardingActions` (`src/app/OnboardingBridges.kf`; joins, connection requests, liked topics and skills now run the owners' rules, counters, notices and presence) |
| `OnboardingStore` reads (starter pack) | onboarding | communities, groups, network, preferences | OPEN: read-only candidate queries, no owner API for them |
| `IdentityUsers` | identity | profile | KEPT: the profile domain has no account creation API; the writes (signup, anonymise, verify, 2FA flags) are the repository saves identity does in Java |
| `IdentityIpBlocks`, `IdentitySignupGuard` | identity | moderation | WIRED: the defaults already are the moderation rules (`blocked_ips` lookup with the Java 5 s cache; the per-pod signup strike guard of `SuspiciousSignupGuard`); moderation writes the table through `ModerationIpBlocks`, proved in `ModerationSeamsTest` |
| `IdentityOAuthLinks` | identity | contributions | WIRED `ContributionsOAuthLinks` |
| `IdentityReputation` | identity | jobs/profile | WIRED `JobsIdentityReputation` |
| `AgeStore` birth date read | age | profile | KEPT: age owns the policy; Java `AgePolicyAdapter` reads the same column |
| `JobCompanies` | jobs | companies | WIRED `CompanyJobsBridge` |
| `JobCorporate` | jobs | corporate | WIRED `CorporateJobsBridge` |
| `CosmeticsContributors` | cosmetics | contributions | WIRED `ContributionsCosmeticsContributors` |
| `SupportService` GitHub identity | support | contributions | WIRED `SupportLinkedPeople` |
| `SuggestionsGithubToken` | suggestions | support | WIRED `SuggestionsSupportToken` |
| `CoinDisputeModeration` | coin | moderation | SWITCHED `ModerationCoinDispute` (report, `applyForReport` and `restrictUser` are the moderation services; bound after the moderation install) |
| `SecurityModerators`, `SecurityAutoReports`, `RiskEscalation` | kernel security and risk | moderation | SWITCHED `ModerationEarly` (hooks set before `Security.install`; `SharedServices.createWith` takes the escalation; all three bound to `ModerationService` at the end) |
| `ModerationCompanies` | moderation | companies | SWITCHED `ModerationCompaniesBridge` (`CompanyService.contentOf` / `ownerOf` / `closeByModeration`, which also tells the owner) |
| `/moderation/games`, `/moderation/services` | moderation | games, services | SWITCHED `ModerationReviewRoutes` (the owners' use cases behind the team guard and the own-submission rule) |
| `MediaImageReviewer`, `ModerationImages` | media, moderation | moderation (MediaSafetyAnalyzer) | OPEN: needs the MediaSafety analyzer (area 6, not ported) |
| `GifCommunityReader` | gifs | feed | KEPT: dead in Java (`CommunityGifProvider` is never registered as a bean), nothing reads it |
| `MediaPdfCleaner` | media | pdf library | OPEN: PDFBox needs the `loadPDF(byte[])` workaround of G281 and the save path of G164; not attempted in this round |
| `CallClock`, `PushSender`, `DigestMailer` | calls, push, notifications | none | KEPT: test seams or infrastructure, no owner |

## Tests proving the wiring

`tests/integration/NotificationSeamsTest.kf`, `FeedSeamsTest.kf`, `CommunitySeamsTest.kf`, `ModerationSeamsTest.kf` boot the production wiring:
connection request and mention go through the Notifications API (a listener on the API sees the event), a game share is
a feed post with `PostPublished`, a blog post is a BLOG pointer post and raises NEW_BLOG_POST, the community and channel
feeds are the real feed (channel rules ported from `CommunityChannelTests.channelRulesAreEnforcedByTheBackend`, pin),
and onboarding joins a community, asks for a connection and saves a skill through the owners.

## Handoff: what is left

- OPEN rows above.
- Feed and coins tests still waiting for a wired suite (PORTING_STATUS): the coin-ledger reaction test, the identity
  presentation tests (profile cosmetics frame and name style on a post) and the Mockito media-embedding test.
- Moderation seams are switched except `MediaImageReviewer` and the reported-image reader (they need the MediaSafety
  analyzer, see PORTING_STATUS "moderation").
