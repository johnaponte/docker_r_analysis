#!/bin/bash

# create_r_analysis_project.sh
# Usage: ./create_r_analysis_project.sh <image> <tag>
# Optional environment variables:
#   projects_dir, user_name, user_password, container_name, host_port

set -e

# Default values
projects_dir="${projects_dir:-projects}"
user_name="${user_name:-myuser}"
user_password="${user_password:-mypass123}"
container_name="${container_name:-r_analysis}"
host_port="${host_port:-8787}"

if [ "$#" -ne 2 ]; then
  echo "Usage: $0 <image> <tag>"
  echo "Optional environment variables:"
  echo "  projects_dir, user_name, user_password, container_name, host_port"
  exit 1
fi

image="$1"
tag="$2"

# Create project directory
mkdir -p "${projects_dir}"

# Create .gitignore
cat <<EOF > .gitignore
.DS_Store
.env
# Each project must have its own git repository
projects
EOF

# Create .env
cat <<EOF > .env
USER_NAME=${user_name}
USER_PASSWORD=${user_password}
EOF

# Create docker-compose.yml
cat <<EOF > docker-compose.yml
services:
  rstudio:
    image: r_analysis_${image}:${tag}
    container_name: ${container_name}
    ports:
      - "${host_port}:8787"
    environment:
      USER_NAME: "\${USER_NAME}"
      USER_PASSWORD: "\${USER_PASSWORD}"
    volumes:
      - "./projects:/home/\${USER_NAME}"
    restart: unless-stopped
EOF

echo "R analysis project initialized"
echo "Please customize .env and docker-compose.yml"