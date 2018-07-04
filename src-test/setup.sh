#!/bin/bash

echo "setup hostname"
hostnamectl set-hostname cephaio

echo "setup IP"
echo "Setup IP ens160"
nmcli c modify ens160 ipv4.addresses 172.16.2.204/24
nmcli c modify ens160 ipv4.gateway 172.16.10.1
nmcli c modify ens160 ipv4.dns 8.8.8.8
nmcli c modify ens160 ipv4.method manual
nmcli con mod ens160 connection.autoconnect yes
echo "Setup IP ens192"
nmcli c modify ens192 ipv4.addresses 10.0.10.1/24
nmcli c modify ens192 ipv4.method manual
nmcli con mod ens192 connection.autoconnect yes

service network restart

sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/sysconfig/selinux
sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config

echo "setup user Ceph Deploy"
useradd -d /home/cephuser -m cephuser
echo 123456 | passwd cephuser --stdin
echo "cephuser ALL = (root) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/cephuser
chmod 0440 /etc/sudoers.d/cephuser
sed -i s'/Defaults requiretty/#Defaults requiretty'/g /etc/sudoers

# echo "setup NTP"

# yum -y install chrony
# ntpdate 0.us.pool.ntp.org
# hwclock --systohc
# systemctl enable ntpd.service
# systemctl start ntpd.service

echo "setup host file"
echo 172.16.2.204 cephaio >> /etc/hosts


# gen key ssh
echo -e "\n" | ssh-keygen -t rsa -N ""

cat > ~/.ssh/config <<'EOF'
Host ceph-aio
        Hostname ceph-aio
        User cephuser
EOF

chmod 644 ~/.ssh/config

echo 0435626533a@ | ssh-copy-id cephaio

# Cấu hình Firewalld

systemctl stop firewalld
systemctl disable firewalld

# Thiết lập Ceph Cluster
yum install python-setuptools -y
yum -y install epel-release
yum install python-virtualenv -y


cat > /etc/yum.repos.d/ceph.repo <<'EOF'
[Ceph]
name=Ceph packages for $basearch
baseurl=http://download.ceph.com/rpm-luminous/el7/$basearch
enabled=1
gpgcheck=1
type=rpm-md
gpgkey=https://download.ceph.com/keys/release.asc
priority=1

[Ceph-noarch]
name=Ceph noarch packages
baseurl=http://download.ceph.com/rpm-luminous/el7/noarch
enabled=1
gpgcheck=1
type=rpm-md
gpgkey=https://download.ceph.com/keys/release.asc
priority=1

[ceph-source]
name=Ceph source packages
baseurl=http://download.ceph.com/rpm-luminous/el7/SRPMS
enabled=1
gpgcheck=1
type=rpm-md
gpgkey=https://download.ceph.com/keys/release.asc
priority=1
EOF

yum update -y


# Cài đặt ceph-deploy tool từ git
yum install git -y

git clone https://github.com/ceph/ceph-deploy.git

cd ceph-deploy/
./bootstrap

cp virtualenv/bin/ceph-deploy /usr/bin/


# Tạo mới Ceph Cluster config
cd 
mkdir cluster
cd cluster/

ceph-deploy new cephaio

# Cài đặt Ceph trên Ceph AIO
ceph-deploy install --release luminous cephaio


# Thiết lập ceph mon

ceph-deploy mon create-initial

# Thiết lập OSD

ceph-deploy disk list cephaio

# Xóa partition tables trên tất cả node với zap option

ceph-deploy disk zap cephaio /dev/sdb
ceph-deploy disk zap cephaio /dev/sdc
ceph-deploy disk zap cephaio /dev/sdd

# Tạo mới OSD

ceph-deploy osd create cephaio --data /dev/sdb
ceph-deploy osd create cephaio --data /dev/sdc
ceph-deploy osd create cephaio --data /dev/sdd

# Kiểm tra tại OSD node

# Thiết lập management-key trên node

ceph-deploy admin cephaio

# Thiết lập quyền truy cập file

sudo chmod 644 /etc/ceph/ceph.client.admin.keyring

# Triển khai Ceph MGR nodes

ceph-deploy mgr create cephaio:ceph-mgr-1



