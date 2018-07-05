# Script cài đặt Ceph AIO Luminous
---
## Tài nguyên
```
CPU         2 core
RAM         4 GB

Disk        sba: os
            sbd,sdc: 2 disk osd

Network     ens160: 1 replicate data
            ens192: 1 access ceph
```
## Cách sử dụng
> Script cần được chạy bằng user `root`
### 1. Thiết lập File config của script
> File cấu hình mặc định tại: `<project>/src/config/config.yaml`

__Cấu trúc__

```
host:
  hostname: <ten-host> 
  ip: <ip-host>
network:
  interface: <list-interface>
  <ten-interface>:  
    ip: <ip-interface>/<netmask-num>
    gateway: <gateway-ip>
    dns: <dns>
  <ten-interface>:
    ....
ceph:
  userceph: cephuser
  password: <passwd>
  disk: <list-device-disk>
  network:
    public: <ip-interface>/<netmask-num>
    cluster: <ip-interface>/<netmask-num>
root:
  password: <passwd>

VD:

host:
  hostname: cephaio
  ip: 172.16.4.204
network:
  interface: ens160 ens192 
  ens160:
    ip: 172.16.4.204/24
    gateway: 172.16.10.1
    dns: 8.8.8.8
  ens192:
    ip: 10.0.10.1/24
ceph:
  userceph: cephuser
  password: 123456
  disk: /dev/sdb /dev/sdc
  network:
    public: 172.16.4.0/24
    cluster: 10.0.10.0/24
root:
  password: 123456a@
```

Lưu ý: 
- Khai báo đầu đủ các mục host, network, ceph, root. Thiếu có thể gây lỗi
- Đường dẫn disk phải là `<media>/<disk>`. VD: `/dev/sdb`
- Cần có netmark-num sau các ip (như ví dụ)
- Cần liệt kế số interface và mô tả interface. Hỗ trợ các tham số cấu hình ip, gateway, dns 
- Cần cung cấp passwd root để thực thi 1 số tính năng 

### 2. Cấu hình phiên bản Ceph (Lumi)
> File cấu hình mặc định tại: `<project>/src/config/ceph.repo`
```
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
```

### 3. Chạy Script
Thiết lập quyển thực thi
```
chmod +x <project>/src/install.sh
chmod +x <project>/src/tool/*
```

Chạy script
```
bash ./<project>/src/install.sh
```

### Trace log
> Log của script sẽ hiện thị ra màn hình và file log.

LOG FILE BAO GỒM:
- `trace.log`: Log chung của script
- `error.log`: Log error của script




