#!/usr/bin/env bash
# Sourced in the initial client and the fresh post-restart JVM environment.
export HADOOP_CONF_DIR=/var/lib/flink/cdc-s3-conf HADOOP_OPTIONAL_TOOLS=hadoop-aws
export JAVA_TOOL_OPTIONS='-Djavax.net.ssl.trustStore=/var/lib/flink/cdc-s3-conf/trust.jks -Djavax.net.ssl.trustStorePassword=fixture-trust'
export HADOOP_CLASSPATH
HADOOP_CLASSPATH="$(hadoop classpath --glob):/usr/lib/hadoop/tools/lib/*"
