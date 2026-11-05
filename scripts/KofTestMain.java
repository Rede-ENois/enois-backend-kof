/**
 * Runs one compiled Kof test suite and exits the JVM when it returns. Suites that boot shared services
 * leave `spawn` loops (scheduler, outbox worker) running on non-daemon threads, so a normal return
 * never ended the process (docs/KOF_GAPS.md G124/G144). System.exit is not enough either: the Kof runtime
 * registers a shutdown hook that waits for spawned tasks (G150), so the suite ends with Runtime.halt, which
 * skips shutdown hooks. Output is flushed first. A failing suite still exits non-zero (KofJvmMain calls
 * System.exit(1) before any spawned loop matters), and any escaping throwable halts with 1.
 * Usage (from KofTool): java -cp <suite classes:deps:kof-cli.jar> scripts/KofTestMain.java <mainClass>
 */
public class KofTestMain {
    public static void main(String[] args) {
        try {
            Class.forName("dev.kof.runtime.KofJvmMain").getMethod("main", String[].class).invoke(null, (Object) args);
        } catch (java.lang.reflect.InvocationTargetException e) {
            e.getCause().printStackTrace();
            halt(1);
        } catch (Throwable t) {
            t.printStackTrace();
            halt(1);
        }
        halt(0);
    }

    static void halt(int code) {
        System.out.flush();
        System.err.flush();
        Runtime.getRuntime().halt(code);
    }
}
