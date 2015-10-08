#!/bin/bash

#exec > >(tee -a /var/log/clearwater-cloudify.log) 2>&1

# Configure the APT software source.
echo 'deb http://repo.cw-ngv.com/stable binary/' > /etc/apt/sources.list.d/clearwater.list
curl -L http://repo.cw-ngv.com/repo_key | apt-key add -
apt-get update

# Configure /etc/clearwater/local_config.
mkdir -p /etc/clearwater
cat > /etc/clearwater/config << EOF
# Deployment definitions
home_domain=example.com
sprout_hostname=sprout.example.com
chronos_hostname=$(hostname -I | sed -e 's/  *//g'):7253
hs_hostname=hs.example.com:8888
hs_provisioning_hostname=hs.example.com:8889
ralf_hostname=ralf.example.com:10888
xdms_hostname=homer.example.com:7888

# Local IP configuration
local_ip=$(hostname -I)
public_ip=
public_hostname=homer.example.com

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

# Now install the software.
sudo DEBIAN_FRONTEND=noninteractive apt-get install clearwater-cassandra --yes --force-yes
sudo DEBIAN_FRONTEND=noninteractive apt-get install homer --yes --force-yes

