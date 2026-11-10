#!/bin/bash
set -euo pipefail
exec 19>>/root/mephi-commands.log
BASH_XTRACEFD=19
set -x
artifacts=/root/mephi-results
install -d -m 755 "$artifacts"
ping -c 4 8.8.8.8 > /root/ping.out
dnf history > /root/dnf.out
stat /data/mephi-2026 > /root/stat.out
stat /mephi-web >> /root/stat.out
getcap /usr/sbin/tcpdump > /root/getcap.out
journalctl -u nginx -b --no-pager > /root/journalctl.out
getenforce > /root/getenforce.out
curl -fsS http://localhost/ > /root/curl.out
cp /root/ping.out /root/dnf.out /root/stat.out /root/getcap.out /root/journalctl.out /root/getenforce.out /root/curl.out "$artifacts/"
cp /etc/fstab /etc/passwd /etc/group /etc/security/pwquality.conf "$artifacts/"
set +x
awk -F: 'BEGIN {OFS=":"} {if ($2 != "" && $2 != "!" && $2 != "!!" && $2 != "*") $2="[REDACTED]"; print}' /etc/shadow > "$artifacts/shadow"
set -x
cp /etc/nginx/nginx.conf "$artifacts/nginx.conf"
cp /etc/pam.d/login "$artifacts/login.pam"
cp /etc/security/mephi-console-denied "$artifacts/mephi-console-denied"
cp /etc/login.defs "$artifacts/login.defs"
cp /etc/selinux/config "$artifacts/selinux-config"
cp /etc/dracut.conf.d/50-mephi-virtio.conf "$artifacts/mephi-virtio.conf"
cp /root/fix-initramfs.sh "$artifacts/fix-initramfs.sh"
printf 'Before reboot: ' > "$artifacts/boot-check.out"
cat /root/boot-id-before >> "$artifacts/boot-check.out"
printf 'After reboot: ' >> "$artifacts/boot-check.out"
cat /proc/sys/kernel/random/boot_id >> "$artifacts/boot-check.out"
uname -r >> "$artifacts/boot-check.out"
uptime >> "$artifacts/boot-check.out"
getfacl -p /data/mephi-2026 > "$artifacts/getfacl.out"
findmnt /mephi-web > "$artifacts/findmnt.out"
semanage fcontext -l -C > "$artifacts/selinux-fcontext.out"
nmcli -f connection.id,ipv4.method connection show "$(nmcli -g GENERAL.CONNECTION device show ens18)" > "$artifacts/network.out"
ip -brief address >> "$artifacts/network.out"
ip route >> "$artifacts/network.out"
rpm -qi tcpdump > "$artifacts/tcpdump-rpm.out"
cp /root/tcpdump-user1.out /root/verification.out /root/verification-after-reboot.out "$artifacts/"
cat /etc/os-release > "$artifacts/os-release.out"
rpm -qa 'redos-release*' >> "$artifacts/os-release.out"
systemctl get-default >> "$artifacts/os-release.out"
cp /root/configure.sh /root/verify.sh /root/verify-pam.py /root/collect.sh "$artifacts/"
set +x
bash -c 'history -c; test ! -f /root/.bash_history || history -r /root/.bash_history; history -r /root/mephi-commands.log; history > /root/history.out'
cp /root/history.out "$artifacts/history.out"
chmod 644 "$artifacts/"*
printf '%s\n' 'Artifacts collected; shadow hashes redacted'
