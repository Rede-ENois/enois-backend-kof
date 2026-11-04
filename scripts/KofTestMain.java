/**
 * Runs one compiled Kof test suite and exits the JVM when it returns. Suites that boot shared services
 * leave `spawn` loops (scheduler, outbox worker) running on non-daemon threads, so a normal return
 * never ended the process (docs/KOF_GAPS.md G124/G144). A failing suite still exits non-zero through
 * KofJvmMain, and any escaping throwable exits 1.
 * Usage (from KofTool): java -cp <suite classes:deps:kof-cli.jar> scripts/KofTestMain.java <mainClass>
 */
public class KofTestMain {
    public static void main(String[] args) {
        try {
            Class.forName("dev.kof.runtime.KofJvmMain").getMethod("main", String[].class).invoke(null, (Object) args);
        } catch (java.lang.reflect.InvocationTargetException e) {
            e.getCause().printStackTrace();
            System.exit(1);
        } catch (Throwable t) {
            t.printStackTrace();
            System.exit(1);
        }
        System.out.flush();
        System.exit(0);
    }
}
