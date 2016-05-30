#!/bin/bash

aws cloudformation create-stack --stack-name WebAppStack --template-body file://cloudformation/create-web-app.json
echo "Building the Sainsburys Test Environment......."
echo "Estimated build time: 3 mins"
sleep 200

echo "Demonstrating load balancing."
curl http://52.58.13.166
echo ""
sleep 20
curl http://52.58.13.166
echo ""
