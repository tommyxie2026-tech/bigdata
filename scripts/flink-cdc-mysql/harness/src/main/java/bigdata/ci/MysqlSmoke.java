package bigdata.ci;

import java.sql.*;
import java.util.*;
import org.apache.flink.api.common.restartstrategy.RestartStrategies;
import org.apache.flink.streaming.api.environment.StreamExecutionEnvironment;
import org.apache.flink.streaming.api.functions.sink.SinkFunction;
import org.apache.flink.table.api.bridge.java.StreamTableEnvironment;
import org.apache.flink.types.Row;
import org.apache.flink.types.RowKind;

/** Test-only MySQL fixture and idempotent changelog materializer. Not part of the RPM. */
public final class MysqlSmoke {
    static Connection connect(String database) throws SQLException {
        return DriverManager.getConnection("jdbc:mysql://127.0.0.1:3306/" + database
            + "?useSSL=false&allowPublicKeyRetrieval=true&connectTimeout=5000&socketTimeout=10000",
            "root", "cdc-fixture");
    }
    static void statements(String database, String... sqls) throws SQLException {
        try (Connection c = connect(database); Statement s = c.createStatement()) {
            for (String sql : sqls) s.execute(sql);
        }
    }
    static final class Materialize implements SinkFunction<Row> {
        @Override public void invoke(Row row, Context context) throws Exception {
            boolean delete = row.getKind() == RowKind.DELETE || row.getKind() == RowKind.UPDATE_BEFORE;
            try (Connection c = connect("cdc_test"); PreparedStatement s = c.prepareStatement(
                delete ? "DELETE FROM target_rows WHERE id=?"
                       : "INSERT INTO target_rows(id,name) VALUES (?,?) ON DUPLICATE KEY UPDATE name=VALUES(name)")) {
                s.setInt(1, ((Number) row.getField(0)).intValue());
                if (!delete) s.setString(2, (String) row.getField(1));
                s.executeUpdate();
            }
        }
    }
    static void assertRows(String phase) throws Exception {
        Map<Integer,String> expected = new TreeMap<>();
        if (phase.equals("snapshot")) { expected.put(1,"before"); expected.put(2,"delete-me"); }
        else if (phase.equals("changes")) { expected.put(1,"after"); expected.put(3,"inserted"); }
        else if (phase.equals("restored")) { expected.put(1,"offline-update"); expected.put(4,"offline-insert"); }
        else throw new IllegalArgumentException("unknown assertion phase");
        if (PaimonTarget.enabled()) { PaimonTarget.assertRows(expected); return; }
        long deadline = System.nanoTime() + 120_000_000_000L;
        Map<Integer,String> actual = new TreeMap<>();
        do {
            actual.clear();
            try (Connection c = connect("cdc_test"); Statement s = c.createStatement();
                 ResultSet rows = s.executeQuery("SELECT id,name FROM target_rows ORDER BY id")) {
                while (rows.next()) actual.put(rows.getInt(1), rows.getString(2));
            }
            if (actual.equals(expected)) {
                System.out.println(phase + ": PASS exact_rows=" + actual);
                return;
            }
            Thread.sleep(1000);
        } while (System.nanoTime() < deadline);
        throw new AssertionError(phase + " expected " + expected + " but found " + actual);
    }
    public static void main(String[] args) throws Exception {
        switch (args[0]) {
        case "prepare":
            statements("mysql", "CREATE DATABASE cdc_test");
            statements("cdc_test",
                "CREATE TABLE source_rows(id INT PRIMARY KEY,name VARCHAR(64))",
                "CREATE TABLE target_rows(id INT PRIMARY KEY,name VARCHAR(64))",
                "INSERT INTO source_rows VALUES(1,'before'),(2,'delete-me')");
            return;
        case "mutate":
            statements("cdc_test", "UPDATE source_rows SET name='after' WHERE id=1",
                "DELETE FROM source_rows WHERE id=2", "INSERT INTO source_rows VALUES(3,'inserted')");
            return;
        case "offline":
            statements("cdc_test", "UPDATE source_rows SET name='offline-update' WHERE id=1",
                "DELETE FROM source_rows WHERE id=3", "INSERT INTO source_rows VALUES(4,'offline-insert')");
            return;
        case "assert": assertRows(args[1]); return;
        case "job": break;
        default: throw new IllegalArgumentException("unknown mode");
        }
        StreamExecutionEnvironment env = StreamExecutionEnvironment.getExecutionEnvironment();
        env.setParallelism(1);
        env.enableCheckpointing(2000);
        env.setRestartStrategy(RestartStrategies.noRestart());
        env.getCheckpointConfig().setCheckpointStorage("file:///var/lib/flink/cdc-checkpoints");
        StreamTableEnvironment table = StreamTableEnvironment.create(env);
        table.executeSql("CREATE TABLE mysql_source (id INT, name STRING, PRIMARY KEY(id) NOT ENFORCED) WITH ("
            + "'connector'='mysql-cdc','hostname'='127.0.0.1','port'='3306',"
            + "'username'='root','password'='cdc-fixture','database-name'='cdc_test',"
            + "'table-name'='source_rows','server-id'='5401-5404','scan.startup.mode'='initial')");
        if (PaimonTarget.enabled()) { PaimonTarget.submit(table, "mysql_source"); return; }
        table.toChangelogStream(table.from("mysql_source"))
            .addSink(new Materialize()).name("test-only-mysql-materializer")
            .uid("test-only-mysql-materializer").setParallelism(1);
        env.execute("BIGDATA MySQL CDC snapshot and recovery");
    }
}
