package bigdata.ci;

import java.net.URI;
import java.util.Set;

/** Only explicit supported warehouse URIs may enter the test's SQL catalog. */
public final class WarehouseLocation {
    public static String configured() {
        return validate(System.getenv().getOrDefault("CDC_WAREHOUSE", "file:///var/lib/flink/cdc-paimon"));
    }
    public static String validate(String location) {
        URI uri = URI.create(location);
        String scheme = uri.getScheme();
        if (scheme == null || !Set.of("file", "hdfs", "s3a").contains(scheme)
                || uri.getUserInfo() != null || uri.getQuery() != null || uri.getFragment() != null
                || uri.getPath() == null || !uri.getPath().startsWith("/")
                || !uri.normalize().equals(uri) || location.contains("'") || location.contains("\\"))
            throw new IllegalArgumentException("Invalid warehouse URI");
        if (scheme.equals("file")) {
            if (uri.getAuthority() != null && !uri.getAuthority().equals("localhost"))
                throw new IllegalArgumentException("Non-local file warehouse");
        } else if (uri.getAuthority() == null || uri.getAuthority().isBlank()) {
            throw new IllegalArgumentException("Remote warehouse has no authority");
        }
        return location;
    }
}
