import dev.kof.compiler.CompilationResult;
import dev.kof.compiler.CompilerDriver;
import dev.kof.compiler.Diagnostic;
import dev.kof.compiler.Target;
import java.io.File;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.stream.Stream;

/**
 * `kof test` / `kof run` with the kofdeps jars on the compiler and runtime classpath.
 * Kof 0.7.1's `kof test` never sets an external classpath (docs/KOF_GAPS.md G9) and `kof run`
 * resolves imports from the kof.toml project root instead of src/ (G10), so the kernel (HikariCP,
 * H2, Flyway) cannot be compiled by either. Same flow as CmdTest/CmdRun (JVM target).
 * Usage: see scripts/kof-test and scripts/kof-run.
 */
public class KofTool {
    static final Path TEST_MAIN = Path.of(System.getProperty("kof.tool.dir", "scripts"), "KofTestMain.java").toAbsolutePath();
    static final long SUITE_TIMEOUT_SECONDS = Long.getLong("kof.suite.timeout", 900L);

    public static void main(String[] args) throws Exception {
        if (args[0].equals("run")) {
            run(args);
            return;
        }
        test(args);
    }

    static void run(String[] args) throws Exception {
        Path moduleRoot = Path.of(args[1]);
        String depsCp = args[2];
        Path mainFile = Path.of(args[3]);
        String cliJar = System.getProperty("java.class.path").split(File.pathSeparator)[0];
        List<Path> deps = new ArrayList<>();
        for (String part : depsCp.split(File.pathSeparator)) {
            if (!part.isBlank()) deps.add(Path.of(part));
        }
        List<Path> sources = new ArrayList<>();
        sources.add(mainFile.toAbsolutePath().normalize());
        try (Stream<Path> s = Files.list(mainFile.toAbsolutePath().normalize().getParent())) {
            s.filter(f -> f.toString().endsWith(".kf")).sorted().forEach(f -> {
                if (!sources.contains(f)) sources.add(f);
            });
        }
        CompilerDriver driver = new CompilerDriver();
        driver.setDependencySourceRoots(List.of(moduleRoot));
        driver.setExternalClasspath(deps);
        Path tmp = Files.createTempDirectory("kof-run-");
        CompilationResult result = driver.compileSources(sources, tmp, Target.JVM, moduleRoot.toAbsolutePath().normalize());
        for (Diagnostic d : result.diagnostics().getDiagnostics()) System.err.println(d.format());
        if (!result.success()) System.exit(1);
        List<String> cmd = new ArrayList<>(List.of(
                Path.of(System.getProperty("java.home"), "bin", "java").toString(),
                "-Dstdout.encoding=UTF-8", "-Dstderr.encoding=UTF-8",
                "-cp", tmp + File.pathSeparator + depsCp + File.pathSeparator + cliJar,
                "dev.kof.runtime.KofJvmMain", findMainClass(tmp)));
        // The app runs in a child JVM: stop it with the launcher, or a killed launcher leaves the app holding
        // its port and later boots silently talk to the stale build.
        Process app = new ProcessBuilder(cmd).inheritIO().start();
        // SIGTERM alone is not enough: the Kof runtime shutdown hook waits for spawned loops (G150), so the
        // app gets a short grace period and is then killed.
        Runtime.getRuntime().addShutdownHook(new Thread(() -> {
            app.descendants().forEach(ProcessHandle::destroy);
            app.destroy();
            try {
                if (!app.waitFor(5, java.util.concurrent.TimeUnit.SECONDS)) {
                    app.descendants().forEach(ProcessHandle::destroyForcibly);
                    app.destroyForcibly();
                }
            } catch (InterruptedException e) {
                app.destroyForcibly();
            }
        }));
        System.exit(app.waitFor());
    }

    static void test(String[] args) throws Exception {
        Path moduleRoot = Path.of(args[1]);
        String depsCp = args[2];
        String cliJar = System.getProperty("java.class.path").split(File.pathSeparator)[0];
        List<Path> deps = new ArrayList<>();
        for (String part : depsCp.split(File.pathSeparator)) {
            if (!part.isBlank()) deps.add(Path.of(part));
        }
        List<Path> files = new ArrayList<>();
        for (int i = 3; i < args.length; i++) {
            Path p = Path.of(args[i]);
            if (Files.isDirectory(p)) {
                try (Stream<Path> s = Files.walk(p)) {
                    s.filter(f -> f.toString().endsWith(".kf")).sorted(Comparator.naturalOrder()).forEach(files::add);
                }
            } else {
                files.add(p);
            }
        }
        int jobs = Integer.parseInt(System.getenv().getOrDefault("KOF_TEST_JOBS", "3"));
        if (files.size() > 1 && jobs > 1) {
            parallel(args, files, jobs);
            return;
        }
        int passed = 0, failed = 0, skipped = 0;
        for (Path f : files) {
            int code = runOne(f, moduleRoot, deps, depsCp, cliJar);
            if (code == SKIPPED) {
                skipped++;
            } else if (code == 0) {
                passed++;
            } else {
                failed++;
            }
        }
        System.out.println(passed + " passed, " + failed + " failed" + (skipped > 0 ? ", " + skipped + " skipped" : ""));
        System.exit(failed == 0 && passed > 0 ? 0 : 1);
    }

    static final int SKIPPED = -2;

    // Compiles and runs one test file; prints SUITE/SKIP/FAIL/TIMEOUT lines; returns the suite exit code.
    static int runOne(Path f, Path moduleRoot, List<Path> deps, String depsCp, String cliJar) throws Exception {
        CompilerDriver driver = new CompilerDriver();
        driver.setDependencySourceRoots(List.of(moduleRoot));
        driver.setExternalClasspath(deps);
        Path tmp = Files.createTempDirectory("kof-test-");
        try {
            CompilationResult result = driver.compileForTests(f, tmp, Target.JVM, moduleRoot);
            if (!result.success()) {
                System.out.println("FAIL " + f);
                for (Diagnostic d : result.diagnostics().getDiagnostics()) System.out.println(d.format());
                return 1;
            }
            if (driver.discoveredTests().isEmpty() && !driver.hasMainEntryPoint()) {
                System.out.println("SKIP " + f + " (no tests, no main)");
                return SKIPPED;
            }
            if (!driver.discoveredTests().isEmpty()) {
                System.out.println("SUITE " + f + " (" + driver.discoveredTests().size() + " tests)");
            }
            String mainClass = findMainClass(tmp);
            // KofTestMain halts the JVM once the suite returns: background loops started with `spawn`
            // (scheduler, outbox worker) are non-daemon and used to keep finished suites alive forever.
            List<String> cmd = new ArrayList<>(List.of(
                    Path.of(System.getProperty("java.home"), "bin", "java").toString(),
                    "-Dstdout.encoding=UTF-8", "-Dstderr.encoding=UTF-8",
                    "-cp", tmp + File.pathSeparator + depsCp + File.pathSeparator + cliJar,
                    TEST_MAIN.toString(), mainClass));
            Process proc = new ProcessBuilder(cmd).inheritIO().start();
            int code;
            if (proc.waitFor(SUITE_TIMEOUT_SECONDS, java.util.concurrent.TimeUnit.SECONDS)) {
                code = proc.exitValue();
            } else {
                proc.descendants().forEach(ProcessHandle::destroyForcibly);
                proc.destroyForcibly();
                System.out.println("TIMEOUT " + f + " (> " + SUITE_TIMEOUT_SECONDS + "s, killed)");
                code = 124;
            }
            if (code != 0) System.out.println("FAIL " + f + " (exit code " + code + ")");
            return code;
        } finally {
            deleteTree(tmp);
        }
    }

    // Every test file recompiles the whole module, so files run as separate single-file child runs, `jobs` at a
    // time (KOF_TEST_JOBS). Each child's output is buffered and printed whole when it ends, so suites never
    // interleave. Separate processes, not threads: the compiler keeps static state.
    static void parallel(String[] args, List<Path> files, int jobs) throws Exception {
        String launcher = Path.of(System.getProperty("java.home"), "bin", "java").toString();
        String cliJar = System.getProperty("java.class.path").split(File.pathSeparator)[0];
        Path self = Path.of(System.getProperty("kof.tool.dir", "scripts"), "KofTool.java").toAbsolutePath();
        java.util.concurrent.ExecutorService pool = java.util.concurrent.Executors.newFixedThreadPool(jobs);
        List<java.util.concurrent.Future<int[]>> results = new ArrayList<>();
        Object printLock = new Object();
        for (Path f : files) {
            results.add(pool.submit(() -> {
                Path log = Files.createTempFile("kof-test-", ".log");
                try {
                    List<String> cmd = List.of(launcher, "-cp", cliJar, self.toString(), "test", args[1], args[2], f.toString());
                    ProcessBuilder pb = new ProcessBuilder(cmd).redirectErrorStream(true).redirectOutput(log.toFile());
                    pb.environment().put("KOF_TEST_JOBS", "1");
                    Process child = pb.start();
                    int code = child.waitFor();
                    String out = Files.readString(log);
                    synchronized (printLock) {
                        System.out.print(out);
                        System.out.flush();
                    }
                    boolean skipped = out.contains("SKIP " + f) && !out.contains("SUITE " + f);
                    return new int[] {code, skipped ? 1 : 0};
                } finally {
                    Files.deleteIfExists(log);
                }
            }));
        }
        int passed = 0, failed = 0, skipped = 0;
        for (java.util.concurrent.Future<int[]> r : results) {
            int[] v = r.get();
            if (v[1] == 1) {
                skipped++;
            } else if (v[0] == 0) {
                passed++;
            } else {
                failed++;
            }
        }
        pool.shutdown();
        System.out.println(passed + " passed, " + failed + " failed" + (skipped > 0 ? ", " + skipped + " skipped" : ""));
        System.exit(failed == 0 && passed > 0 ? 0 : 1);
    }

    static void deleteTree(Path dir) {
        try (Stream<Path> s = Files.walk(dir)) {
            s.sorted(Comparator.reverseOrder()).forEach(p -> p.toFile().delete());
        } catch (Exception ignored) {
            // best effort: a leftover temp dir is not a test failure
        }
    }

    static String findMainClass(Path dir) throws Exception {
        try (Stream<Path> s = Files.walk(dir)) {
            List<String> classes = s.filter(p -> p.toString().endsWith(".class"))
                    .map(p -> dir.relativize(p).toString().replace(".class", "").replace('/', '.'))
                    .toList();
            for (String c : classes) {
                if (c.endsWith(".Main") || c.equals("Main")) return c;
            }
            return classes.get(classes.size() - 1);
        }
    }
}
