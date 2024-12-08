#!/bin/bash
yum update -y
amazon-linux-extras enable docker
yum install -y docker
systemctl start docker
systemctl enable docker
