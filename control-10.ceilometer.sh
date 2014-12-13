#!/bin/bash -ex
#
source config.cfg


########
echo "############ Cai dat MONGODB ############"
sleep 5
########
# Cai dat mongodb
apt-get install mongodb-server -y

sed -i 's/bind_ip = 127.0.0.1/bind_ip = 0.0.0.0/g' /etc/mongodb.conf

service mongodb restart

mongo --host controller --eval '
db = db.getSiblingDB("ceilometer");
db.addUser({user: "ceilometer",
pwd: "$SERVICE_PASSWORD",
roles: [ "readWrite", "dbAdmin" ]})'

########
echo "############ Cai dat MONGODB ############"
sleep 5
########
# Cai dat Ceilometer
apt-get install ceilometer-api ceilometer-collector ceilometer-agent-central ceilometer-agent-notification ceilometer-alarm-evaluator ceilometer-alarm-notifier python-ceilometerclient -y


ceil=/etc/ceilometer/ceilometer.conf
test -f $ceil.orig || cp $ceil $ceil.orig
rm $ceil
touch $ceil
cat << EOF >> $ceil
[DEFAULT]
rpc_backend = rabbit
rabbit_host = controller
rabbit_password = RABBIT_PASS
auth_strategy = keystone
log_dir = /var/log/ceilometer
[database]
connection = mongodb://ceilometer:CEILOMETER_DBPASS@controller:27017/ceilometer
[keystone_authtoken]
auth_uri = http://controller:5000/v2.0
identity_uri = http://controller:35357
admin_tenant_name = service
admin_user = ceilometer
admin_password = $ADMIN_PASS
[service_credentials]
os_auth_url = http://controller:5000/v2.0
os_username = ceilometer
os_tenant_name = service
os_password = $ADMIN_PASS
[publisher]
metering_secret = $TOKEN
EOF

service ceilometer-agent-central restart
service ceilometer-agent-notification restart
service ceilometer-api restart
service ceilometer-collector restart
service ceilometer-alarm-evaluator restart
service ceilometer-alarm-notifier restart


