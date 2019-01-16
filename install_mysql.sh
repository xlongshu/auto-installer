#!/bin/bash
# install_mysql.sh

PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

#=================================================
#	Description: Install MySQL
#	System Required: CentOS/Debian/Ubuntu
#	Author: longshu
#=================================================


#=================================================
MYSQL_VERSION="5.7"
LOG_FILE="/tmp/install_mysql.log"
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


function install_mysql() {
    stty erase '^H' && echo -n "version:[${MYSQL_VERSION}]" && read version
    [[ -n ${version} ]] && MYSQL_VERSION=${version}
    log_info "install ${MYSQL_VERSION}"

}

#=================================================
check_sys
check_root
install_mysql
