#!/usr/bin/env bash

nohup hive --service metastore 1>${HADOOP_DATA_PREFIX}/hive/hive_metastore.log 2>&1 &
