#!/bin/bash
# install_nginx.sh

PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

#=================================================
#	Description: Install Nginx
#	System Required: CentOS/Debian/Ubuntu
#	Author: longshu
#=================================================


#=================================================
LOG_FILE="/tmp/nginx_install.log"
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

function install_nginx() {
    if [[ "$release" == "centos" ]]; then
        if [[ -f /etc/yum.repos.d/nginx.repo ]]; then
            log_warn "bak /etc/yum.repos.d/nginx.repo"
            mv -f /etc/yum.repos.d/nginx.repo /etc/yum.repos.d/nginx.repo.bak
        fi

        cat > /etc/yum.repos.d/nginx.repo <<- EOF
# nginx.repo

[nginx-stable]
name=nginx stable repo
baseurl=http://nginx.org/packages/centos/\$releasever/\$basearch/
gpgcheck=1
enabled=1
gpgkey=https://nginx.org/keys/nginx_signing.key

[nginx-mainline]
name=nginx mainline repo
baseurl=http://nginx.org/packages/mainline/centos/\$releasever/\$basearch/
gpgcheck=1
enabled=0
gpgkey=https://nginx.org/keys/nginx_signing.key

EOF

        yum install yum-utils
        yum update
        yum install nginx -y
    else
        sudo apt-get install software-properties-common
        sudo add-apt-repository ppa:nginx/stable

        apt-get update
        apt-get install nginx -y
    fi
}


check_sys
check_root
install_nginx
