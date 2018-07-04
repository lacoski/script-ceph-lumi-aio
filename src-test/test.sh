#!/bin/sh

# include parse_yaml function
readonly base_file=`readlink -f "$0"`
readonly base_path=`dirname $base_file`
. "$base_path/parse_yaml.sh"

# read yaml file
eval $(parse_yaml "$base_path/config.yaml" "config_")

ip_conf(){
    var=$(echo $config_network_interface | tr " " "\n")

    for x in $var
    do            
        temp_ip=config_network_"$x"_ip
        var_ip=${!temp_ip}
        #echo $var_ip       
        if [ ! -z $var_ip ]; then
            echo "nmcli c modify $x ipv4.addresses $var_ip"
        fi

        temp_gateway=config_network_"$x"_gateway
        var_gw=${!temp_gateway} 
        #echo $var_gw
        if [ ! -z $var_gw ]; then
            echo "nmcli c modify $x ipv4.gateway $var_gw"
        fi

        temp_dns=config_network_"$x"_dns
        var_dns=${!temp_dns} 
        #echo $var_dns
        if [ ! -z $var_dns ]; then
            echo "nmcli c modify $x ipv4.dns $var_dns"
        fi

        echo "nmcli c modify $x ipv4.method manual"
        echo "nmcli con mod $x connection.autoconnect yes"
    done    
    #service network restart
}

user_cephdeploy_setup(){
    echo "setup user Ceph Deploy"
    useradd -d /home/$config_ceph_userceph -m $config_ceph_userceph
    echo $config_ceph_password | passwd $config_ceph_userceph --stdin
    echo "$config_ceph_userceph ALL = (root) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/cephuser
    chmod 0440 /etc/sudoers.d/$config_ceph_userceph
    sed -i s'/Defaults requiretty/#Defaults requiretty'/g /etc/sudoers
}

ssh_key_conf(){
echo -e "\n" | ssh-keygen -t rsa -N ""

cat > ~/.ssh/config <<EOF
Host ceph-aio
        Hostname ceph-aio
        User cephuser
EOF

chmod 644 ~/.ssh/config
echo 0435626533a@ | ssh-copy-id cephaio
}

ssh_key_conf