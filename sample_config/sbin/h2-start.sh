#!/usr/bin/env bash

SH_DIR=$(cd "$(dirname "$0")"; pwd)
CLASSPATH="$HIVE_HOME/lib/*:$H2DRIVERS:$SPARK_HOME/jars/*"

# windows
if [[ -e "${WINDIR}" ]]; then
    CLASSPATH=$(cygpath -wp "$CLASSPATH")
    SH_DIR=$(cygpath -w "$SH_DIR")
fi
echo "$CLASSPATH"

args="$@ -baseDir '$SH_DIR' -ifNotExists -webAllowOthers -tcpAllowOthers -pgAllowOthers "
echo args: ${args}

java -cp "$CLASSPATH" org.h2.tools.Server ${args}
