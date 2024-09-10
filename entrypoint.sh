#!/bin/bash

REPO=$REPO
ACCESS_TOKEN=$TOKEN

#echo $REPO
#TOKEN=$(curl -X POST -H "Authorization: token ${ACCESS_TOKEN}" -H "Accept: application/vnd.github.v3+json" https://api.github.com/repos/${REPO}/actions/runners/registration-token | jq .token --raw-output)

cd /home/docker/docker-github-actions-runner

echo "--------------------------"
echo $REPO
echo $TOKEN
echo "--------------------------"

./config.sh --url https://github.com/${REPO} --token ${TOKEN}

cleanup() {
    echo "Removing runner..."
    ./config.sh remove --unattended --token ${TOKEN}
}

trap 'cleanup; exit 130' INT
trap 'cleanup; exit 143' TERM

./run.sh & wait $!
