#!/bin/bash
echo "Disk-Wizard Debug information fetcher"

output=/tmp/dw_debug_$$.tmp

#exec > $output 2>&1

echo -e "\n------------This Debug Information was Generated on $(date +"%B-%d-%Y %r")------------\n"

printf "\n/*===*dsw.log wrapper script log (tail -n 50)===*/\n"

if [ ! -f /var/hda/apps/520ut3lo6w/elevated/dsw.log ]; then
	echo "File not found!"
else
	tail -n 50 /var/hda/apps/520ut3lo6w/elevated/dsw.log
fi

printf "\n/*=== *Current mounted partitions ===*/\n"
sudo mount -l

printf "\n/*=== *list disk/partitions details with parted ===*/\n"
parted -sl print all

printf "\n/*=== *List all logical volumes ===*/\n"
lvdisplay -av

printf "\n/*=== *dsk-wz.sh wrapper script ===*/\n"

if [ ! -f /var/hda/apps/520ut3lo6w/elevated/dsk-wz.sh ]; then
	echo "File not found!"
else
	cat /var/hda/apps/520ut3lo6w/elevated/dsk-wz.sh
fi

printf "\n/*=== *disk-wizard rails log file(tail -n 50)===*/\n"

if [ ! -f /var/hda/platform/html/log/dw_debug.log ]; then
	echo "File not found!"
else
	tail -n 50 /var/hda/platform/html/log/dw_debug.log
fi

#fpaste -l "shell" /var/log/debug_info.tmp

tail -n 600 /var/hda/platform/html/log/dw_debug.log > temp_file && fpaste temp_file

