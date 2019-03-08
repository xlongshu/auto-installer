#!/bin/bash

# install_zk_fake_cluster.sh

#=================================================
#   Description: Install ZooKeeper Fake Cluster
#   System Required: Linux/Unix
#   Author: LongShu
#=================================================

#=================================================
ZK_INSTALL_PREFIX=${ZK_INSTALL_PREFIX:-"$HOME/zkCluster"}
ZK_NODE_NAME='znode' # znode1,znode2,znode3
ZK_HOST='localhost' # 127.0.0.1, 192.168.56.1
BASE_CLIENT_PORT=2280 # 2281,2282,2283
BASE_SERVER_PORT=2880
#=================================================

function log_print() {
    local level="$1"
    local msg="$2"

    case ${level} in
        error | E) echo -e "\033[0;31m${msg}\033[0m" ;;
        warn | W) echo -e "\033[0;33m${msg}\033[0m" ;;
        info | I) echo -e "\033[0;32m${msg}\033[0m" ;;
        *) echo "$*" ;;
    esac
}

function pre_install() {
    log_print I "Process ${zk_tar_gz_apth} ..."

    mkdir -p ${ZK_INSTALL_PREFIX}

    # download file
    if [[ "$zk_tar_gz_apth" =~ "http" ]]; then
        log_print I "Download $zk_tar_gz ..."

        if [[ ! -e "${ZK_INSTALL_PREFIX}/${zk_tar_gz}" ]]; then
            curl ${zk_tar_gz_apth} -o ${ZK_INSTALL_PREFIX}/${zk_tar_gz}
        else
            log_print W "Already exists file [${ZK_INSTALL_PREFIX}/${zk_tar_gz}] !"
        fi

        zk_tar_gz_apth=${ZK_INSTALL_PREFIX}/${zk_tar_gz}
    fi

    log_print I "Generate zkCluster.sh ..."

    cat << EOF > ${ZK_INSTALL_PREFIX}/zkCluster.sh
#!/bin/bash
# zkCluster.sh

CUR_DIR=\$(pwd)
BASE_DIR="\$(cd "\$(dirname "\$0")"; pwd)"
cd \${BASE_DIR}

export ZK_NODE_NAME='${ZK_NODE_NAME}'
export ZK_HOME=\$(readlink -f "${zk_name_ver}")
echo "ZK_HOME=\${ZK_HOME}"
export ZOOBINDIR=\${ZK_HOME}/bin
export PATH=\${ZOOBINDIR}:\$PATH

if [[ "\$(uname)" =~ "MINGW" ]]; then
    echo "Load \${ZOOBINDIR}/zkEnv.sh"
    . "\${ZOOBINDIR}/zkEnv.sh"
    export CLASSPATH=\$(cygpath -wp "\${CLASSPATH}")
fi

if [[ \$# -lt 2 ]]; then
    echo "Usage: \${0##*/} [all|node_name,...] {test|start|start-foreground|stop|restart|status|upgrade|print-cmd}"
    echo "Example: \${0##*/} all test"
    echo "         \${0##*/} znode1,znode2 test"
    exit 0
fi

NODE_NAME="\${1//,/ }"
ZK_ACTION=\$2
echo "\${ZK_ACTION} \${NODE_NAME}"
ZK_NODES="\$(ls -d ${ZK_NODE_NAME}*)"
[[ "all" != "\${NODE_NAME}" ]] && ZK_NODES=\${NODE_NAME}

for zn in \${ZK_NODES}; do
    echo ">>> \${zn} >>>"
    [[ ! -d "\${zn}" ]] && echo "Not exist [\${zn}] name!" && exit 0
    [[ "test" = "\${ZK_ACTION}" ]] && ZK_ACTION=print-cmd
    export ZOOCFGDIR=\$(readlink -f "\${zn}/")
    #export ZOO_LOG_DIR=\$(readlink -f "\${zn}")
    cd \${zn} && zkServer.sh \${ZK_ACTION}
    cd \${BASE_DIR}
    echo "<<< \${zn} <<<"
    echo "======================================="
    sleep 1
done

EOF


    log_print I "Generate zkClient.sh ..."

    cat << EOF > ${ZK_INSTALL_PREFIX}/zkClient.sh
#!/bin/bash
# zkClient.sh

cd "\$(dirname "\$0")"

if [[ \$# -lt 1 ]]; then
    echo "Usage: \${0##*/} <host:port|host:port,host:port...>"
    echo "Example: \${0##*/} localhost:2281,localhost:2282,localhost:2283"
    echo "         \${0##*/} localhost:2281"
    exit 0
fi

export ZK_HOME=\$(readlink -f "${zk_name_ver}")
echo "ZK_HOME=\${ZK_HOME}"
export ZOOBINDIR=\${ZK_HOME}/bin
export PATH=\${ZOOBINDIR}:\$PATH

if [[ "\$(uname)" =~ "MINGW" ]]; then
    echo "Load \${ZOOBINDIR}/zkEnv.sh"
    . "\${ZOOBINDIR}/zkEnv.sh"
    export CLASSPATH=\$(cygpath -wp "\${CLASSPATH}")
fi

NODE_URL=\$1
echo "NODE_URL=\${NODE_URL}"
sleep 1
zkCli.sh -server "\$NODE_URL"

EOF

    chmod +x ${ZK_INSTALL_PREFIX}/*.sh

}

function install_zk() {
    log_print I "Install ${zk_name_ver} to [${ZK_INSTALL_PREFIX}] ..."
    ZK_INSTALL_HOME="${ZK_INSTALL_PREFIX}/${zk_name_ver}"

    # Copy directory
    if [[ -d "$zk_tar_gz_apth" && ! -e "$ZK_INSTALL_HOME" ]]; then
        log_print I "Copy $zk_tar_gz_apth to [$ZK_INSTALL_HOME]..."
        cp -r ${zk_tar_gz_apth} ${ZK_INSTALL_HOME}
    # Unpack file
    elif [[ ! -e ${ZK_INSTALL_HOME} ]]; then
        log_print I "Unpacking ${zk_tar_gz} ..."
        [[ ! -f ${zk_tar_gz_apth} ]] && log_print E "Not a file or exist [$zk_tar_gz]!" && exit 0
        tar -zxf ${zk_tar_gz_apth} -C ${ZK_INSTALL_PREFIX}
    else
        log_print W "Already exists [$ZK_INSTALL_HOME] !"
    fi


    log_print I "Create zookeeper node ..."
    for i in {1..3}; do
        zk_node=${ZK_INSTALL_PREFIX}/${ZK_NODE_NAME}${i}
        client_port=$[ BASE_CLIENT_PORT + ${i} ]
        log_print "Config ${zk_node} ${ZK_HOST}:${client_port}"
        mkdir -p ${zk_node}/data
        echo ${i} > ${zk_node}/data/myid

        cp -rf ${ZK_INSTALL_PREFIX}/${zk_name_ver}/conf/* ${zk_node}/
        cat << EOF > ${zk_node}/zoo.cfg

tickTime=2000
initLimit=10
syncLimit=5

clientPort=${client_port}
dataDir=./data
# cluster
server.1=${ZK_HOST}:$[ BASE_SERVER_PORT + 1 ]:$[ BASE_SERVER_PORT + 1001 ]
server.2=${ZK_HOST}:$[ BASE_SERVER_PORT + 2 ]:$[ BASE_SERVER_PORT + 1002 ]
server.3=${ZK_HOST}:$[ BASE_SERVER_PORT + 3 ]:$[ BASE_SERVER_PORT + 1003 ]

EOF

    done

    echo "======================================="
    ${ZK_INSTALL_PREFIX}/zkCluster.sh
}

#=================================================

# 'local tar.gz', 'local path', 'http url'
zk_tar_gz_apth=$1
zk_tar_gz="${zk_tar_gz_apth##*/}"
zk_name_ver="${zk_tar_gz%%.tar.gz}"

if [[ $# -lt 1 ]]; then
    log_print E "Usage: $(basename "$0") </youpath/zookeeper-x.y.z.tar.gz> [/youpath/exist_zk_prefix]"
    log_print W "zk_tar_gz_apth 'local tar.gz', 'local path', 'http url'"
    log_print W "Example: $(basename "$0") https://mirrors.aliyun.com/apache/zookeeper/stable/zookeeper-3.4.13.tar.gz"
    exit 0
fi

if [[ -d "$2" ]]; then
    ZK_INSTALL_PREFIX=$(readlink -f "$2")
elif [[ "x$2" != "x" ]]; then
    log_print W "Not exist [$(readlink -f "$2")]!"
fi
ZK_INSTALL_PREFIX=$(readlink -f "${ZK_INSTALL_PREFIX}")


pre_install
install_zk
