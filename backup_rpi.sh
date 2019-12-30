#!/bin/bash

EMAIL = "your_email@mail.com"

#Set the date variable so we have nice file naming
days="$(date +'%Y-%m-%d')"

#Get the size so we can pass it to pv and display accurate percentage of operation
size="$(ssh pi@192.168.88.226 "sudo blockdev --getsize64 /dev/mmcblk0")"

#Give us some info
let human_size=size/1073741824
let expected_time=(human_size*1000/11)/60
echo "We've got ${human_size}GB to backup which should take about ${expected_time} minutes.."

if ssh pi@192.168.88.226 "true"
then
	echo -e "From:root@codin.ro\nSubject:RPi Backup ${days}\n\n Pi appears to be ok @ 192.168.88.226, starting backup of ${human_size}GB which should take about ${expected_time} minutes." | ssmtp $EMAIL
else
	echo -e "From:root@codin.ro\nSubject:RPi Backup ${days}\n\n\ Pi appears to be offline" | ssmtp $EMAIL
fi

#Connect to the RaspberryPi and dd the microSD card, pipe it into pv with the $size and output it locally using the $days variable.
ssh pi@192.168.88.226 "sudo dd if=/dev/mmcblk0" | pv --size ${size} | dd of=rpi_backups/rpi_img_${days}.img.gz

BACKUP_FILE = rpi_backups/rpi_img_${days}.img.gz
BACKUP_SIZE = $(stat -c%s "$BACKUP_FILE")

if [ BACKUP_SIZE -eq size ]
then
	echo -e "From:root@codin.ro\nSubject:RPi Backup ${days} Success\n\n Backup completed successfully." | ssmtp $EMAIL
else
	echo -e "From:root@codin.ro\nSubject:RPi Backup ${days} Success\n\n Did you really think this would work just that easily?" | ssmtp $EMAIL
fi
