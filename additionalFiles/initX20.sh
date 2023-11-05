#!/bin/bash

#initialise x20 air-unit

#add platform identification
mkdir -p /usr/local/share/openhd/platform/x20
mkdir -p /usr/local/share/openhd/platform/wifi_card_type/88xxau/
touch /usr/local/share/openhd/platform/wifi_card_type/88xxau/custom
touch /usr/local/share/openhd/platform/x20/hdzero

sleep 10
depmod -a
modprobe 88XXau_wfb
modprobe HdZero

