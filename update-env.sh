#!/bin/bash

export AWS_ACCESS_KEY_ID=AKIAJYNP7DCG3QUUSI4A
export AWS_SECRET_ACCESS_KEY=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
export AWS_DEFAULT_REGION=eu-central-1

echo "Recreating the Sainsburys Test Environment....."
aws cloudformation delete-stack --stack-name WebAppStack

aws cloudformation create-stack --stack-name WebAppStack --template-body file://cloudformation/create-web-app.json
echo "Rebuilding the Sainsburys Test Environment......."
echo "Estimated rebuild time: 3 mins"
sleep 200

echo "Demonstrating load balancing and application changes."
curl http://52.58.198.214
echo ""
sleep 2
curl http://52.58.198.214
echo ""
