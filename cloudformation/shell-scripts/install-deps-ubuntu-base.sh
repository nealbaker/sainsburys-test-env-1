#!/bin/bash

# Update the packages installed, and add some additional ones
apt-get -y update;

apt-get -y install curl git

##disabled for ansible access
sed -i 's/#   StrictHostKeyChecking ask/StrictHostKeyChecking no/' /etc/ssh/ssh_config

exit 0
