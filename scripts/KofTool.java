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
        System.exit(new ProcessBuilder(cmd).inheritIO().start().waitFor());
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
        int passed = 0, failed = 0, skipped = 0;
        for (Path f : files) {
            CompilerDriver driver = new CompilerDriver();
            driver.setDependencySourceRoots(List.of(moduleRoot));
            driver.setExternalClasspath(deps);
            Path tmp = Files.createTempDirectory("kof-test-");
            CompilationResult result = driver.compileForTests(f, tmp, Target.JVM, moduleRoot);
            if (!result.success()) {
                System.out.println("FAIL " + f);
                for (Diagnostic d : result.diagnostics().getDiagnostics()) System.out.println(d.format());
                failed++;
                continue;
            }
            if (driver.discoveredTests().isEmpty() && !driver.hasMainEntryPoint()) {
                System.out.println("SKIP " + f + " (no tests, no main)");
                skipped++;
                continue;
            }
            if (!driver.discoveredTests().isEmpty()) {
                System.out.println("SUITE " + f + " (" + driver.discoveredTests().size() + " tests)");
            }
            String mainClass = findMainClass(tmp);
            // KofTestMain exits the JVM once the suite returns: background loops started with `spawn`
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
            if (code == 0) {
                passed++;
            } else {
                System.out.println("FAIL " + f + " (exit code " + code + ")");
                failed++;
            }
        }
        System.out.println(passed + " passed, " + failed + " failed" + (skipped > 0 ? ", " + skipped + " skipped" : ""));
        System.exit(failed == 0 && passed > 0 ? 0 : 1);
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
