#!/bin/bash

exec > >(tee -a /var/log/clearwater-cloudify.log) 2>&1

# Configure the APT software source.
echo 'deb http://repo.cw-ngv.com/stable binary/' > /etc/apt/sources.list.d/clearwater.list
curl -L http://repo.cw-ngv.com/repo_key | apt-key add -
apt-get update

# Configure /etc/clearwater/local_config.
mkdir -p /etc/clearwater
etcd_ip=$(hostname -I)
cat > /etc/clearwater/local_config << EOF
local_ip=$(hostname -I)
public_ip=
public_hostname=homestead-0.example.com
etcd_cluster=$etcd_ip
EOF

# Now install the software.
# "-o DPkg::options::=--force-confnew" works around https://github.com/Metaswitch/clearwater-infrastructure/issues/186.
DEBIAN_FRONTEND=noninteractive apt-get install clearwater-cassandra --yes --force-yes -o DPkg::options::=--force-confnew
DEBIAN_FRONTEND=noninteractive apt-get install homestead homestead-prov --yes --force-yes -o DPkg::options::=--force-confnew
DEBIAN_FRONTEND=noninteractive apt-get install clearwater-management --yes --force-yes
sudo /usr/share/clearwater/clearwater-config-manager/scripts/apply_shared_config

# Update DNS
retries=0
while ! { nsupdate -y "example.com:8r6SIIX/cWE6b0Pe8l2bnc/v5vYbMSYvj+jQPP4bWe+CXzOpojJGrXI7iiustDQdWtBHUpWxweiHDWvLIp6/zw==" -v << EOF
server ${dns_ip}
update add homestead-0.example.com. 30 A $(hostname- I)
update add hs.example.com. 30 A $(hosname -I)
send
EOF
} && [ $retries -lt 10 ]
do
  retries=$((retries + 1))
  echo 'nsupdate failed - retrying (retry '$retries')...'
  sleep 5
done

