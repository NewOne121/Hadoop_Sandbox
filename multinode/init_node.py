#!/usr/bin/python

import sys
import subprocess
import argparse

###TODO
#Cluster control. add/bootstrap node, start/stop/restart cluster/component
#How to delive cluster configs?
#$HADOOP_PREFIX/bin/hdfs namenode -format <cluster_name>
#$HADOOP_PREFIX/sbin/hadoop-daemon.sh --config $HADOOP_CONF_DIR --script hdfs start namenode
#$HADOOP_PREFIX/sbin/hadoop-daemons.sh --config $HADOOP_CONF_DIR --script hdfs start datanode

#If etc/hadoop/slaves and ssh trusted access is configured (see Single Node Setup), all of the HDFS processes can be started with a utility script. As hdfs:
#$HADOOP_PREFIX/sbin/start-dfs.sh

#Setup cluster key exchange

#$HADOOP_YARN_HOME/sbin/yarn-daemon.sh --config $HADOOP_CONF_DIR start resourcemanager
#$HADOOP_YARN_HOME/sbin/yarn-daemons.sh --config $HADOOP_CONF_DIR start nodemanager
#$HADOOP_YARN_HOME/sbin/yarn-daemon.sh --config $HADOOP_CONF_DIR start proxyserver
#If etc/hadoop/slaves and ssh trusted access is configured (see Single Node Setup), all of the YARN processes can be started with a utility script. As yarn:
#$HADOOP_PREFIX/sbin/start-yarn.sh
#$HADOOP_PREFIX/sbin/mr-jobhistory-daemon.sh --config $HADOOP_CONF_DIR start historyserver
