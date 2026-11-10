#!/bin/bash
set -euo pipefail
exec 19>>/root/mephi-commands.log
BASH_XTRACEFD=19
set -x
cat > /etc/dracut.conf.d/50-mephi-virtio.conf <<'EOF'
hostonly="no"
add_drivers+=" virtio_pci virtio_scsi virtio_blk virtio_net virtio_console "
EOF
cp -a /boot/initramfs-6.12.113-1.red80.x86_64.img /root/mephi-private/initramfs-6.12.113.before.img
dracut --force --no-hostonly /boot/initramfs-6.12.113-1.red80.x86_64.img 6.12.113-1.red80.x86_64
ls -lh /boot/initramfs-6.12.113-1.red80.x86_64.img
lsinitrd /boot/initramfs-6.12.113-1.red80.x86_64.img | grep -E 'virtio_scsi|virtio_blk|virtio_console'
