### Hadoop Sandbox

Hadoop Sandbox on a Standalone Linux Node.<br/>
Pseudo distributed clustering will be performed for HDFS, YARN, HBase and Spark.

#### Usage
      bash install.sh [--apps=all|{hdfs,yarn,hive,hbase,sqoop,kafka,flume,spark}] [--installdir=/absolute/path] [--datadir=/absolute/path]
      arguments:
       --apps       : all (Installs all supported components)
                      hdfs,yarn,.. (comma seperated list of components)
       --installdir : absolute path to the directory for sandbox installation
       --datadir    : absolute path to the directory for components' data 

**Operating System:** Ubuntu<br/>
**Distribution:** Apache<br/>
**Components:** HDFS, YARN, Hive (w/ Tez), HBase, Sqoop, Kafka, Flume, Spark
