#!/bin/bash

# install_hadoop.sh

PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

#=================================================
#  Description: Install Hadoop
#  System Required: Linux/Unix
#  Author: LongShu
#=================================================


#=================================================
APP_USER="hadoop"
ADD_APP_USER="false"
JAVA_VER=8 # 7, 8
DOWNLOAD_DIR=/data/download
INSTALL_PREFIX=/opt/app
DATA_DIR=/data/hadoop
CONF_DIR=${DATA_DIR}/conf
LOG_FILE=/tmp/install_hadoop.log

HADOOP_HOST='localhost' # 127.0.0.1, 192.168.56.1
#=================================================


#=================================================
MIRRORS="https://mirrors.tuna.tsinghua.edu.cn/apache"
# http://mirrors.ustc.edu.cn/apache
APACHE_DIST="http://archive.apache.org/dist"

ZK_DL_URL="$APACHE_DIST/zookeeper/zookeeper-3.4.13/zookeeper-3.4.13.tar.gz"
HADOOP_DL_URL="$MIRRORS/hadoop/common/hadoop-2.7.7/hadoop-2.7.7.tar.gz"
HIVE_DL_URL="$MIRRORS/hive/hive-1.2.2/apache-hive-1.2.2-bin.tar.gz"
SPARK_DL_URL="$MIRRORS/spark/spark-2.3.3/spark-2.3.3-bin-hadoop2.7.tgz"
HBASE_DL_URL="$MIRRORS/hbase/1.4.9/hbase-1.4.9-bin.tar.gz"

# mysql: com.mysql.jdbc.Driver, jdbc:mysql://localhost:3306/hive?createDatabaseIfNotExist=true&amp;useSSL=false
DRIVER_DL_URL="http://central.maven.org/maven2/mysql/mysql-connector-java/5.1.40/mysql-connector-java-5.1.40.jar"
#=================================================

CUR_DIR=$(pwd)
BASE_DIR="$(cd "$(dirname "$0")"; pwd)"
cd "${BASE_DIR}"

if [[ -f ./common.sh ]]; then
    echo ". ./common.sh"
    . ./common.sh
else
    curl -o ./common.sh https://raw.githubusercontent.com/xlongshu/auto-installer/master/common.sh
    chmod +x ./common.sh
    echo ". ./common.sh"
    . ./common.sh
fi


function pre_install() {
    mkdir -p ${DOWNLOAD_DIR}
    mkdir -p ${INSTALL_PREFIX}

    if [[ "$release" == "centos" ]]; then
        disable_selinux
        yum update
        yum install openssh-server wget vim "java-1.$JAVA_VER.0-openjdk-devel" -y
    else
        apt-get update
        apt-get install openssh-server wget vim "openjdk-$JAVA_VER-jdk" rsync -y
    fi
}


function download_install() {
    local dl_url=$1

    local archive_name=$(get_path_file_name ${dl_url}) # hadoop-x.y.z.tar.gz
    local name_var=$(get_name_var ${archive_name}) # hadoop-x.y.z
    local target_path="$INSTALL_PREFIX/$name_var"

    if [[ ! -e ${target_path} ]]; then
        file_path=$(download_file ${dl_url} ${DOWNLOAD_DIR}) # download_file
        out_path=$(unpack_file ${file_path} ${INSTALL_PREFIX}) # unpack_file
        dir_name=$(get_path_file_name ${out_path})

        if [[ ${dir_name} != ${name_var} ]]; then
            log_info "Rename [${dir_name}] to [${name_var}]."
            mv ${INSTALL_PREFIX}/${dir_name} ${target_path}
        fi

        set_owner ${target_path}
        log_info "Install ${archive_name} into [$target_path]."
    else
        log_warn "Already exists [$target_path] !"
    fi
}

function set_env_hadoop() {
    mkdir -p ${DATA_DIR} ${DATA_DIR}/zookeeper ${DATA_DIR}/hadoop ${DATA_DIR}/hive ${DATA_DIR}/hbase
    mkdir -p ${CONF_DIR}/hadoop ${CONF_DIR}/zookeeper ${CONF_DIR}/hive ${CONF_DIR}/spark ${CONF_DIR}/hbase

    if [[ -f ${CONF_DIR}/env_hadoop.sh ]]; then
        log_warn "Backup [${CONF_DIR}/env_hadoop.sh] !"
        mv -f ${CONF_DIR}/env_hadoop.sh ${CONF_DIR}/env_hadoop.sh.bak
    fi

    log_info "Generate [${CONF_DIR}/env_hadoop.sh] ..."
    cat << EOF > ${CONF_DIR}/env_hadoop.sh
# env_hadoop.sh

export HADOOP_INSTALL_PREFIX=${INSTALL_PREFIX}
export HADOOP_DATA_PREFIX=${DATA_DIR}
export HADOOP_CONF_PREFIX=${CONF_DIR}

export HADOOP_SSH_OPTS="-p 22"
#export HADOOP_HEAPSIZE=600

# ZooKeeper
export ZK_HOME=\${HADOOP_INSTALL_PREFIX}/$(get_name_var ${ZK_DL_URL})
export ZOOBINDIR=\${ZK_HOME}/bin
export PATH=\${ZOOBINDIR}:\$PATH
export ZOOCFGDIR=\${HADOOP_CONF_PREFIX}/zookeeper
export ZOO_LOG_DIR=\${HADOOP_DATA_PREFIX}/zookeeper

# Hadoop
export HADOOP_HOME=\${HADOOP_INSTALL_PREFIX}/$(get_name_var ${HADOOP_DL_URL})
export HADOOP_PREFIX=\${HADOOP_HOME}
export PATH=\${HADOOP_HOME}/bin:\${HADOOP_HOME}/sbin:\$PATH

export HADOOP_COMMON_LIB_NATIVE_DIR=\${HADOOP_HOME}/lib/native
# export HADOOP_OPTS="-Djava.library.path=\${HADOOP_COMMON_LIB_NATIVE_DIR}"
export LD_LIBRARY_PATH=\${HADOOP_COMMON_LIB_NATIVE_DIR}:\$LD_LIBRARY_PATH

export HADOOP_HDFS_HOME=\${HADOOP_HOME}
export HADOOP_YARN_HOME=\${HADOOP_HOME}
export HADOOP_CONF_DIR=\${HADOOP_CONF_PREFIX}/hadoop
export YARN_CONF_DIR=\${HADOOP_CONF_DIR}

# Hive
export HIVE_HOME=\${HADOOP_INSTALL_PREFIX}/$(get_name_var ${HIVE_DL_URL})
export PATH=\${HIVE_HOME}/bin:\$PATH
export HIVE_CONF_DIR=\${HADOOP_CONF_PREFIX}/hive

# Spark
export SPARK_HOME=\${HADOOP_INSTALL_PREFIX}/$(get_name_var ${SPARK_DL_URL})
export PATH=\$PATH:\${SPARK_HOME}/bin:\${SPARK_HOME}/sbin
export SPARK_CONF_DIR=\${HADOOP_CONF_PREFIX}/spark

# Hbase
export HBASE_HOME=\${HADOOP_INSTALL_PREFIX}/$(get_name_var ${HBASE_DL_URL})
export PATH=\${HBASE_HOME}/bin:\$PATH
export HBASE_CONF_DIR=\${HADOOP_CONF_PREFIX}/hbase
export HBASE_MANAGES_ZK=false

EOF

    chmod +x ${CONF_DIR}/env_hadoop.sh
    . ${CONF_DIR}/env_hadoop.sh

    if [[ "ture" == ${ADD_APP_USER} && -f /home/${APP_USER}/.bashrc ]]; then
        log_info "Add [${CONF_DIR}/env_hadoop.sh] into [/home/${APP_USER}/.bashrc]"
        cat >> /home/${APP_USER}/.bashrc <<- EOF

# Hadoop
if [ -f ${CONF_DIR}/env_hadoop.sh ]; then
    . ${CONF_DIR}/env_hadoop.sh
fi
EOF
    else
        log_warn "Not exists /home/${APP_USER}/.bashrc"
    fi

}

function config_hadoop() {
    log_info "Copy conf"
    # load ${CONF_DIR}/env_hadoop.sh
    cp -rf ${HADOOP_HOME}/etc/hadoop/* ${CONF_DIR}/hadoop
    cp -rf ${ZK_HOME}/conf/* ${CONF_DIR}/zookeeper
    cp -rf ${HIVE_HOME}/conf/* ${CONF_DIR}/hive
    cp -rf ${SPARK_HOME}/conf/* ${CONF_DIR}/spark
    cp -rf ${HBASE_HOME}/conf/* ${CONF_DIR}/hbase

    cp -rf ${BASE_DIR}/sample_config/hadoop/* ${CONF_DIR}/hadoop
    cp -rf ${BASE_DIR}/sample_config/hive/* ${CONF_DIR}/hive
    cp -rf ${BASE_DIR}/sample_config/hbase/* ${CONF_DIR}/hbase
    cp -f ${BASE_DIR}/sample_config/hive/hive-site.client.xml ${CONF_DIR}/spark/

    cp -rf ${BASE_DIR}/sample_config/sbin/* ${CONF_DIR}/
    chmod +x ${CONF_DIR}/*.sh

    replace_str ${CONF_DIR}/hadoop/core-site.xml "replace_hadoop_host" "${HADOOP_HOST}"
    replace_str ${CONF_DIR}/hadoop/core-site.xml "replace_hadoop_tmp_dir" "${DATA_DIR}/hadoop"
    replace_str ${CONF_DIR}/hadoop/yarn-site.xml "replace_hadoop_host" "${HADOOP_HOST}"

    replace_str ${CONF_DIR}/hbase/hbase-site.xml "replace_hadoop_host" "${HADOOP_HOST}"
    replace_str ${CONF_DIR}/hbase/hbase-site.xml "replace_hbase_rootdir" "${DATA_DIR}/hbase"

    # download jdbc driver
    jdbc_jar=$(download_file ${DRIVER_DL_URL} "${HIVE_HOME}/lib/")
    log_info "Driver [$jdbc_jar]"

    # zookeeper
    #echo 1 > ${ZOO_LOG_DIR}/myid
    if [[ -f ${CONF_DIR}/zookeeper/zoo.cfg ]]; then
        log_warn "Backup ${CONF_DIR}/zookeeper/zoo.cfg"
        mv -f ${CONF_DIR}/zookeeper/zoo.cfg ${CONF_DIR}/zookeeper/zoo.cfg.bak
    fi

    cat << EOF > ${CONF_DIR}/zookeeper/zoo.cfg

tickTime=2000
initLimit=10
syncLimit=5

clientPort=2181
dataDir=${DATA_DIR}/zookeeper

EOF

    set_owner ${CONF_DIR}
    set_owner ${DATA_DIR}

}

#=================================================
clear
check_sys
#check_root

# if [[ "ture" == ${ADD_APP_USER} ]]; then
#     add_appuser
# else
#     log_info "user: $(id -un)"
# fi

# download_install $ZK_DL_URL
# download_install $HADOOP_DL_URL
# download_install $HIVE_DL_URL
# download_install $SPARK_DL_URL
# download_install $HBASE_DL_URL

# set_env_hadoop

# config_hadoop
