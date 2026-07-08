#!/bin/bash

set -e

# Create non-root user if it doesn't exist
if ! id githubrunner &>/dev/null; then
    useradd -m -s /bin/bash githubrunner
    echo "User githubrunner created."
else
    echo "User githubrunner already exists."
fi

# Execute remaining steps as githubrunner
su - githubrunner << 'EOF'

set -e

mkdir -p ~/actions-runner
cd ~/actions-runner

echo "Downloading GitHub Actions Runner..."

curl -o actions-runner-linux-x64-2.335.1.tar.gz -L \
https://github.com/actions/runner/releases/download/v2.335.1/actions-runner-linux-x64-2.335.1.tar.gz

echo "Verifying checksum..."

echo "4ef2f25285f0ae4477f1fe1e346db76d2f3ebf03824e2ddd1973a2819bf6c8cf  actions-runner-linux-x64-2.335.1.tar.gz" | sha256sum -c

echo "Extracting package..."

tar xzf actions-runner-linux-x64-2.335.1.tar.gz

echo "Configuring runner..."

./config.sh \
  --url https://github.com/ashok-engineering-hub \
  --token CHW7TJ3GXTD3POOHSNKR2MDKJYRY4 \
  --unattended \
  --name controlplane \
  --labels self-hosted,Linux,X64

echo "Starting runner..."

./run.sh

EOF
