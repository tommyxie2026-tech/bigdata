#!/usr/bin/env bash
# Compile the full pinned SQL connector reactor, never a synthetic probe project.
set -Eeuo pipefail
: "${PHASE:?}" "${BUILD_TOOLCHAIN_ID:?}"
case "$PHASE" in cold|warm|offline) ;; *) exit 2 ;; esac
mkdir -p /work/evidence
source_sha=06581fc73b84b1da45fccf93441d96a118d9bfc1
git config --global --add safe.directory /source
[[ "$(git -C /source rev-parse HEAD)" == "$source_sha" ]]
java_bin=$(rpm -ql java-11-openjdk-devel | awk '/\/bin\/javac$/ && !found {print;found=1}')
test -x "$java_bin"
export JAVA_HOME
JAVA_HOME=$(dirname "$(dirname "$java_bin")")
export PATH="$JAVA_HOME/bin:$PATH"
java -version 2>&1 | grep -Eq 'version "11([.]|")'
keytool -importcert -noprompt -alias proxy-fixture -file /ca/tls.crt -keystore /work/trust.jks -storepass proxy-fixture
export MAVEN_OPTS="-Djavax.net.ssl.trustStore=/work/trust.jks -Djavax.net.ssl.trustStorePassword=proxy-fixture"
export MAVEN_MIRROR_URL=https://tls:8443/maven/ci-maven/
export MAVEN_RETRY_ATTEMPTS=2 MAVEN_RETRY_ATTEMPT_SECONDS=1200 MAVEN_RETRY_TOTAL_SECONDS=1500
if [[ "$PHASE" == offline ]]; then
  export MAVEN_NETWORK_MODE=offline MAVEN_RETRY_ATTEMPTS=1 MAVEN_RETRY_ATTEMPT_SECONDS=900 MAVEN_RETRY_TOTAL_SECONDS=900
elif [[ "$PHASE" == warm ]]; then
  export MAVEN_RETRY_ATTEMPT_SECONDS=900 MAVEN_RETRY_TOTAL_SECONDS=900
fi
test ! -e /work/source
cp -R /source/. /work/source
cd /work/source
start=$SECONDS
bash /workspace/scripts/ci/retry-maven-downloads.sh /work/evidence/compile.log \
  mvn -B -ntp -T 2 -DskipTests \
    -pl flink-cdc-connect/flink-cdc-source-connectors/flink-sql-connector-postgres-cdc -am package
elapsed=$((SECONDS - start))
jar=flink-cdc-connect/flink-cdc-source-connectors/flink-sql-connector-postgres-cdc/target/flink-sql-connector-postgres-cdc-3.4.0.jar
test -s "$jar"
jar tf "$jar" > /work/evidence/jar-entries.txt
grep -q 'PostgreSQLTableFactory.class' /work/evidence/jar-entries.txt
grep -qx 'org/postgresql/Driver.class' /work/evidence/jar-entries.txt
sha256sum "$jar" > /work/evidence/compiled-jar.sha256
(cd /root/.m2/repository && find . -type f \( -name '*.jar' -o -name '*.pom' \) -print0 | sort -z | xargs -0 sha256sum > /work/evidence/dependency-bytes.sha256)
rpm -q java-11-openjdk-devel maven > /work/evidence/toolchain.txt
export ELAPSED_SECONDS="$elapsed"
python3 - <<'PY'
import json,os,pathlib
p=pathlib.Path('/work/evidence')
result={'component':'flink-cdc-postgres','version':'3.4.0','phase':os.environ['PHASE'],
 'source_identity':'06581fc73b84b1da45fccf93441d96a118d9bfc1','toolchain_image':os.environ['BUILD_TOOLCHAIN_ID'],
 'compile_seconds':int(os.environ['ELAPSED_SECONDS']),'actual_sql_connector_and_jdbc_driver':'PASS',
 'compiled_jar':(p/'compiled-jar.sha256').read_text().split()[0],
 'dependency_files':len((p/'dependency-bytes.sha256').read_text().splitlines()),
 'rpm_build':'NOT_RUN','release':'NOT_RUN','status':'PASS'}
(p/'cycle-evidence.json').write_text(json.dumps(result,indent=2)+'\n')
PY
