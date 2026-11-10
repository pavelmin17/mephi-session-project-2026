#!/bin/bash
set -euo pipefail
umask 022
exec 19>>/root/mephi-commands.log
BASH_XTRACEFD=19
set -x
test "$(id -u)" = 0
grep -qi 'RED OS' /etc/os-release
hostnamectl set-hostname mephi-2026.domain.local
dnf -y upgrade
dnf -y install nginx libcap-ng-utils dnf-plugins-core acl policycoreutils-python-utils libcap libpcap parted qemu-guest-agent openssl
cd /tmp
dnf download --arch=x86_64 --destdir /tmp tcpdump
rpm -Uvh --replacepkgs /tmp/tcpdump-*.x86_64.rpm
if ! blkid -L MEPHI_WEB >/dev/null; then
    test "$(blockdev --getsize64 /dev/sdb)" -eq 8589934592
    test "$(lsblk -nr -o NAME /dev/sdb | wc -l)" -eq 1
    test -z "$(wipefs -n /dev/sdb)"
    parted -s /dev/sdb mklabel gpt
    parted -s /dev/sdb mkpart primary ext4 1MiB 100%
    udevadm settle
    mkfs.ext4 -L MEPHI_WEB /dev/sdb1
fi
test "$(blkid -L MEPHI_WEB)" = /dev/sdb1
mkdir -p /mephi-web
if ! grep -q '^LABEL=MEPHI_WEB[[:space:]]' /etc/fstab; then
    printf '%s\n' 'LABEL=MEPHI_WEB /mephi-web ext4 defaults 0 2' >> /etc/fstab
fi
systemctl daemon-reload
mountpoint -q /mephi-web || mount /mephi-web
getent group mephi-dev >/dev/null || groupadd mephi-dev
getent group curators >/dev/null || groupadd -g 4444 curators
test "$(getent group curators | cut -d: -f3)" = 4444
for entry in user1:5501 user2:5502 user3:5503; do
    user=${entry%:*}
    uid=${entry#*:}
    id "$user" >/dev/null 2>&1 || useradd -m -u "$uid" -G mephi-dev -s /bin/bash "$user"
    test "$(id -u "$user")" = "$uid"
    usermod -aG mephi-dev "$user"
done
for user in curator1 curator2; do
    id "$user" >/dev/null 2>&1 || useradd -m -g curators -s /bin/bash "$user"
    usermod -aG curators "$user"
done
install -d -m 700 /root/mephi-private
set +x
for user in user1 user2 user3 curator1 curator2; do
    if [ ! -e "/root/mephi-private/$user.password" ]; then
        password=$(openssl rand -base64 24)
        printf '%s\n' "$password" > "/root/mephi-private/$user.password"
        chmod 600 "/root/mephi-private/$user.password"
        printf '%s:%s\n' "$user" "$password" | chpasswd
        unset password
    fi
done
set -x
mkdir -p /data/mephi-2026
chown root:mephi-dev /data/mephi-2026
chmod 2770 /data/mephi-2026
setfacl -m u::rwx,g::rwx,g:curators:r-x,m::rwx,o::--- /data/mephi-2026
setfacl -d -m u::rwx,g::rwx,g:curators:r-x,m::rwx,o::--- /data/mephi-2026
chmod u-s /usr/sbin/tcpdump
setcap cap_net_raw,cap_net_admin=eip /usr/sbin/tcpdump
sed -i 's/^SELINUX=.*/SELINUX=enforcing/' /etc/selinux/config
test "$(getenforce)" != Disabled
setenforce 1
semanage fcontext -a -t httpd_sys_content_t '/mephi-web(/.*)?'
printf '%s\n' 'Hello from Student: М265268' > /mephi-web/index.html
chmod 755 /mephi-web
chmod 644 /mephi-web/index.html
restorecon -RFv /mephi-web
cp -a /etc/nginx/nginx.conf /root/mephi-private/nginx.conf.before
cat > /etc/nginx/nginx.conf <<'EOF'
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log;
pid /run/nginx.pid;
include /usr/share/nginx/modules/*.conf;
events {
    worker_connections 1024;
}
http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    access_log /var/log/nginx/access.log;
    sendfile on;
    server {
        listen 80 default_server;
        listen [::]:80 default_server;
        server_name _;
        root /mephi-web;
        index index.html;
        location / {
            try_files $uri $uri/ =404;
        }
    }
}
EOF
mkdir -p /etc/systemd/system/nginx.service.d
cat > /etc/systemd/system/nginx.service.d/mephi-web.conf <<'EOF'
[Unit]
RequiresMountsFor=/mephi-web
EOF
nginx -t
systemctl daemon-reload
systemctl enable --now nginx
if systemctl is-active --quiet firewalld; then
    firewall-cmd --permanent --add-service=http
    firewall-cmd --reload
fi
printf '%s\n' curator1 curator2 > /etc/security/mephi-console-denied
chmod 644 /etc/security/mephi-console-denied
if ! grep -q 'file=/etc/security/mephi-console-denied' /etc/pam.d/login; then
    sed -i '1a account required pam_listfile.so item=user sense=deny file=/etc/security/mephi-console-denied onerr=fail' /etc/pam.d/login
fi
sed -i 's/^[[:space:]]*PASS_MAX_DAYS[[:space:]].*/PASS_MAX_DAYS   90/' /etc/login.defs
sed -i -E '/^[[:space:]]*#?[[:space:]]*(minlen|dcredit|ucredit|lcredit|ocredit|enforcing|enforce_for_root)[[:space:]=]/d' /etc/security/pwquality.conf
cat >> /etc/security/pwquality.conf <<'EOF'
minlen = 12
dcredit = 0
ucredit = 0
lcredit = 0
ocredit = 0
enforcing = 1
enforce_for_root
EOF
grep -q 'pam_pwquality.so' /etc/pam.d/system-auth
for user in root user1 user2 user3 curator1 curator2; do
    chage -M 90 "$user"
done
rootdate=$(getent shadow root | cut -d: -f3)
if [ -z "$rootdate" ] || [ "$rootdate" -le 0 ]; then
    chage -d "$(date +%F)" root
fi
systemctl set-default multi-user.target
systemctl enable sshd qemu-guest-agent
curl -fsS http://localhost/
getenforce
findmnt /mephi-web
printf '%s\n' 'Configuration complete'
