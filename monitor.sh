#!/bin/bash
while true; do
    if ! curl -s -o /dev/null -w '%{http_code}' http://localhost:3002 | grep -q '200'; then
        echo "$(date): Server down, restarting..."
        cd /Users/administrator/Documents/tickers
        pkill -f 'node server.js'
        sleep 2
        nohup npm start > server.log 2>&1 &
        sleep 5
    else
        echo "$(date): Server healthy"
    fi
    sleep 30
done
