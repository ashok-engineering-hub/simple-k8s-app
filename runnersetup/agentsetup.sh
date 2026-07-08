#!/bin/bash

set -e

RUNNER_USER="githubrunner"
REPO_URL="https://github.com/ashok-engineering-hub/simple-k8s-app"
RUNNER_NAME="controlplane"
GITHUB_PAT="PAT"
RUNNER_TOKEN=$(curl -s -X POST   -H "Accept: application/vnd.github+json" -H "Authorization: Bearer $GITHUB_PAT"  https://api.github.com/repos/ashok-engineering-hub/simple-k8s-app/actions/
runners/registration-token | jq -r .token)

echo "Creating runner user..."

if ! id "$RUNNER_USER" >/dev/null 2>&1; then
    useradd -m -s /bin/bash "$RUNNER_USER"
fi

echo "Configuring Kubernetes access..."

mkdir -p /home/$RUNNER_USER/.kube

if [ -f /root/.kube/config ]; then
    cp /root/.kube/config /home/$RUNNER_USER/.kube/config
    chown -R $RUNNER_USER:$RUNNER_USER /home/$RUNNER_USER/.kube
    chmod 600 /home/$RUNNER_USER/.kube/config
fi

echo "Installing GitHub Actions runner..."

su - "$RUNNER_USER" << EOF

set -e

mkdir -p ~/actions-runner
cd ~/actions-runner

curl -o actions-runner-linux-x64-2.335.1.tar.gz -L \
https://github.com/actions/runner/releases/download/v2.335.1/actions-runner-linux-x64-2.335.1.tar.gz

echo "4ef2f25285f0ae4477f1fe1e346db76d2f3ebf03824e2ddd1973a2819bf6c8cf  actions-runner-linux-x64-2.335.1.tar.gz" | sha256sum -c

tar xzf actions-runner-linux-x64-2.335.1.tar.gz

chmod +x config.sh
chmod +x run.sh
chmod +x bin/*

./config.sh \
  --url "$REPO_URL" \
  --token "$RUNNER_TOKEN" \
  --unattended \
  --name "$RUNNER_NAME" \
  --labels self-hosted,Linux,X64

echo "Testing Kubernetes access..."
kubectl get nodes

echo "Starting runner..."
./run.sh

EOF
