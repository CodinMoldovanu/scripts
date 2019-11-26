#!/bin/bash

#Set the date variable so we have nice file naming
days="$(date +'%Y-%m-%d')"

#Get the size so we can pass it to pv and display accurate percentage of operation
size="$(ssh pi@192.168.88.226 "sudo blockdev --getsize64 /dev/mmcblk0")"

#Give us some info
let human_size=size/1073741824
let expected_time=(human_size*1000/11)/60
echo "We've got ${human_size}GB to backup which should take about ${expected_time} minutes..."

#Connect to the RaspberryPi and dd the microSD card, pipe it into pv with the $size and output it locally using the $days variable.
ssh pi@192.168.88.226 "sudo dd if=/dev/mmcblk0" | pv --size ${size} | dd of=rpi_backups/rpi_img_${days}.img.gz
