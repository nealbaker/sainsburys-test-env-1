#!/bin/bash
##
echo "5.1 Set Shell For System Accounts (/dev/null)"
cp /etc/passwd /etc/passwd.${TODAY}

for USR in `cut -d: -f1 /etc/passwd`;
do
        uid=`id -u ${USR}`
        if [[ ${uid} -lt 500 && ${USR} != "root" ]];
        then
                usermod -L -s /dev/null ${USR}
        fi
done

##
echo "5.2 Check Accounts For Null Password"
cp /etc/shadow /etc/shadow.${TODAY}
awk -F: '($2 == "") { print $1 }' /etc/shadow

##
echo "5.3 Set Password Aging"
cp /etc/login.defs /etc/login.defs.${TODAY}
awk '($1 ~ /^PASS_MAX_DAYS/) { $2="90" }
($1 ~ /^PASS_MIN_DAYS/) { $2="7" }
($1 ~ /^PASS_WARN_AGE/) { $2="28" }
{ print } ' /etc/login.defs.${TODAY} > /etc/login.defs

sed 's/password.*[success=1 default=ignore].*pam_unix.so obscure sha512/password    [success=1 default=ignore]    pam_unix.so obscure sha512 minlen=8/' -i /etc/pam.d/common-password

##
echo "5.4 User Home Directory Permissions"
for userhome in `awk -F: '($3 >= 500) { print $6 }' /etc/passwd`;
do
        if [[ ${userhome} != "/nonexistent" ]];
        then
                chmod 750 ${userhome}
        fi
done

##
echo "5.5 Configuring Sudo"
apt-get install sudo
cat > /etc/sudoers <<EOF
# Users
root    ALL=(ALL) ALL
test-user ALL=(ALL) NOPASSWD:ALL

%administrators	ALL=(ALL) ALL
EOF

#remove unwanted accounts
userdel -rf ubuntu
userdel -rf games
userdel -rf irc
userdel -rf news




exit 0
