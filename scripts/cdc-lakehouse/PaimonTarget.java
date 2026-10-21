package bigdata.ci;

import java.util.Map;
import java.util.TreeMap;
import org.apache.flink.table.api.EnvironmentSettings;
import org.apache.flink.table.api.TableEnvironment;
import org.apache.flink.table.api.TableResult;
import org.apache.flink.table.api.bridge.java.StreamTableEnvironment;
import org.apache.flink.types.Row;
import org.apache.flink.util.CloseableIterator;

/** Test-only target. Each assertion starts a fresh bounded reader of committed lake files. */
public final class PaimonTarget {
    public static boolean enabled() {
        String target = System.getenv().getOrDefault("CDC_TARGET", "jdbc");
        if (!target.equals("jdbc") && !target.equals("paimon"))
            throw new IllegalArgumentException("Unsupported CDC_TARGET: " + target);
        return target.equals("paimon");
    }
    private static void define(TableEnvironment table) {
        table.executeSql("CREATE CATALOG lakehouse WITH ('type'='paimon',"
            + "'warehouse'='" + WarehouseLocation.configured() + "')");
        table.executeSql("CREATE DATABASE IF NOT EXISTS lakehouse.cdc_ci");
        table.executeSql("CREATE TABLE IF NOT EXISTS lakehouse.cdc_ci.lake_rows (id INT, name STRING, "
            + "PRIMARY KEY(id) NOT ENFORCED) WITH ('bucket'='1')");
    }
    public static void submit(StreamTableEnvironment table, String source) {
        if (!source.equals("mysql_source") && !source.equals("postgres_source"))
            throw new IllegalArgumentException("Unexpected source table");
        define(table);
        table.executeSql("INSERT INTO lakehouse.cdc_ci.lake_rows SELECT id, name FROM " + source);
    }
    public static void assertRows(Map<Integer,String> expected) throws Exception {
        long deadline = System.nanoTime() + 120_000_000_000L;
        Map<Integer,String> actual = new TreeMap<>();
        do {
            TableEnvironment reader = TableEnvironment.create(EnvironmentSettings.inBatchMode());
            reader.getConfig().getConfiguration().setString("execution.target", "local");
            reader.getConfig().getConfiguration().setInteger("parallelism.default", 1);
            define(reader);
            TableResult rows = reader.executeSql("SELECT id, name FROM lakehouse.cdc_ci.lake_rows");
            actual.clear();
            try (CloseableIterator<Row> iterator = rows.collect()) {
                while (iterator.hasNext()) {
                    Row row = iterator.next();
                    int key = ((Number) row.getField(0)).intValue();
                    if (actual.containsKey(key)) throw new AssertionError("Duplicate key: " + key);
                    actual.put(key, (String) row.getField(1));
                }
            }
            if (actual.equals(expected)) {
                System.out.println("paimon: PASS exact_rows=" + actual);
                return;
            }
            Thread.sleep(1000);
        } while (System.nanoTime() < deadline);
        throw new AssertionError("Paimon expected " + expected + " but found " + actual);
    }
}
