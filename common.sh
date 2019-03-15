# common.sh

#=================================================
#  Description: Common script
#  System Required: Linux/Unix
#  Author: LongShu
#=================================================


ADD_APP_USER="false"
APP_USER=${APP_USER:-"admin"}
#=================================================
text_red='\033[0;31m'
text_green='\033[0;32m'
text_yellow='\033[0;33m'
text_plain='\033[0m'
INFO="${text_green}[INFO ]:${text_plain}"
WARN="${text_yellow}[WARN ]:${text_plain}"
ERROR="${text_red}[ERROR]:${text_plain}"
LOG_FILE=${LOG_FILE:-"/tmp/auto_installer.log"}
echo "log file ${LOG_FILE}"
#=================================================

function log_info() {
    local date=`date "+%Y-%m-%d %H:%M:%S"`
    echo -e "${INFO} $*" 1>&2
    echo "[INFO ][$date]: $*" >> ${LOG_FILE}
}

function log_warn() {
    local date=`date "+%Y-%m-%d %H:%M:%S"`
    echo -e "${WARN} $*" 1>&2
    echo "[WARN][$date]: $*" >> ${LOG_FILE}
}

function log_err() {
    local date=`date "+%Y-%m-%d %H:%M:%S"`
    echo -e "${ERROR} $*" 1>&2
    echo "[ERROR][$date]: $*" >> ${LOG_FILE}
}

function replace_str() {
    local file_path=$(readlink -f "$1")
    local orig_str=$2
    local target_str=$3
    sed -i "s,${orig_str},${target_str}," ${file_path}
}

function get_path_file_name() {
    local full_path=$1
    local file_name="${full_path##*/}"
    echo ${file_name}
}

function get_archive_dir_name() {
    local full_path=$1
    local archive_name="${full_path##*/}"
    local dir_name="${archive_name%.tar.gz}"
    dir_name="${dir_name%.zip}"
    echo ${dir_name}
}

function get_name_var() {
    local full_path=$1
    local archive_name="${full_path##*/}"
    # apache-maven-x.y.z-bin.tar.gz, apache-maven-x.y.z-bin.zip
    local name_ver="${archive_name%.tar.gz}"
    name_ver="${name_ver%.zip}"

    # apache-maven-x.y.z-bin
    [[ ${name_ver} == apache-* ]] && name_ver=${name_ver:7}
    [[ ${name_ver} == *-bin ]] && name_ver=${name_ver:0:-4}

    echo ${name_ver}
}

# https://stackoverflow.com/questions/592620/how-to-check-if-a-program-exists-from-a-bash-script
function command_exists() {
    type "$1" &> /dev/null;
    # command -v "$1" > /dev/null 2>&1
}

function download_file() {
    local dl_url=$1
    local dl_dir=$(readlink -f "$2")

    local file_name=${3:-"${dl_url##*/}"}
    local file_path="${dl_dir}/${file_name}"

    if [[ -f "$file_path" ]]; then
        log_warn "Already exists file [$file_path] !"
        echo ${file_path}
        return 0
    fi

    log_info "Download ${file_name} ..."
    if command_exists wget; then
        wget -c -nv -t 2 -T 30 --no-check-certificate -P ${dl_dir} ${dl_url}
    else
        curl -L ${dl_url} -o ${file_path}
    fi
    echo ${file_path}
}

function unpack_file() {
    local file_path=$1
    local out_dir=$(readlink -f "$2")

    local dir_name=$(get_archive_dir_name ${file_path})
    local out_path="$(ls -d ${out_dir}/* | grep "${dir_name%-bin}*" | head -1)"

    if [[ -d ${out_path} ]]; then
        log_warn "Already exists dir [$out_path] !"
        echo ${out_path}
        return 0
    fi

    log_info "Unpacking ${file_path}"
    if [[ ${file_path} == *.zip ]]; then
        unzip -q ${file_path} -d ${out_dir}
    else
        tar -zxf ${file_path} -C ${out_dir}
    fi

    out_path=$(ls -d ${out_dir}/* | grep "${dir_name%-bin}*" | head -1)
    echo ${out_path}
}

# Make sure only root can run our script, sudo su
function check_root() {
    [[ $EUID -ne 0 ]] && log_err "This script must be run as root." && exit 1
}

# Check OS
function check_sys() {
    if [[ -f /etc/redhat-release ]]; then
        release="centos"
    elif [[ -f /etc/issue ]]; then
        if cat /etc/issue | grep -Eqi "debian"; then
            release="debian"
        elif cat /etc/issue | grep -Eqi "ubuntu"; then
            release="ubuntu"
        elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
            release="centos"
        fi
    elif cat /proc/version | grep -Eqi "debian"; then
        release="debian"
    elif cat /proc/version | grep -Eqi "ubuntu"; then
        release="ubuntu"
    elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
        release="centos"
    else
        log_err "Not support OS: $(uname -a)." && return
    fi
    log_info "sys: ${release}"
}

# Get version
function get_version() {
    if [[ -s /etc/redhat-release ]]; then
        grep -oE "[0-9.]+" /etc/redhat-release
    else
        grep -oE "[0-9.]+" /etc/issue
    fi
}

# CentOS version
function centos_version() {
    local version="`get_version`"
    local main_ver=${version%%.*}
    echo ${main_ver}
}

# Disable selinux
function disable_selinux() {
    if [[ -s /etc/selinux/config ]] && grep 'SELINUX=enforcing' /etc/selinux/config; then
        sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
        setenforce 0
    fi
}

function add_appuser() {
    stty erase '^H' && echo -n "username:[${APP_USER}]" && read username
    stty erase '^H' && read -p "password:[123456]" password
    [[ -n ${username} ]] && APP_USER=${username}
    [[ -z ${password} ]] && password="123456"

    useradd -m -s /bin/bash ${APP_USER}
    echo ${password} | passwd --stdin ${APP_USER}
    log_info "created user: ${APP_USER}:${password}"
}

function set_owner() {
    target=$1

    if [[ "ture" == ${ADD_APP_USER} ]]; then
        owner_user=${APP_USER}
    else
        owner_user=$(id -un)
    fi
    log_info "Set Owner ${owner_user} -> ${target} ..."
    chown -R ${owner_user} ${target}
}
