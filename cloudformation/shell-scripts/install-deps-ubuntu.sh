#!/bin/bash

# Update the packages installed, and add some additional ones
apt-get -y update;

apt-get -y install curl git nginx libc6 libc6-dev libc6-dbg libffi-dev python-dev build-essential unzip python-pip locales dos2unix 

apt-get install software-properties-common -y

apt-add-repository ppa:ansible/ansible -y

apt-get update -y

apt-get install ansible -y

pip install awscli

mkdir -p /etc/ansible/playbooks
mkdir -p /etc/ansible/configs

##disabled for ansible
sed -i 's/#   StrictHostKeyChecking ask/StrictHostKeyChecking no/' /etc/ssh/ssh_config


cat > /etc/ansible/run-provisioning.sh <<EOF
#!/bin/bash

ansible-playbook -s /etc/ansible/playbooks/nginx.yml &> /tmp/nginx.log
ansible-playbook -s /etc/ansible/playbooks/golang.yml &> /tmp/golang.log

exit 0
EOF

chmod 755 /etc/ansible/run-provisioning.sh


cat > /etc/rc.local <<EOF
#!/bin/sh -e

/etc/ansible/run-provisioning.sh | at now + 3 minutes

exit 0
EOF


cat > /etc/ansible/hosts <<EOF
[prov-server]
172.16.0.6

[web-server]
172.16.0.10

[app-server-1]
172.16.0.20

[app-server-2]
172.16.0.21
EOF


cat > /etc/ansible/configs/load-balancer.conf <<EOF
upstream appserver {
     server 172.16.0.20:8484;
     server 172.16.0.21:8484;
}

server {
     listen 80;

     location / {
         proxy_pass http://appserver;
     }
}
EOF

cat > /etc/ansible/playbooks/nginx.yml <<EOF
---
- hosts: web-server
  vars:
    http_port: 8484
    max_clients: 200
    remote_user: test-user
    become: yes
    become_user: sudo
  tasks:
  - name: ensure nginx is at the latest version
    apt: pkg=nginx state=latest
  - name: replace default nginx.conf with latest
    copy: src=/etc/ansible/configs/nginx.conf dest=/etc/nginx/ mode=0644
  - name: add lb config
    copy: src=/etc/ansible/configs/load-balancer.conf dest=/etc/nginx/conf.d/ mode=0644
    notify:
    - restart nginx
  - name: ensure nginx is running (and enable it at boot)
    service: name=nginx state=started enabled=yes
  handlers:
    - name: restart nginx
      service: name=nginx state=restarted
EOF

cat > /etc/ansible/playbooks/golang.yml <<EOF
---
  - hosts: app-server-1 app-server-2
    vars:
       http_port: 8484
       max_clients: 200
       remote_user: test-user
       become: yes
       become_method: sudo

    tasks:
     - name: insert/update .profile
       blockinfile:
        dest: /home/test-user/.profile
        block: |
          export GOROOT=/usr/local/go
          export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/bin
          export GOPATH=/home/test-user/work
       sudo: yes
     - name: download latest go and install
       get_url: url=https://storage.googleapis.com/golang/go1.6.linux-amd64.tar.gz dest=/usr/local validate_certs=False
           dest=/tmp/go1.6.linux-amd64.tar.gz
     - name: Extract the Go tarball if Go is not yet installed or not the desired version
       unarchive: src=/tmp/go1.6.linux-amd64.tar.gz
             dest=/usr/local
             copy=no
     - name: checkout app from github
       action: git repo=https://github.com/nealbaker/sainsburys-app.git dest=/home/test-user/work/src/github.com/user/sainsburys-app
     - name: cd into app dir and install
       file: path=/home/test-user/work owner=test-user group=test-user mode=755 state=directory recurse=yes
     - name: cd into app dir and install
       sudo: no
       shell: source ~/.profile && /usr/local/go/bin/go install
       args:
         executable: /bin/bash
         chdir: /home/test-user/work/src/github.com/user/sainsburys-app/
     - name: run the app
       shell: nohup /home/test-user/work/bin/sainsburys-app &
EOF



cat > /etc/ansible/configs/nginx.conf <<EOF
user  test-user;
worker_processes  2;   # Set to number of CPU cores

error_log  /var/log/nginx/error.log;

pid  /run/nginx.pid;

events {
    worker_connections  1024;
}

http {
  include  /etc/nginx/mime.types;
  default_type  application/octet-stream;

  log_format  main '$remote_addr - $remote_user [$time_local] "$request" '
              '$status $body_bytes_sent "$http_referer" '
              '"$http_user_agent" "$http_x_forwarded_for"';

  access_log  /var/log/nginx/access.log  main;

  sendfile  on;

  keepalive_timeout  65;

  include /etc/nginx/conf.d/*.conf;

  index  index.html index.htm;
}
EOF

cat > /etc/ansible/ansible.cfg <<EOF
# config file for ansible -- http://ansible.com/
# ==============================================

# nearly all parameters can be overridden in ansible-playbook
# or with command line flags. ansible will read ANSIBLE_CONFIG,
# ansible.cfg in the current working directory, .ansible.cfg in
# the home directory or /etc/ansible/ansible.cfg, whichever it
# finds first

[defaults]

# some basic default values...

#inventory      = /etc/ansible/hosts
#library        = /usr/share/my_modules/
#remote_tmp     = $HOME/.ansible/tmp
#forks          = 5
#poll_interval  = 15
#sudo_user      = root
#ask_sudo_pass = True
#ask_pass      = True
#transport      = smart
#remote_port    = 22
#module_lang    = C

# plays will gather facts by default, which contain information about
# the remote system.
#
# smart - gather by default, but don't regather if already gathered
# implicit - gather by default, turn off with gather_facts: False
# explicit - do not gather by default, must say gather_facts: True
#gathering = implicit

# additional paths to search for roles in, colon separated
#roles_path    = /etc/ansible/roles

# uncomment this to disable SSH key host checking
#host_key_checking = False

# change the default callback
#stdout_callback = skippy
# enable additional callbacks
#callback_whitelist = timer, mail

# change this for alternative sudo implementations
#sudo_exe = sudo

# What flags to pass to sudo
# WARNING: leaving out the defaults might create unexpected behaviours
#sudo_flags = -H -S -n

# SSH timeout
#timeout = 10

# default user to use for playbooks if user is not specified
# (/usr/bin/ansible will use current user as default)
remote_user = test-user

# logging is off by default unless this path is defined
# if so defined, consider logrotate
#log_path = /var/log/ansible.log

# default module name for /usr/bin/ansible
#module_name = command

# use this shell for commands executed under sudo
# you may need to change this to bin/bash in rare instances
# if sudo is constrained
#executable = /bin/sh

# if inventory variables overlap, does the higher precedence one win
# or are hash values merged together?  The default is 'replace' but
# this can also be set to 'merge'.
#hash_behaviour = replace

# by default, variables from roles will be visible in the global variable
# scope. To prevent this, the following option can be enabled, and only
# tasks and handlers within the role will see the variables there
#private_role_vars = yes

# list any Jinja2 extensions to enable here:
#jinja2_extensions = jinja2.ext.do,jinja2.ext.i18n

# if set, always use this private key file for authentication, same as
# if passing --private-key to ansible or ansible-playbook
private_key_file = /home/test-user/test.pem

# format of string {{ ansible_managed }} available within Jinja2
# templates indicates to users editing templates files will be replaced.
# replacing {file}, {host} and {uid} and strftime codes with proper values.
#ansible_managed = Ansible managed: {file} modified on %Y-%m-%d %H:%M:%S by {uid} on {host}
# This short version is better used in templates as it won't flag the file as changed every run.
#ansible_managed = Ansible managed: {file} on {host}

# by default, ansible-playbook will display "Skipping [host]" if it determines a task
# should not be run on a host.  Set this to "False" if you don't want to see these "Skipping"
# messages. NOTE: the task header will still be shown regardless of whether or not the
# task is skipped.
#display_skipped_hosts = True

# by default (as of 1.3), Ansible will raise errors when attempting to dereference
# Jinja2 variables that are not set in templates or action lines. Uncomment this line
# to revert the behavior to pre-1.3.
#error_on_undefined_vars = False

# by default (as of 1.6), Ansible may display warnings based on the configuration of the
# system running ansible itself. This may include warnings about 3rd party packages or
# other conditions that should be resolved if possible.
# to disable these warnings, set the following value to False:
#system_warnings = True

# by default (as of 1.4), Ansible may display deprecation warnings for language
# features that should no longer be used and will be removed in future versions.
# to disable these warnings, set the following value to False:
#deprecation_warnings = True

# (as of 1.8), Ansible can optionally warn when usage of the shell and
# command module appear to be simplified by using a default Ansible module
# instead.  These warnings can be silenced by adjusting the following
# setting or adding warn=yes or warn=no to the end of the command line
# parameter string.  This will for example suggest using the git module
# instead of shelling out to the git command.
# command_warnings = False


# set plugin path directories here, separate with colons
#action_plugins     = /usr/share/ansible/plugins/action
#callback_plugins   = /usr/share/ansible/plugins/callback
#connection_plugins = /usr/share/ansible/plugins/connection
#lookup_plugins     = /usr/share/ansible/plugins/lookup
#vars_plugins       = /usr/share/ansible/plugins/vars
#filter_plugins     = /usr/share/ansible/plugins/filter
#test_plugins       = /usr/share/ansible/plugins/test

# by default callbacks are not loaded for /bin/ansible, enable this if you
# want, for example, a notification or logging callback to also apply to
# /bin/ansible runs
#bin_ansible_callbacks = False


# don't like cows?  that's unfortunate.
# set to 1 if you don't want cowsay support or export ANSIBLE_NOCOWS=1
#nocows = 1

# set which cowsay stencil you'd like to use by default. When set to 'random',
# a random stencil will be selected for each task. The selection will be filtered
# against the `cow_whitelist` option below.
#cow_selection = default
#cow_selection = random

# when using the 'random' option for cowsay, stencils will be restricted to this list.
# it should be formatted as a comma-separated list with no spaces between names.
# NOTE: line continuations here are for formatting purposes only, as the INI parser
#       in python does not support them.
#cow_whitelist=bud-frogs,bunny,cheese,daemon,default,dragon,elephant-in-snake,elephant,eyes,\
#              hellokitty,kitty,luke-koala,meow,milk,moofasa,moose,ren,sheep,small,stegosaurus,\
#              stimpy,supermilker,three-eyes,turkey,turtle,tux,udder,vader-koala,vader,www

# don't like colors either?
# set to 1 if you don't want colors, or export ANSIBLE_NOCOLOR=1
#nocolor = 1

# if set to a persistent type (not 'memory', for example 'redis') fact values
# from previous runs in Ansible will be stored.  This may be useful when
# wanting to use, for example, IP information from one group of servers
# without having to talk to them in the same playbook run to get their
# current IP information.
#fact_caching = memory


# retry files
# When a playbook fails by default a .retry file will be created in ~/
# You can disable this feature by setting retry_files_enabled to False
# and you can change the location of the files by setting retry_files_save_path

#retry_files_enabled = False
#retry_files_save_path = ~/.ansible-retry


# prevents logging of task data, off by default
#no_log = False

# prevents logging of tasks, but only on the targets, data is still logged on the master/controller
#no_target_syslog = False

# controls the compression level of variables sent to
# worker processes. At the default of 0, no compression
# is used. This value must be an integer from 0 to 9.
#var_compression_level = 9

[privilege_escalation]
#become=True
#become_method=sudo
#become_user=root
#become_ask_pass=False

[paramiko_connection]

# uncomment this line to cause the paramiko connection plugin to not record new host
# keys encountered.  Increases performance on new host additions.  Setting works independently of the
# host key checking setting above.
#record_host_keys=False

# by default, Ansible requests a pseudo-terminal for commands executed under sudo. Uncomment this
# line to disable this behaviour.
#pty=False

[ssh_connection]

# ssh arguments to use
# Leaving off ControlPersist will result in poor performance, so use
# paramiko on older platforms rather than removing it
#ssh_args = -o ControlMaster=auto -o ControlPersist=60s

# The path to use for the ControlPath sockets. This defaults to
# "%(directory)s/ansible-ssh-%%h-%%p-%%r", however on some systems with
# very long hostnames or very long path names (caused by long user names or
# deeply nested home directories) this can exceed the character limit on
# file socket names (108 characters for most platforms). In that case, you
# may wish to shorten the string below.
#
# Example:
# control_path = %(directory)s/%%h-%%r
#control_path = %(directory)s/ansible-ssh-%%h-%%p-%%r

# Enabling pipelining reduces the number of SSH operations required to
# execute a module on the remote server. This can result in a significant
# performance improvement when enabled, however when using "sudo:" you must
# first disable 'requiretty' in /etc/sudoers
#
# By default, this option is disabled to preserve compatibility with
# sudoers configurations that have requiretty (the default on many distros).
#
#pipelining = False

# if True, make ansible use scp if the connection type is ssh
# (default is sftp)
#scp_if_ssh = True

# if False, sftp will not use batch mode to transfer files. This may cause some
# types of file transfer failures impossible to catch however, and should
# only be disabled if your sftp version has problems with batch mode
#sftp_batch_mode = False

[accelerate]
#accelerate_port = 5099
#accelerate_timeout = 30
#accelerate_connect_timeout = 5.0

# The daemon timeout is measured in minutes. This time is measured
# from the last activity to the accelerate daemon.
#accelerate_daemon_timeout = 30

# If set to yes, accelerate_multi_key will allow multiple
# private keys to be uploaded to it, though each user must
# have access to the system via SSH to add a new key. The default
# is "no".
#accelerate_multi_key = yes

[selinux]
# file systems that require special treatment when dealing with security context
# the default behaviour that copies the existing context or uses the user default
# needs to be changed to use the file system dependent context.
#special_context_filesystems=nfs,vboxsf,fuse,ramfs

[colors]
#verbose = blue
#warn = bright purple
#error = red
#debug = dark gray
#deprecate = purple
#skip = cyan
#unreachable = red
#ok = green
#changed = yellow
EOF

exit 0
