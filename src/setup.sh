#!/bin/bash

hostnamectl set-hostname cephaio

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