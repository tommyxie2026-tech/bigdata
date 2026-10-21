package bigdata.ci;

public final class WarehouseLocationTest {
    public static void main(String[] args) {
        for (String valid : new String[] {"file:///var/lib/flink/cdc-paimon",
                "hdfs://127.0.0.1:9000/warehouse", "s3a://fixture-bucket/warehouse"}) {
            if (!WarehouseLocation.validate(valid).equals(valid)) throw new AssertionError(valid);
        }
        for (String invalid : new String[] {"/tmp/local", "https://example/warehouse",
                "hdfs:///missing-host", "hdfs://host/warehouse?query=yes", "s3a://bucket/a#fragment",
                "hdfs://user:secret@host/warehouse", "hdfs://host/a/../escape",
                "file://remote/warehouse", "hdfs://host/a'broken"}) {
            try {
                WarehouseLocation.validate(invalid);
                throw new AssertionError("Accepted invalid warehouse: " + invalid);
            } catch (IllegalArgumentException expected) {
                // Validation must fail before constructing SQL or accessing storage.
            }
        }
        System.out.println("PASS: warehouse URI positive and negative cases");
    }
}
