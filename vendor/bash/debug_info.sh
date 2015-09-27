#!/bin/bash
echo "Disk-Wizard Debug information fetcher"

echo -e "\n------------This Debug Information was Generated on $(date +"%B-%d-%Y %r")------------\n" > /var/log/debug_info.tmp

printf "\n/*===*dsw.log wrapper script log (tail -n 50)===*/\n" >> /var/log/debug_info.tmp

if [ ! -f /var/hda/apps/520ut3lo6w/elevated/dsw.log ]; then
	        echo "File not found!" >> /var/log/debug_info.tmp
else
	        tail -n 50 /var/hda/apps/520ut3lo6w/elevated/dsw.log >> /var/log/debug_info.tmp
fi

printf "\n/*=== *Current mounted partitions ===*/\n" >> /var/log/debug_info.tmp
sudo mount -l >> /var/log/debug_info.tmp 2>&1

printf "\n/*=== *list disk/partitions details with parted ===*/\n" >> /var/log/debug_info.tmp
parted -sl print all  >> /var/log/debug_info.tmp 2>&1

printf "\n/*=== *List all logical volumes ===*/\n" >> /var/log/debug_info.tmp
lvdisplay -av >> /var/log/debug_info.tmp 2>&1

printf "\n/*=== *dsk-wz.sh wrapper script ===*/\n" >> /var/log/debug_info.tmp

if [ ! -f /var/hda/apps/520ut3lo6w/elevated/dsk-wz.sh ]; then
	        echo "File not found!" >> /var/log/debug_info.tmp
else
		        cat /var/hda/apps/520ut3lo6w/elevated/dsk-wz.sh >> /var/log/debug_info.tmp
fi

printf "\n/*=== *disk-wizard rails log file(tail -n 50)===*/\n" >> /var/log/debug_info.tmp

if [ ! -f /var/hda/platform/html/log/dw_debug.log ]; then
	        echo "File not found!" >> /var/log/debug_info.tmp
else
		        tail -n 50 /var/hda/platform/html/log/dw_debug.log >> /var/log/debug_info.tmp
fi

fpaste -l bash /var/log/debug_info.tmp
