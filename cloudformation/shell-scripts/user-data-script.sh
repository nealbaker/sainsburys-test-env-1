#!/bin/bash

groupadd administrators
useradd -m -s /bin/bash test-user

mkdir /home/test-user/.ssh
touch /home/test-user/.ssh/authorized_keys

curl http://169.254.169.254/latest/meta-data/public-keys/0/openssh-key > /home/test-user/.ssh/authorized_keys

chown -R test-user.test-user /home/test-user/.ssh
chmod -R 700 /home/test-user/.ssh
chmod 600 /home/test-user/.ssh/authorized_keys

echo "test-user ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

userdel -rf ubuntu

