# Porting guide (domain waves)

Shared rules for every agent porting Java domains in parallel. AGENTS.md still applies in full.

## Worktree and branch

```bash
cd /Users/fabiohr/Projects/enois/enois-backend-kof
git worktree add ../.worktrees/kof-<slug> -b port/<slug> main
cd ../.worktrees/kof-<slug>
export PATH="$HOME/.local/kof:$PATH" JAVA_TOOL_OPTIONS="-Xmx1g"
```

Commit on your branch only. Never push, never merge, never touch another worktree.

## Module shape

Each domain has `src/<domain>/<Domain>Module.kf` with one static entry point,
`static install(platform: Platform, shared: SharedServices, hooks: SecurityHooks)`, that builds its stores,
services and routes, registers its jobs/outbox handlers, and returns the module object when other modules
need it. `Main.kf` gets exactly one line per domain, after `Security.install`, so merges stay trivial.

## Cross-domain seams

Several domains are ported at the same time, so the domain you call may not exist yet.

- The **caller** owns the seam: a concrete class in its own package, e.g. `class FeedAuthorLookup`, with
  overridable methods (interfaces from another package do not work, G30).
- Its **default implementation reads the owner's tables read-only** with the same SQL the owner uses, so
  behaviour and tests are real from day one. Mark it `// pending-port: <owner>` and list it in
  `docs/PORTING_STATUS.md`.
- Writes into another domain (notify a user, credit coins, open a report) go through the seam too; the
  default may write the owner's table only when that is a single insert the Java code also does directly,
  otherwise it is a logged no-op listed as pending.
- When the owner is ported, it subclasses the seam and `Main.kf` passes the subclass in.

## Tests

- Run only your domain while working: `scripts/kof-test tests/<domain>`; the full suite (`scripts/kof-test`)
  once before each commit that touches `src/kernel` and before your final commit.
- Port every Java test of your domains (`backend-ref/src/test/java/com/socialcoisa/rede/<domain>`), HTTP-level
  with `kernel.testkit`. Never weaken an assertion; unportable tests get a reason in `docs/PORTING_STATUS.md`.

## Kernel changes

Prefer not to change `src/kernel`. If you must (a missing helper, a kernel bug), keep it minimal, add a test,
and mention it in your final report: other agents are changing the same files.

## Docs

- `docs/PORTING_STATUS.md`: append your own section (`## <domain>`); do not edit other sections.
- `docs/KOF_GAPS.md`: append rows using only your assigned G-number range.
- `docs/KERNEL.md`: only if you changed the kernel.
