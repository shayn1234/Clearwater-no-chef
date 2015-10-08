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
public_ip=${public_ip}
public_hostname=ellis-0.example.com
etcd_cluster=$etcd_ip
EOF

# Now install the software.
# "-o DPkg::options::=--force-confnew" works around https://github.com/Metaswitch/clearwater-infrastructure/issues/186.
DEBIAN_FRONTEND=noninteractive apt-get install ellis --yes --force-yes -o DPkg::options::=--force-confnew
DEBIAN_FRONTEND=noninteractive apt-get install clearwater-config-manager --yes --force-yes
# Configure and upload /etc/clearwater/shared_config.
cat > /etc/clearwater/shared_config << EOF
# Deployment definitions
home_domain=example.com
sprout_hostname=sprout.example.com
hs_hostname=hs.example.com:8888
hs_provisioning_hostname=hs.example.com:8889
ralf_hostname=ralf.example.com:10888
xdms_hostname=homer.example.com:7888
                                                                                               
# Email server configuration
smtp_smarthost=localhost
smtp_username=username
smtp_password=password
email_recovery_sender=clearwater@example.org
                                                                                                                                                                                                       
# Keys
signup_key=secret
turn_workaround=secret
ellis_api_key=secret
ellis_cookie_key=secret
EOF
sudo /usr/share/clearwater/clearwater-config-manager/scripts/upload_shared_config
sudo /usr/share/clearwater/clearwater-config-manager/scripts/apply_shared_config
# Allocate a allocate a pool of numbers to assign to users.
/usr/share/clearwater/ellis/env/bin/python /usr/share/clearwater/ellis/src/metaswitch/ellis/tools/create_numbers.py --start 6505550000 --count 1000

# Update DNS
retries=0
while ! { nsupdate -y "example.com:8r6SIIX/cWE6b0Pe8l2bnc/v5vYbMSYvj+jQPP4bWe+CXzOpojJGrXI7iiustDQdWtBHUpWxweiHDWvLIp6/zw==" -v << EOF
server ${dns_ip}
update add ellis-0.example.com. 30 A ${public_ip}
update add ellis.example.com. 30 A ${public_ip}
send
EOF
} && [ $retries -lt 10 ]
do
  retries=$((retries + 1))
  echo 'nsupdate failed - retrying (retry '$retries')...'
  sleep 5
done

