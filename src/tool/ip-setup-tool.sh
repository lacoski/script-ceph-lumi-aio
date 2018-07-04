#!/bin/bash
while getopts "i:g:d:h:" option
    do
    case "${option}"
        in
            i) 
                # nmcli c modify ens160 ipv4.addresses 172.16.2.204/24
                echo "$OPTARG"
            ;;
            g) 
                # nmcli c modify ens160 ipv4.gateway 172.16.10.1
                echo "$OPTARG"
            ;;
            d) 
                # nmcli c modify ens160 ipv4.dns 8.8.8.8
                echo "$OPTARG"
            ;;
            h) 
                # nmcli c modify ens160 ipv4.addresses 172.16.2.204/24
                echo "$OPTARG"
            ;;
            ?)
            echo "script usage: $(basename $0) [-l] [-h] [-a somevalue]" >&2
            exit 1
            ;;
    esac
done

#nmcli c modify ens160 ipv4.method manual
#nmcli con mod ens160 connection.autoconnect yes