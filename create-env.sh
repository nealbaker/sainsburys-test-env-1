#!/bin/bash

export AWS_ACCESS_KEY_ID=AKIAIUFLHWGJ2GVHTNKA
export AWS_SECRET_ACCESS_KEY=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
export AWS_DEFAULT_REGION=eu-central-1


aws cloudformation create-stack --stack-name WebAppStack --template-body file://cloudformation/create-web-app.json
echo "Building the Sainsburys Test Environment......."
echo "Estimated build time: 3 mins"
sleep 200

echo "Demonstrating load balancing."
curl http://52.58.198.214
echo ""
sleep 2
curl http://52.58.198.214
echo ""
