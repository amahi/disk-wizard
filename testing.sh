#! /bin/bash
echo "Start coping ........"
sudo scp -r -i ../disks/id_rsa2.pub /media/data_1/Uni_work/Level3_semester1/gsoc/amahi/amahi_disk_manager/* kbsoft@172.16.55.130:/home/kbsoft/amahi/disk_wizard
