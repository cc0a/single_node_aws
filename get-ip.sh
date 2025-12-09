#!/bin/bash
# Try to get your public IP from AWS CLI (Elastic IPs)
IP=$(aws ec2 describe-addresses --query 'Addresses[0].PublicIp' --output text 2>/dev/null)

# Fallback: detect your public IP
if [[ "$IP" == "None" || -z "$IP" ]]; then
  IP=$(curl -s https://checkip.amazonaws.com)
fi

echo "{\"cidr\": \"${IP}/32\"}"
