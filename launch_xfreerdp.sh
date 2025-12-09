#!/bin/bash
IP=$1

# Wait a few seconds for SSH to respond
sleep 10

ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa -L 3389:localhost:3389 ubuntu@$IP &
sleep 3

xfreerdp /v:localhost /u:ubuntu /p: /cert:ignore /dynamic-resolution +clipboard +fonts
