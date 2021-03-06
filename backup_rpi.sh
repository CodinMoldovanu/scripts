#!/bin/bash

#Set the date variable so we have nice file naming
days="$(date +'%Y-%m-%d')"

#Get the size so we can pass it to pv and display accurate percentage of operation
size=$(ssh pi@192.168.88.226 "sudo blockdev --getsize64 /dev/mmcblk0")

#Give us some info
let rate_limit=11
let human_size=size/1073741824
let expected_time=(human_size*1000/rate_limit)/60
echo "We've got ${human_size}GB to backup which should take about ${expected_time} minutes.."

if ssh pi@192.168.88.226 "true"
then
        echo -e "From:root@codin.ro\nSubject:RPi Backup ${days}\n\n Pi appears to be ok @ 192.168.88.226, starting backup of ${human_size}GB which should take about ${expected_time} minutes." | ssmtp kodin94@gmail.com
else
        echo -e "From:root@codin.ro\nSubject:RPi Backup ${days}\n\n\ Pi appears to be offline" | ssmtp kodin94@gmail.com
fi

#Connect to the RaspberryPi and dd the microSD card, pipe it into pv with the $size and output it locally using the $days variable.
ssh pi@192.168.88.226 "sudo dd if=/dev/mmcblk0" | pv -L ${rate_limit}m --size ${size} | dd of=rpi_backups/rpi_img_${days}.img.gz

BACKUP_FILE=rpi_backups/rpi_img_${days}.img.gz
BACKUP_SIZE=$(stat -c %s $BACKUP_FILE)

if [[ $BACKUP_SIZE+0 -eq $size+0 ]]
then
        echo -e "From:root@codin.ro\nSubject:RPi Backup ${days} Success\n\n Backup completed successfully. Backup size is ${BACKUP_SIZE}. Image has been saved to {$BACKUP_FILE}." | ssmtp kodin94@gmail.com
else
        echo -e "From:root@codin.ro\nSubject:RPi Backup ${days} Error\n\n Something went wrong and you have no logging." | ssmtp kodin94@gmail.com
fi
