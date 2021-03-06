#!/bin/bash
# include parse_yaml function
exec > >(tee trace.log) 2>&1
exec 2> >(tee error.log)

red=`tput setaf 1`
green=`tput setaf 2`
reset=`tput sgr0`

readonly base_file=`readlink -f "$0"`
readonly base_path=`dirname $base_file`
. "$base_path/tool/parse_yaml.sh"



# read yaml file
eval $(parse_yaml "$base_path/config/config.yaml" "config_")


# STEP 1: Setup host
hostname_conf(){
    hostnamectl set-hostname $config_host_hostname
}

pre_setup_install(){
    yum install sshpass -y
}

## setup ip interface
ip_conf(){
    echo "[${green} Notification ${reset}] Setup IP CONFIG " && sleep 2s

    var=$(echo $config_network_interface | tr " " "\n")
    for x in $var
    do
        echo "Setup interface $x"            
        temp_ip=config_network_"$x"_ip
        var_ip=${!temp_ip}
        #echo $var_ip       
        if [ ! -z $var_ip ]; then
            nmcli c modify $x ipv4.addresses $var_ip
        fi

        temp_gateway=config_network_"$x"_gateway
        var_gw=${!temp_gateway} 
        #echo $var_gw
        if [ ! -z $var_gw ]; then
            nmcli c modify $x ipv4.gateway $var_gw
        fi

        temp_dns=config_network_"$x"_dns
        var_dns=${!temp_dns} 
        #echo $var_dns
        if [ ! -z $var_dns ]; then
            nmcli c modify $x ipv4.dns $var_dns
        fi

        nmcli c modify $x ipv4.method manual
        nmcli con mod $x connection.autoconnect yes
    done    

    # echo "Setup IP ens160"
    # nmcli c modify ens160 ipv4.addresses 172.16.2.204/24
    # nmcli c modify ens160 ipv4.gateway 172.16.10.1
    # nmcli c modify ens160 ipv4.dns 8.8.8.8
    # nmcli c modify ens160 ipv4.method manual
    # nmcli con mod ens160 connection.autoconnect yes

    # echo "Setup IP ens192"
    # nmcli c modify ens192 ipv4.addresses 10.0.10.1/24
    # nmcli c modify ens192 ipv4.method manual
    # nmcli con mod ens192 connection.autoconnect yes

    service network restart
}

## setup selinux
selinux_conf(){    
    echo "[${green} Notification ${reset}] Setup SELinux" && sleep 2s
    setenforce 0
    sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/sysconfig/selinux
    sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
}

## setup ntp (chuyen sang chouny)
ntp_setup(){    
    echo "[${green} Notification ${reset}] Setup NTP Server" && sleep 2s

    yum install -y ntp ntpdate ntp-doc
    ntpdate 0.us.pool.ntp.org
    hwclock --systohc
    systemctl enable ntpd.service
    systemctl start ntpd.service
}

host_file_conf(){
    echo "[${green} Notification ${reset}] Setup Host File" && sleep 2s    
    ./tool/manage-etc-hosts.sh add $config_host_hostname $config_host_ip
    # echo "setup host file"
    # echo 172.16.2.204 cephaio >> /etc/hosts
}

user_cephdeploy_setup(){    
    echo "[${green} Notification ${reset}] Setup user Ceph deploy" && sleep 2s

    echo "Setup user Ceph Deploy"
    useradd -d /home/$config_ceph_userceph -m $config_ceph_userceph
    echo $config_ceph_password | passwd $config_ceph_userceph --stdin
    echo "$config_ceph_userceph ALL = (root) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/cephuser
    chmod 0440 /etc/sudoers.d/$config_ceph_userceph
    sed -i s'/Defaults requiretty/#Defaults requiretty'/g /etc/sudoers
}

# STEP 2: setup ssh server
ssh_key_conf(){
echo "[${green} Notification ${reset}] Setup SSH Server" && sleep 2s

echo -e "\n" | ssh-keygen -t rsa -N ""

echo -e "Host $config_host_hostname" >> ~/.ssh/config
echo -e "    Hostname $config_host_hostname" >> ~/.ssh/config
echo -e "    User cephuser" >> ~/.ssh/config

chmod 644 ~/.ssh/config

echo $'\n'StrictHostKeyChecking no >> ~/.ssh/config
echo $'\n'UserKnownHostsFile=/dev/null >> ~/.ssh/config
echo $'\n'LogLevel QUIET >> ~/.ssh/config

sshpass -p "$config_root_password" ssh-copy-id -o StrictHostKeyChecking=no root@${config_host_hostname}
}

# STEP 3: setup firewalld
firewalld_conf(){
    echo "[${green} Notification ${reset}] Setup Firewalld " && sleep 2s
    systemctl stop firewalld
    systemctl disable firewalld
}

# STEP 4: setup ceph cluster
pre_ceph_install(){
    echo "[${green} Notification ${reset}] Pre install Ceph" && sleep 2s

    yum install python-setuptools -y
    yum -y install epel-release
    yum install python-virtualenv -y
    yum install git -y
}

ceph_repo_conf(){
    echo "[${green} Notification ${reset}] Create cluster config Ceph" && sleep 2s
    cat config/ceph.repo > /etc/yum.repos.d/ceph.repo   
    yum update -y 
}

ceph_deploy_install(){
    echo "[${green} Notification ${reset}] Building ceph-deploy tool" && sleep 2s
    git clone https://github.com/ceph/ceph-deploy.git
    cd ceph-deploy/
    ./bootstrap
    cp virtualenv/bin/ceph-deploy /usr/bin/
}

ceph_deploy_install_repo(){
    echo "[${green} Notification ${reset}] Building ceph-deploy tool" && sleep 2s
    yum install ceph-deploy -y
    yum update ceph-deploy -y #2.0.1
}

ceph_setup(){
    echo "[${green} Notification ${reset}] Create cluster Ceph directory" && sleep 2s
    cd 
    mkdir cluster
    cd cluster/
}

ceph_lumi_install(){
    echo "[${green} Notification ${reset}] Installing Ceph Luminous" && sleep 2s

    cd ~/cluster/
    ceph-deploy new $config_host_hostname
    if [ ! -z $config_ceph_network_public ]; then
        echo "public network = $config_ceph_network_public" >> ~/cluster/ceph.conf
    fi

    if [ ! -z $config_ceph_network_cluster ]; then
        echo "cluster network = $config_ceph_network_cluster" >> ~/cluster/ceph.conf
    fi
    
    
    ceph-deploy install --release luminous $config_host_hostname
}

ceph_mon_setup(){
    echo "[${green} Notification ${reset}] Installing ceph monitor node" && sleep 2s

    cd ~/cluster/
    ceph-deploy mon create-initial
}

# STEP 5: setup ceph osd
zap_partition(){
    echo "[${green} Notification ${reset}] Preparing Ceph Disk" && sleep 2s

    cd ~/cluster/
    var=$(echo $config_ceph_disk | tr " " "\n")
    for x in $var
    do
        echo "Zapping disk $x"
        ceph-deploy disk zap $config_host_hostname $x
        
    done      
}

create_osd(){
    echo "[${green} Notification ${reset}] Creating OSD Disk" && sleep 2s
    cd ~/cluster/
    var=$(echo $config_ceph_disk | tr " " "\n")
    for x in $var
    do

        echo "Creating OSD $x"
        ceph-deploy osd create $config_host_hostname --data $x
        
    done
}

setup_admin_node(){
    echo "[${green} Notification ${reset}] Setup Admin node" && sleep 2s

    cd ~/cluster/
    ceph-deploy admin $config_host_hostname
    sudo chmod 644 /etc/ceph/ceph.client.admin.keyring
}

setup_ceph_mgr(){
    echo "[${green} Notification ${reset}] Setup Ceph mgr" && sleep 2s

    cd ~/cluster/
    ceph-deploy mgr create $config_host_hostname:ceph-mgr-1
}
# MAIN

pre_install(){
    hostname_conf

    pre_setup_install

    ip_conf

    selinux_conf

    ntp_setup

    host_file_conf

    user_cephdeploy_setup
}

setup_ssh_firewall(){
    ssh_key_conf

    firewalld_conf     
}

setup_ceph(){
    pre_ceph_install

    ceph_repo_conf

    #ceph_deploy_install
    ceph_deploy_install_repo

    ceph_setup

    ceph_lumi_install

    ceph_mon_setup

    zap_partition

    create_osd

    setup_admin_node

    setup_ceph_mgr
}

# RUN
echo "WELCOME TO SCRIPT INSTALL CEPH AIO LUMINOUS" && sleep 2s

echo "-------------------------------------------" && sleep 2s

echo "[${red} STEP 1 ${reset}] Pre instal Ceph ALL IN ONE, setup node"
pre_install
echo "[${red} END STEP 1 ${reset}]"

echo "[${red} STEP 2 ${reset}] Setup SSH server and setup firewall"
setup_ssh_firewall
echo "[${red} END STEP 2 ${reset}]"

echo "[${red} STEP 3 ${reset}] Setup Ceph Cluster"
setup_ceph
echo "[${red} END STEP 3 ${reset}]"


# zap_partition

#setup_admin_node

# setup_ceph_mgr
