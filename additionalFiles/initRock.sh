#!/bin/bash

#add platform identification
mkdir -p /usr/local/share/openhd/platform/rock


if [[ -f "/boot/openhd/rock-5a.txt" ]]; then
    echo "Running on a rock5 A"
    mkdir -p /usr/local/share/openhd/platform/rock/rock5a
    config_file=$(find /boot/openhd/ -type f -name 'IMX*')
    
    if [[ -n "$config_file" ]]; then
        if [[ "$config_file" == *"/IMX415"* ]]; then
            cp "/boot/openhd/rock5_camera_configs/a/imx415.conf" "/boot/extlinux/extlinux.conf"
            echo "$config_file written"
        elif [[ "$config_file" == *"/IMX462"* ]]; then
            cp "/boot/openhd/rock5_camera_configs/a/imx462.conf" "/boot/extlinux/extlinux.conf"
            echo "$config_file written"
        else
            echo "No Camera configured"
        fi
    else
        echo "Config file not found"
    fi
fi


if [[ -f "/boot/openhd/rock-5b.txt" ]]; then
    echo "Running on a rock5 B"
    mkdir -p /usr/local/share/openhd/platform/rock/rock5b
    config_file=$(find /boot/openhd/ -type f -name 'IMX*')
    
    if [[ -n "$config_file" ]]; then
        if [[ "$config_file" == *"/IMX415"* ]]; then
            cp "/boot/openhd/rock5_camera_configs/b/imx415.conf" "/boot/extlinux/extlinux.conf"
            echo "$config_file written"
        elif [[ "$config_file" == *"/IMX462"* ]]; then
            cp "/boot/openhd/rock5_camera_configs/b/imx462.conf" "/boot/extlinux/extlinux.conf"
            echo "$config_file written"
        else
            echo "No Camera configured"
        fi
    else
        echo "Config file not found"
    fi
fi

if [[ -f "/boot/openhd/rock-rk3566.txt" ]]; then
    echo "Running on a rk3566 "
    mkdir -p /usr/local/share/openhd/platform/rock/rk3566
    touch /boot/openhd/IExecuted
    config_file=$(find /boot/openhd/ -type f -name 'IMX*')
    
    if [[ -n "$config_file" ]]; then
        if [[ "$config_file" == *"/708"* ]]; then
            cp "/boot/openhd/rock3_camera_configs/zero3w/imx708.conf" "/boot/extlinux/extlinux.conf"
            echo "$config_file written"
        elif [[ "$config_file" == *"/IMX462"* ]]; then
            cp "/boot/openhd/rock3_camera_configs/zero3w/imx462.conf" "/boot/extlinux/extlinux.conf"
            echo "$config_file written"
        else
            echo "No Camera configured"
        fi
    else
        echo "Config file not found"
    fi

    if [[ -n "/boot/openhd/resize.txt" ]]; then
    echo "resizing started"
    rm /boot/openhd/resize.txt
    (pv -n /dev/mmcblk1 | dd of=/dev/mmcblk0 bs=128M conv=notrunc,noerror) 2>&1 | whiptail --gauge "Running dd command (cloning), please wait..." 10 70 0
    fi

fi