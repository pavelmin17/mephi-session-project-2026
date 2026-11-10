#!/bin/bash
set -euo pipefail
exec 19>>/root/mephi-commands.log
BASH_XTRACEFD=19
set -x
test "$(hostname)" = mephi-2026.domain.local
test "$(systemctl get-default)" = multi-user.target
test "$(getenforce)" = Enforcing
systemctl is-enabled nginx
systemctl is-active nginx
test "$(findmnt -n -o FSTYPE /mephi-web)" = ext4
test "$(findmnt -n -o SOURCE /mephi-web)" = /dev/sdb1
test "$(blkid -s LABEL -o value /dev/sdb1)" = MEPHI_WEB
test "$(curl -fsS http://localhost/)" = 'Hello from Student: М265268'
nginx -t
getcap /usr/sbin/tcpdump
test ! -u /usr/sbin/tcpdump
test "$(getent group curators | cut -d: -f3)" = 4444
for entry in user1:5501 user2:5502 user3:5503; do
    test "$(id -u "${entry%:*}")" = "${entry#*:}"
done
work=/data/mephi-2026/verification
runuser -u user1 -- mkdir "$work"
for user in user1 user2 user3; do
    runuser -u "$user" -- sh -c 'umask 0777; printf "%s\n" "$1" > "$2/$1.txt"' sh "$user" "$work"
done
for user in user1 user2 user3; do
    for file in "$work"/*.txt; do
        runuser -u "$user" -- sh -c 'printf "%s\n" "$1" >> "$2"; cat "$2" >/dev/null' sh "$user" "$file"
    done
done
for user in curator1 curator2; do
    for file in "$work"/*.txt; do
        runuser -u "$user" -- cat "$file" >/dev/null
        runuser -u "$user" -- test ! -w "$file"
    done
    runuser -u "$user" -- test ! -w "$work"
done
runuser -u nobody -- test ! -r "$work"
runuser -u nobody -- test ! -x "$work"
getfacl -p /data/mephi-2026 "$work" "$work/user1.txt"
rm -r "$work"
timeout 12 runuser -u user1 -- tcpdump -i lo -nn -c 1 icmp > /root/tcpdump-user1.out 2>&1 &
capture=$!
sleep 1
ping -c 1 127.0.0.1
wait "$capture"
cat /root/tcpdump-user1.out
python3 /root/verify-pam.py
for user in root user1 user2 user3 curator1 curator2; do
    test "$(getent shadow "$user" | cut -d: -f5)" = 90
done
nmcli -f connection.id,ipv4.method connection show "$(nmcli -g GENERAL.CONNECTION device show ens18)"
test "$(nmcli -g ipv4.method connection show "$(nmcli -g GENERAL.CONNECTION device show ens18)")" = auto
printf '%s\n' 'ALL CHECKS PASSED'
