#!/bin/bash

#Set the date variable so we have nice file naming
days="$(date +'%Y%m%d')"

#Get the size so we can pass it to pv and display accurate percentage of operation
size="$(ssh pi@192.168.88.226 "sudo blockdev --getsize64 /dev/mmcblk0")"

#Connect to the RaspberryPi and dd the microSD card, pipe it into pv with the $size and output it locally using the $days variable.
ssh pi@192.168.88.226 "sudo dd if=/dev/mmcblk0" | pv --size ${size} | dd of=rpi_backups/rpi_img_${days}.img.gz
