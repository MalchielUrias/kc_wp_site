#!/bin/bash
sudo apt-get update -y
sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
sudo apt-get update -y
sudo apt-get install -y docker-ce
sudo usermod -aG docker ubuntu  # Add default user to the Docker group

# Install AWS SSM Agent via Snap
sudo snap install amazon-ssm-agent --classic

# Enable and start the SSM Agent service
sudo systemctl enable snap.amazon-ssm-agent.amazon-ssm-agent.service
sudo systemctl start snap.amazon-ssm-agent.amazon-ssm-agent.service

# Verify the SSM Agent status (optional)
sudo systemctl status snap.amazon-ssm-agent.amazon-ssm-agent.service