#!/usr/bin/env fish
set DIR (status dirname)
python3 "$DIR/server.py" "$DIR" $argv
