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
public_ip=$local_ip
public_hostname=sprout-0.example.com
etcd_cluster=$etcd_ip
EOF


# Create /etc/chronos/chronos.conf.
mkdir -p /etc/chronos
cat > /etc/chronos/chronos.conf << EOF
[http]
bind-address = $(hostname -I)
bind-port = 7253
threads = 50
                                 
[logging]
folder = /var/log/chronos
level = 2
                                                                                                   
[alarms]
enabled = true
                                                                                                                                                   
[exceptions]
max_ttl = 600
EOF
# Now install the software.
# "-o DPkg::options::=--force-confnew" works around https://github.com/Metaswitch/clearwater-infrastructure/issues/186.
DEBIAN_FRONTEND=noninteractive apt-get install sprout --yes --force-yes -o DPkg::options::=--force-confnew
DEBIAN_FRONTEND=noninteractive apt-get install clearwater-management --yes --force-yes

# Update DNS
retries=0
while ! { nsupdate -y "example.com:8r6SIIX/cWE6b0Pe8l2bnc/v5vYbMSYvj+jQPP4bWe+CXzOpojJGrXI7iiustDQdWtBHUpWxweiHDWvLIp6/zw==" -v << EOF
server ${dns_ip}
update add sprout-0.example.com. 30 A $(hostname- I)
update add sprout.example.com. 30 A $(hosname -I)
send
EOF
} && [ $retries -lt 10 ]
do
  retries=$((retries + 1))
  echo 'nsupdate failed - retrying (retry '$retries')...'
  sleep 5
done

