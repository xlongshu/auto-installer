# common.sh
#! /bin/bash

PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

#=================================================
#	Description: Install common
#	System Required: CentOS/Debian/Ubuntu
#	Author: longshu
#=================================================


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
    echo -e "${INFO} $*"
    echo "[INFO ][$date]: $*" >> ${LOG_FILE}
}

function log_warn() {
    local date=`date "+%Y-%m-%d %H:%M:%S"`
    echo -e "${WARN} $*"
    echo "[WARN][$date]: $*" >> ${LOG_FILE}
}

function log_err() {
    local date=`date "+%Y-%m-%d %H:%M:%S"`
    echo -e "${ERROR} $*"
    echo "[ERROR][$date]: $*" >> ${LOG_FILE}
}

# Make sure only root can run our script, sudo su
function check_root() {
    [[ $EUID -ne 0 ]] && log_err "This script must be run as root." && exit 1
}

# Check OS
function check_sys() {
    if [ -f /etc/redhat-release ]; then
        release="centos"
    elif [ -f /etc/issue ]; then
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
    if [ -s /etc/selinux/config ] && grep 'SELINUX=enforcing' /etc/selinux/config; then
        sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
        setenforce 0
    fi
}

function add_appuser() {
    stty erase '^H' && echo -n "username:[${APP_USER}]" && read username
    stty erase '^H' && read -p "password:[123456]" password
    [[ -n ${username} ]] && APP_USER=${username}
    [[ -z ${password} ]] && password="123456"

    adduser -m -s /bin/bash ${APP_USER}
    echo ${password} | passwd --stdin ${APP_USER}
    log_info "created user: ${APP_USER}:${password}"
}

