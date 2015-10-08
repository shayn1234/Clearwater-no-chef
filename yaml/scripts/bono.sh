#!/bin/bash 

ctx logger info "In Bono ${public_ip}   ${dns_ip}   "

echo "In Bono ${public_ip}   ${dns_ip}   " > /home/ubuntu/dnsfile

sudo exec > >(sudo tee -a /var/log/clearwater-cloudify.log) 2>&1


# Configure the APT software source.
sudo echo 'deb http://repo.cw-ngv.com/stable binary/' > /etc/apt/sources.list.d/clearwater.list
sudo curl -L http://repo.cw-ngv.com/repo_key | apt-key add -
sudo apt-get update

# Configure /etc/clearwater/local_config.
sudo mkdir -p /etc/clearwater
etcd_ip=$(hostname -I)
sudo cat > /etc/clearwater/local_config << EOF
local_ip=$(hostname -I)
public_ip1=$public_ip
public_hostname=bono-0.example.com
etcd_cluster=$etcd_ip
EOF

# Now install the software.
# "-o DPkg::options::=--force-confnew" works around https://github.com/Metaswitch/clearwater-infrastructure/issues/186.
sudo DEBIAN_FRONTEND=noninteractive apt-get install bono --yes --force-yes -o DPkg::options::=--force-confnew
sudo DEBIAN_FRONTEND=noninteractive apt-get install clearwater-config-manager --yes --force-yes

# Update DNS
retries=0
while ! { sudo nsupdate -y "example.com:8r6SIIX/cWE6b0Pe8l2bnc/v5vYbMSYvj+jQPP4bWe+CXzOpojJGrXI7iiustDQdWtBHUpWxweiHDWvLIp6/zw==" -v << EOF
server ${dns_ip}
update add bono-0.example.com. 30 A ${public_ip}
update add example.com. 30 A ${public_ip}
send
EOF
} && [ $retries -lt 10 ]
do
  retries=$((retries + 1))
  echo 'nsupdate failed - retrying (retry '$retries')...'
  sleep 5
done

