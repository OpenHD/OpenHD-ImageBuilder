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