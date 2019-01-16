#!/bin/bash
# install_hadoop.sh

PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

#=================================================
#	Description: Install Hadoop
#	System Required: CentOS/Debian/Ubuntu
#	Author: longshu
#=================================================


#=================================================
APP_USER="hadoop"
JAVA_VER=8 # 7, 8
DOWNLOAD_DIR=/data/download
INSTALL_PREFIX=/opt/app
DATA_DIR=/data/hadoop
CONF_DIR=/etc/hadoop
LOG_FILE=/tmp/install_hadoop.log
#=================================================


#=================================================
MIRRORS="https://mirrors.tuna.tsinghua.edu.cn/apache"
# http://mirrors.ustc.edu.cn/apache
# http://archive.apache.org/dist

ZK_DL_URL="$MIRRORS/zookeeper/zookeeper-3.4.10/zookeeper-3.4.10.tar.gz"
HADOOP_DL_URL="$MIRRORS/hadoop/common/hadoop-2.7.7/hadoop-2.7.7.tar.gz"
HBASE_DL_URL="$MIRRORS/hbase/1.2.7/hbase-1.2.7-bin.tar.gz"
HIVE_DL_URL="$MIRRORS/hive/hive-2.3.3/apache-hive-2.3.3-bin.tar.gz"

MYSQL_DRIVER_URL="http://central.maven.org/maven2/mysql/mysql-connector-java/5.1.40/mysql-connector-java-5.1.40.jar"
#=================================================


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
    local name_tar_gz="${dl_url##*/}" # hadoop-x.y.z.tar.gz
    name_ver="${name_tar_gz%%.tar.gz}" # hadoop-x.y.z
    # hbase-x.y.z-bin
    if [[ ${name_ver} == hbase* ]]; then
        name_ver="${name_ver%%-bin}"
    fi
    # apache-hive-x.y.z-bin
    if [[ ${name_ver} == apache-hive* ]]; then
        target="hive"
    else
        target="${name_ver%%-*}"
    fi

    if [[ ! -d ${INSTALL_PREFIX}/${target} ]]; then
        log_info "download ${dl_url}"
        [[ ! -f ${DOWNLOAD_DIR}/${name_tar_gz} ]] && wget -c -T45 --no-check-certificate -P ${DOWNLOAD_DIR} ${dl_url}

        log_info "tar -zxf ${name_tar_gz}"
        tar -zxf ${DOWNLOAD_DIR}/${name_tar_gz} -C ${INSTALL_PREFIX}

        log_info "mv ${name_ver}"
        mv ${INSTALL_PREFIX}/${name_ver} ${INSTALL_PREFIX}/${target}
        chgrp -R root ${INSTALL_PREFIX}/${target}
        chown -R ${APP_USER} ${INSTALL_PREFIX}/${target}
        log_info "install ${name_ver} into ${INSTALL_PREFIX}/${target}"
    else
        log_warn "$INSTALL_PREFIX/$target already exists."
    fi
}

function set_env() {
    mkdir -p ${DATA_DIR} ${DATA_DIR}/zookeeper ${DATA_DIR}/hbase
    mkdir -p ${CONF_DIR}/common ${CONF_DIR}/zookeeper ${CONF_DIR}/hbase ${CONF_DIR}/hive
    chown -R ${APP_USER} ${DATA_DIR}

    if [[ -f ${CONF_DIR}/hadoop_env.sh ]]; then
        log_warn "bak ${CONF_DIR}/hadoop_env.sh"
        mv -f ${CONF_DIR}/hadoop_env.sh ${CONF_DIR}/hadoop_env.sh.bak
    fi

    cat > ${CONF_DIR}/hadoop_env.sh <<- EOF
# hadoop_env.sh

export HADOOP_INSTALL_PREFIX=${INSTALL_PREFIX}
export HADOOP_DATA_PREFIX=${DATA_DIR}
export HADOOP_CONF_PREFIX=${CONF_DIR}

# ZooKeeper
export ZK_HOME=\${HADOOP_INSTALL_PREFIX}/zookeeper
export ZOOBINDIR=\${ZK_HOME}/bin
export PATH=\$PATH:\$ZOOBINDIR
export ZOOCFGDIR=\${HADOOP_CONF_PREFIX}/zookeeper
export ZOO_LOG_DIR=\${HADOOP_DATA_PREFIX}/zookeeper

# Hadoop
export HADOOP_HOME=\${HADOOP_INSTALL_PREFIX}/hadoop
export HADOOP_PREFIX=\$HADOOP_HOME
export PATH=\$PATH:\$HADOOP_HOME/bin:\$HADOOP_HOME/sbin

export HADOOP_HDFS_HOME=\$HADOOP_HOME
export HADOOP_YARN_HOME=\$HADOOP_HOME

export HADOOP_CONF_DIR=\${HADOOP_CONF_PREFIX}/common

# Hbase
export HBASE_HOME=\${HADOOP_INSTALL_PREFIX}/hbase
export PATH=\$PATH:\$HBASE_HOME/bin
export HBASE_CONF_DIR=\${HADOOP_CONF_PREFIX}/hbase

# Hive
export HIVE_HOME=\${HADOOP_INSTALL_PREFIX}/hive
export PATH=\$PATH:\$HIVE_HOME/bin
export HIVE_CONF_DIR=\${HADOOP_CONF_PREFIX}/hive

EOF

    chmod +x ${CONF_DIR}/hadoop_env.sh
    . ${CONF_DIR}/hadoop_env.sh

    if [[ -f /home/${APP_USER}/.bashrc ]]; then
        log_info "add [${CONF_DIR}/hadoop_env.sh] into [/home/${APP_USER}/.bashrc]"
        cat >> /home/${APP_USER}/.bashrc <<- EOF

# Hadoop
if [ -f ${CONF_DIR}/hadoop_env.sh ]; then
    . ${CONF_DIR}/hadoop_env.sh
fi
EOF
    else
        log_err "not exists /home/${APP_USER}/.bashrc"
    fi

}

function config_hadoop() {
    log_info "cp conf"
    cp -rf ${HADOOP_HOME}/etc/hadoop/* ${CONF_DIR}/common
    cp -rf ${ZK_HOME}/conf/* ${CONF_DIR}/zookeeper
    cp -rf ${HBASE_HOME}/conf/* ${CONF_DIR}/hbase
    cp -rf ${HIVE_HOME}/conf/* ${CONF_DIR}/hive

    # zookeeper
    echo 1 > ${ZOO_LOG_DIR}/myid
    if [[ -f ${CONF_DIR}/zookeeper/zoo.cfg ]]; then
        log_warn "bak ${CONF_DIR}/zookeeper/zoo.cfg"
        mv -f ${CONF_DIR}/zookeeper/zoo.cfg ${CONF_DIR}/zookeeper/zoo.cfg.bak
    fi

    cat > ${CONF_DIR}/zookeeper/zoo.cfg <<- EOF

clientPort=2181
dataDir=/data/hadoop/zookeeper

EOF

    chown -R ${APP_USER} ${CONF_DIR}

}

#=================================================
check_sys
check_root
