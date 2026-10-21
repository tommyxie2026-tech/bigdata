package bigdata.ci;

import java.sql.*;
import java.util.*;
import org.apache.flink.api.common.restartstrategy.RestartStrategies;
import org.apache.flink.streaming.api.environment.StreamExecutionEnvironment;
import org.apache.flink.streaming.api.functions.sink.SinkFunction;
import org.apache.flink.table.api.bridge.java.StreamTableEnvironment;
import org.apache.flink.types.Row;
import org.apache.flink.types.RowKind;

/** Test-only PostgreSQL fixture and idempotent changelog materializer. Not part of the RPM. */
public final class PostgresSmoke {
    static Connection connect(String database) throws SQLException {
        return DriverManager.getConnection("jdbc:postgresql://127.0.0.1:5432/" + database
            + "?connectTimeout=5&socketTimeout=10",
            "postgres", "cdc-fixture");
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
                       : "INSERT INTO target_rows(id,name) VALUES (?,?) ON CONFLICT (id) DO UPDATE SET name=EXCLUDED.name")) {
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
        if (LakehouseTarget.enabled()) { LakehouseTarget.assertRows(expected); return; }
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
            try (Connection c = connect("postgres"); Statement s = c.createStatement();
                 ResultSet version = s.executeQuery("SHOW server_version")) {
                version.next();
                if (!version.getString(1).startsWith("14.15 "))
                    throw new AssertionError("Unexpected PostgreSQL fixture: " + version.getString(1));
            }
            statements("postgres", "CREATE DATABASE cdc_test");
            statements("cdc_test",
                "CREATE TABLE source_rows(id INT PRIMARY KEY,name VARCHAR(64))",
                "ALTER TABLE source_rows REPLICA IDENTITY FULL",
                "CREATE TABLE target_rows(id INT PRIMARY KEY,name VARCHAR(64))",
                "INSERT INTO source_rows VALUES(1,'before'),(2,'delete-me')");
            return;
        case "stopped-slot":
            for (int attempt=0; attempt<30; attempt++) {
                try (Connection c = connect("cdc_test"); Statement query = c.createStatement();
                     ResultSet slot = query.executeQuery("SELECT active,plugin,restart_lsn FROM pg_replication_slots WHERE slot_name='bigdata_ci'")) {
                    if (slot.next() && !slot.getBoolean(1) && slot.getString(2).equals("pgoutput")
                            && slot.getString(3) != null) return;
                }
                Thread.sleep(1000);
            }
            throw new AssertionError("Expected retained inactive pgoutput slot before offline writes");
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
        table.executeSql("CREATE TABLE postgres_source (id INT, name STRING, PRIMARY KEY(id) NOT ENFORCED) WITH ("
            + "'connector'='postgres-cdc','hostname'='127.0.0.1','port'='5432',"
            + "'username'='postgres','password'='cdc-fixture','database-name'='cdc_test',"
            + "'schema-name'='public','table-name'='source_rows','slot.name'='bigdata_ci','decoding.plugin.name'='pgoutput','scan.incremental.snapshot.enabled'='true','scan.lsn-commit.checkpoints-num-delay'='100000','scan.startup.mode'='initial','debezium.slot.drop.on.stop'='false','debezium.publication.name'='bigdata_ci_publication','debezium.publication.autocreate.mode'='filtered')");
        if (LakehouseTarget.enabled()) { LakehouseTarget.submit(table, "postgres_source"); return; }
        table.toChangelogStream(table.from("postgres_source"))
            .addSink(new Materialize()).name("test-only-postgres-materializer")
            .uid("test-only-postgres-materializer").setParallelism(1);
        env.execute("BIGDATA PostgreSQL CDC snapshot and recovery");
    }
}
