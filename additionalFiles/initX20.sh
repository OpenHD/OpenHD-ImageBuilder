#!/bin/bash

#initialise x20 air-unit

sleep 10
depmod -a
modprobe 88XXau_wfb
modprobe HdZero
