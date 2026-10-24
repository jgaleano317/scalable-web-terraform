#!/bin/bash

systemctl is-active --quiet scalable-web-app.service

if [ $? -ne 0 ]; then
    echo "scalable-web-app service is not running"
    exit 1
fi

echo "scalable-web-app service is running"
