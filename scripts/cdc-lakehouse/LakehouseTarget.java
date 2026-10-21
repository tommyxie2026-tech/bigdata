package bigdata.ci;

import java.util.Map;
import org.apache.flink.table.api.bridge.java.StreamTableEnvironment;

/** Test-only dispatch. Existing Paimon assertions and JDBC fallback remain unchanged. */
public final class LakehouseTarget {
    private static String target() {
        String target = System.getenv().getOrDefault("CDC_TARGET", "jdbc");
        if (!target.equals("jdbc") && !target.equals("paimon") && !target.equals("hudi"))
            throw new IllegalArgumentException("Unsupported CDC_TARGET: " + target);
        return target;
    }
    public static boolean enabled() { return !target().equals("jdbc"); }
    public static void submit(StreamTableEnvironment table, String source) {
        if (target().equals("hudi")) HudiTarget.submit(table, source);
        else if (target().equals("paimon")) PaimonTarget.submit(table, source);
        else throw new IllegalStateException("JDBC uses its existing materializer");
    }
    public static void assertRows(Map<Integer,String> expected) throws Exception {
        if (target().equals("hudi")) HudiTarget.assertRows(expected);
        else if (target().equals("paimon")) PaimonTarget.assertRows(expected);
        else throw new IllegalStateException("JDBC uses its existing assertion");
    }
}
