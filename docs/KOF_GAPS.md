# Kof gaps found while porting

Compiler/runtime issues hit by this project, measured on Kof 0.7.1 (JVM target). Each entry has a
minimal repro so it can be filed upstream on `KofLang/Kof4j`.

| # | Symptom | Repro | Workaround | Upstream |
|---|---|---|---|---|
| G1 | `db.execute`/`db.query` accept at most 4 bind params (`SEM025`), one shared connection | `db.execute(h, "insert into t values (?,?,?,?,?)", 1, 2, 3, 4, 5)` | `kernel.db` over HikariCP + JDBC | not filed |
| G2 | Java varargs call emits invalid bytecode: `VerifyError: String is not assignable to [Ljava/lang/String;` | `Flyway.configure().locations("filesystem:db")` | avoid varargs APIs; Flyway configured via `envVars()` | not filed |
| G3 | Reading a public primitive field of a Java object emits invalid bytecode (`VerifyError: integer is not assignable to Object`) | `Int n = flyway.migrate().migrationsExecuted` | use getters / avoid the field | not filed |
| G4 | Overload resolution picks the wrong Java overload (`IncompatibleClassChangeError`) | `FluentConfiguration.configuration(HashMap)` dispatches to `configuration(Configuration)` | avoid overloaded APIs or use a non-overloaded entry point | not filed |
| G5 | `Map<K, Bool>.get` returns `Troolean`, not `Bool?` | `ps.setBoolean(1, m.get(k))` → `SEM014` | `m.get(k) == true` | by design? |
| G6 | `kof check` ignores `kofdeps` jars (`PKG006` on third-party imports) while `kof run --deps` resolves them | `import com.zaxxer.hikari.HikariConfig` + `kof check` | validate with `kof test`/`kof run --deps` | not filed |
| G7 | HTTP server answers `Connection: close` on every response (no keep-alive) | any `app.get` | none yet; measure under load before go-live | not filed |
