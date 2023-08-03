#!/bin/bash

#dirty hack to rotate steamdeck
if xinput | grep 'FTS3528'; then
    echo "Running on a Steam Deck, rotating screen!"
    xrandr -o right
    xinput set-prop $(xinput | grep 'FTS3528' | head -n 1 | awk '{print $4}' | sed 's/id=//g' | grep [0-9]) --type=float "Coordinate Transformation Matrix" 0 1 0 -1 0 1 0 0 1
else
    echo "Not running on a Steam Deck."
fi
