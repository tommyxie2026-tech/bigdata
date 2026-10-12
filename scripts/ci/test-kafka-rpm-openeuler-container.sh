#!/usr/bin/env bash
set -euo pipefail

EVIDENCE_ROOT="${EVIDENCE_ROOT:-/evidence}"
KAFKA_HOME="${KAFKA_HOME:-/usr/lib/kafka}"
CONF="$(mktemp -d /tmp/kafka-kraft.XXXXXX)"
DATA="$(mktemp -d /tmp/kafka-kraft-data.XXXXXX)"
BROKER_LOG="${EVIDENCE_ROOT}/kafka-broker.log"
BROKER_PID=""

cleanup() {
  if [[ -n "${BROKER_PID}" ]]; then
    kill "${BROKER_PID}" 2>/dev/null || true
    wait "${BROKER_PID}" 2>/dev/null || true
  fi
}
trap cleanup EXIT

id="$("${KAFKA_HOME}/bin/kafka-storage.sh" random-uuid)"
cat > "${CONF}/server.properties" <<EOF
process.roles=broker,controller
node.id=1
controller.quorum.voters=1@127.0.0.1:9093
listeners=PLAINTEXT://127.0.0.1:9092,CONTROLLER://127.0.0.1:9093
advertised.listeners=PLAINTEXT://127.0.0.1:9092
listener.security.protocol.map=CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT
controller.listener.names=CONTROLLER
inter.broker.listener.name=PLAINTEXT
log.dirs=${DATA}
offsets.topic.replication.factor=1
transaction.state.log.replication.factor=1
transaction.state.log.min.isr=1
num.partitions=1
group.initial.rebalance.delay.ms=0
EOF
chown -R kafka:kafka "${CONF}" "${DATA}"
runuser -u kafka -- "${KAFKA_HOME}/bin/kafka-storage.sh" format \
  --ignore-formatted -t "${id}" -c "${CONF}/server.properties"
runuser -u kafka -- "${KAFKA_HOME}/bin/kafka-server-start.sh" \
  "${CONF}/server.properties" >"${BROKER_LOG}" 2>&1 &
BROKER_PID=$!

ready=false
for _ in $(seq 1 60); do
  if timeout 2 bash -c '</dev/tcp/127.0.0.1/9092' 2>/dev/null; then
    ready=true
    break
  fi
  if ! kill -0 "${BROKER_PID}" 2>/dev/null; then
    cat "${BROKER_LOG}" >&2
    exit 1
  fi
  sleep 2
done
[[ "${ready}" == true ]] || { cat "${BROKER_LOG}" >&2; exit 1; }
echo 'broker_start: PASS' > "${EVIDENCE_ROOT}/broker_start.txt"

topic="ci-smoke-${RANDOM}-${RANDOM}"
"${KAFKA_HOME}/bin/kafka-topics.sh" --bootstrap-server 127.0.0.1:9092 \
  --create --if-not-exists --topic "${topic}" --partitions 1 --replication-factor 1
printf 'bigdata-ci-roundtrip\n' | "${KAFKA_HOME}/bin/kafka-console-producer.sh" \
  --bootstrap-server 127.0.0.1:9092 --topic "${topic}"
actual="$(timeout 30 "${KAFKA_HOME}/bin/kafka-console-consumer.sh" \
  --bootstrap-server 127.0.0.1:9092 --topic "${topic}" --from-beginning \
  --max-messages 1 2>"${EVIDENCE_ROOT}/kafka-consumer.log" | head -n 1)"
[[ "${actual}" == bigdata-ci-roundtrip ]]
echo 'topic_roundtrip: PASS' > "${EVIDENCE_ROOT}/topic_roundtrip.txt"
