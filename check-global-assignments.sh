#!/usr/bin/env sh
for file in $(dirname "$0")/*.lua; do
    echo "$file..."
    luac -p -l $file | grep -E '[GS]ETGLOBAL' | grep -vE '(string|table|tonumber|pairs|type|assert|import|require|math|LrDate|_PLUGIN|LOC)'
done
