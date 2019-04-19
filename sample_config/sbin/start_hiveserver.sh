#!/usr/bin/env bash
# hive --service hiveserver2
# nohup hiveserver2 1>${HADOOP_DATA_PREFIX}/hive/hiveserver.log 2>${HADOOP_DATA_PREFIX}/hive/hiveserver.err &
nohup hiveserver2 1>${HADOOP_DATA_PREFIX}/hive/hiveserver.log 2>&1 &
