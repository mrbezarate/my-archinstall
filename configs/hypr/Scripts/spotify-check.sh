#!/bin/bash
export PATH="$PATH:$HOME/.spicetify"

if pgrep -x spotify > /dev/null; then
    spicetify refresh -s
fi
