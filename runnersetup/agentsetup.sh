#!/bin/bash

set -euo pipefail

# ==========================================
# CONFIGURATION
# ==========================================

RUNNER_USER="githubrunner"
REPO_URL="https://github.com/ashok-engineering-hub/simple-k8s-app"
RUNNER_NAME="controlplane"

# Replace with your PAT
GITHUB_PAT="YOUR_GITHUB_PAT"

# ==========================================
# FETCH RUNNER TOKEN
# ==========================================

echo "Generating runner registration token..."

RUNNER_TOKEN=$(
curl -s -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer ${GITHUB_PAT}" \
  "https://api.github.com/repos/ashok-engineering-hub/simple-k8s-app/actions/runners/registration-token" \
| jq -r '.token'
)

if [ -z "$RUNNER_TOKEN" ] || [ "$RUNNER_TOKEN" = "null" ]; then
    echo "ERROR: Failed to obtain runner token."
    echo "Verify PAT permissions and repository access."
    exit 1
fi

echo "Runner token generated successfully."

# ==========================================
# CREATE RUNNER USER
# ==========================================

echo "Creating runner user..."

if ! id "$RUNNER_USER" >/dev/null 2>&1; then
    useradd -m -s /bin/bash "$RUNNER_USER"
    echo "User created: $RUNNER_USER"
else
    echo "User already exists."
fi

# ==========================================
# COPY KUBECONFIG
# ==========================================

echo "Configuring Kubernetes access..."

mkdir -p /home/$RUNNER_USER/.kube

if [ -f /root/.kube/config ]; then
    cp /root/.kube/config /home/$RUNNER_USER/.kube/config

    chown -R $RUNNER_USER:$RUNNER_USER /home/$RUNNER_USER/.kube

    chmod 700 /home/$RUNNER_USER/.kube
    chmod 600 /home/$RUNNER_USER/.kube/config

    echo "Kubeconfig copied successfully."
else
    echo "WARNING: /root/.kube/config not found."
fi

# ==========================================
# INSTALL RUNNER
# ==========================================

echo "Installing GitHub Actions Runner..."

su - "$RUNNER_USER" <<EOF

set -euo pipefail

mkdir -p ~/actions-runner

cd ~/actions-runner

if [ ! -f actions-runner-linux-x64-2.335.1.tar.gz ]; then
    curl -o actions-runner-linux-x64-2.335.1.tar.gz -L \
    https://github.com/actions/runner/releases/download/v2.335.1/actions-runner-linux-x64-2.335.1.tar.gz
fi

echo "4ef2f25285f0ae4477f1fe1e346db76d2f3ebf03824e2ddd1973a2819bf6c8cf  actions-runner-linux-x64-2.335.1.tar.gz" | sha256sum -c

tar xzf actions-runner-linux-x64-2.335.1.tar.gz

chmod +x config.sh
chmod +x run.sh

find ./bin -type f -exec chmod +x {} \;

# Remove existing configuration if present
if [ -f ".runner" ]; then
    ./config.sh remove --token "${RUNNER_TOKEN}" || true
fi

echo "Configuring runner..."

./config.sh \
    --url "${REPO_URL}" \
    --token "${RUNNER_TOKEN}" \
    --unattended \
    --replace \
    --name "${RUNNER_NAME}" \
    --labels "self-hosted,Linux,X64"

echo "Testing Kubernetes access..."

kubectl get nodes || true

echo "Starting runner..."

./run.sh

EOF
