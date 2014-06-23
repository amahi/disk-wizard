#!/bin/bash

echo "Disk-Wizard Debug information fetcher"

printf "\n/*===*dsw.log wrapper script log ===*/\n" >> /var/log/debug_info.tmp
tail -n 50 /var/hda/apps/520ut3lo6w/elevated/dsw.log >> /var/log/debug_info.tmp

printf "\n/*=== *Current mounted partitions ===*/\n" >> /var/log/debug_info.tmp
sudo mount -l >> /var/log/debug_info.tmp 2>&1

printf "\n/*=== *list disk/partitions details with parted ===*/\n" >> /var/log/debug_info.tmp
parted -sl print all  >> /var/log/debug_info.tmp 2>&1

printf "\n/*=== *List all logical volumes ===*/\n" >> /var/log/debug_info.tmp
lvdisplay -av >> /var/log/debug_info.tmp 2>&1

printf "\n/*=== *dsk-wz.sh script ===*/\n" >> /var/log/debug_info.tmp
cat /var/hda/apps/520ut3lo6w/elevated/dsk-wz.sh >> /var/log/debug_info.tmp


printf "\n/*=== *disk-wizard log file===*/\n" >> /var/log/debug_info.tmp
tail -n 50 /var/hda/platform/html/log/dw_debug.log >> /var/log/debug_info.tmp

fpaste -l bash /var/log/debug_info.tmp
rm /var/log/debug_info.tmp
