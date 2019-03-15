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
# http://archive.apache.org/dist

ZK_DL_URL="$MIRRORS/zookeeper/zookeeper-3.4.13/zookeeper-3.4.13.tar.gz"
HADOOP_DL_URL="$MIRRORS/hadoop/common/hadoop-2.7.7/hadoop-2.7.7.tar.gz"
HBASE_DL_URL="$MIRRORS/hbase/1.4.9/hbase-1.4.9-bin.tar.gz"
HIVE_DL_URL="$MIRRORS/hive/hive-1.2.2/apache-hive-1.2.2-bin.tar.gz"

# http://central.maven.org/maven2/mysql/mysql-connector-java/5.1.40/mysql-connector-java-5.1.40.jar
# mysql: com.mysql.jdbc.Driver, jdbc:mysql://localhost:3306/hive?createDatabaseIfNotExist=true&amp;useSSL=false
# sqlite: org.sqlite.JDBC, jdbc:sqlite:${CONF_DIR}/hive.sqlite
DRIVER_DL_URL="http://central.maven.org/maven2/org/xerial/sqlite-jdbc/3.15.1/sqlite-jdbc-3.15.1.jar"
#=================================================

CUR_DIR=$(pwd)
BASE_DIR="\$(cd "$(dirname "$0")"; pwd)"
cd ${BASE_DIR}

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

function set_hadoop_env() {
    mkdir -p ${DATA_DIR} ${DATA_DIR}/zookeeper ${DATA_DIR}/hadoop ${DATA_DIR}/hbase
    mkdir -p ${CONF_DIR}/hadoop ${CONF_DIR}/zookeeper ${CONF_DIR}/hbase ${CONF_DIR}/hive

    if [[ -f ${CONF_DIR}/hadoop_env.sh ]]; then
        log_warn "Backup [${CONF_DIR}/hadoop_env.sh] !"
        mv -f ${CONF_DIR}/hadoop_env.sh ${CONF_DIR}/hadoop_env.sh.bak
    fi

    log_info "Generate [${CONF_DIR}/hadoop_env.sh] ..."
    cat << EOF > ${CONF_DIR}/hadoop_env.sh
# hadoop_env.sh

export HADOOP_INSTALL_PREFIX=${INSTALL_PREFIX}
export HADOOP_DATA_PREFIX=${DATA_DIR}
export HADOOP_CONF_PREFIX=${CONF_DIR}

# ZooKeeper
export ZK_HOME=\${HADOOP_INSTALL_PREFIX}/$(get_name_var ${ZK_DL_URL})
export ZOOBINDIR=\${ZK_HOME}/bin
export PATH=\$PATH:\$ZOOBINDIR
export ZOOCFGDIR=\${HADOOP_CONF_PREFIX}/zookeeper
export ZOO_LOG_DIR=\${HADOOP_DATA_PREFIX}/zookeeper

# Hadoop
export HADOOP_HOME=\${HADOOP_INSTALL_PREFIX}/$(get_name_var ${HADOOP_DL_URL})
export HADOOP_PREFIX=\$HADOOP_HOME
export PATH=\$PATH:\$HADOOP_HOME/bin:\$HADOOP_HOME/sbin

export HADOOP_HDFS_HOME=\$HADOOP_HOME
export HADOOP_YARN_HOME=\$HADOOP_HOME

export HADOOP_CONF_DIR=\${HADOOP_CONF_PREFIX}/hadoop

# Hbase
export HBASE_HOME=\${HADOOP_INSTALL_PREFIX}/$(get_name_var ${HBASE_DL_URL})
export PATH=\$PATH:\$HBASE_HOME/bin
export HBASE_CONF_DIR=\${HADOOP_CONF_PREFIX}/hbase
export HBASE_MANAGES_ZK=false

# Hive
export HIVE_HOME=\${HADOOP_INSTALL_PREFIX}/$(get_name_var ${HIVE_DL_URL})
export PATH=\$PATH:\$HIVE_HOME/bin
export HIVE_CONF_DIR=\${HADOOP_CONF_PREFIX}/hive

EOF

    chmod +x ${CONF_DIR}/hadoop_env.sh
    . ${CONF_DIR}/hadoop_env.sh

    if [[ "ture" == ${ADD_APP_USER} && -f /home/${APP_USER}/.bashrc ]]; then
        log_info "Add [${CONF_DIR}/hadoop_env.sh] into [/home/${APP_USER}/.bashrc]"
        cat >> /home/${APP_USER}/.bashrc <<- EOF

# Hadoop
if [ -f ${CONF_DIR}/hadoop_env.sh ]; then
    . ${CONF_DIR}/hadoop_env.sh
fi
EOF
    else
        log_warn "Not exists /home/${APP_USER}/.bashrc"
    fi

}

function config_hadoop() {
    log_info "Copy conf"
    # load ${CONF_DIR}/hadoop_env.sh
    cp -rf ${HADOOP_HOME}/etc/hadoop/* ${CONF_DIR}/hadoop
    cp -rf ${ZK_HOME}/conf/* ${CONF_DIR}/zookeeper
    cp -rf ${HBASE_HOME}/conf/* ${CONF_DIR}/hbase
    cp -rf ${HIVE_HOME}/conf/* ${CONF_DIR}/hive

    cp -rf ${BASE_DIR}/sample_config/hadoop/* ${CONF_DIR}/hadoop
    cp -rf ${BASE_DIR}/sample_config/hbase/* ${CONF_DIR}/hbase
    cp -rf ${BASE_DIR}/sample_config/hive/* ${CONF_DIR}/hive

    replace_str ${CONF_DIR}/hadoop/core-site.xml "replace_hadoop_host" "${HADOOP_HOST}"
    replace_str ${CONF_DIR}/hadoop/core-site.xml "replace_hadoop_tmp_dir" "${DATA_DIR}/hadoop"
    replace_str ${CONF_DIR}/hadoop/yarn-site.xml "replace_hadoop_host" "${HADOOP_HOST}"

    replace_str ${CONF_DIR}/hbase/hbase-site.xml "replace_hadoop_host" "${HADOOP_HOST}"
    replace_str ${CONF_DIR}/hbase/hbase-site.xml "replace_hbase_rootdir" "${DATA_DIR}/hbase"

    replace_str ${CONF_DIR}/hbase/hbase-site.xml "replace_hive_jdbc_url" "jdbc:sqlite:${CONF_DIR}/hive.sqlite"
    replace_str ${CONF_DIR}/hbase/hbase-site.xml "replace_hive_jdbc_driver" "org.sqlite.JDBC"
    # download jdbc driver
    jdbc_jar=$(download_file ${DRIVER_DL_URL} "${HBASE_HOME}/lib/")
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
#check_sys
#check_root
