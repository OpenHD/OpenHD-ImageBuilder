#!/bin/bash

sudo apt-get update
apt download libc6 libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev
ls -a
cp *.deb /home/openhd/
ls -a