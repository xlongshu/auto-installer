#!/usr/bin/env bash

CLASSPATH="$HIVE_HOME/lib/*:$H2DRIVERS"

# windows
[[ -e "${WINDIR}" ]] && CLASSPATH=$(cygpath -wp "$CLASSPATH")
echo "$CLASSPATH"

tcpPort=${1:-"9092"}
java -cp "$CLASSPATH" org.h2.tools.Server -tcpShutdown tcp://localhost:${tcpPort}
