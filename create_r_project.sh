#!/bin/bash

# create_r_analysis_project.sh
# Usage: ./create_r_analysis_project.sh --image <IMAGE[:TAG]>
# Optional environment variables:
#   projects_dir, user_name, user_password, container_name, host_port

set -e

# Default values
projects_dir="${projects_dir:-projects}"
user_name="${user_name:-myuser}"
user_password="${user_password:-mypass123}"
container_name="${container_name:-r_analysis}"
host_port="${host_port:-8787}"
image=""

# Parse arguments
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --image)
      image="$2"
      shift
      ;;
    --projects_dir)
      projects_dir="$2"
      shift
      ;;
    --user_name)
      user_name="$2"
      shift
      ;;
    --user_password)
      user_password="$2"
      shift
      ;;
    --container_name)
      container_name="$2"
      shift
      ;;
    --host_port)
      host_port="$2"
      shift
      ;;
    *)
      echo "Unknown parameter passed: $1"
      echo "Usage: $0 --image <IMAGE[:TAG]>"
      echo "Optional arguments:"
      echo "  --projects_dir: Directory to hold projects (default: projects)"
      echo "  --user_name: RStudio user name (default: myuser)"
      echo "  --user_password: RStudio user password (default: mypass123)"
      echo "  --container_name: Name of the Docker container (default: r_analysis)"
      echo "  --host_port: Port to expose RStudio server (default: 8787)"
      exit 1
      ;;
  esac
  shift
done

if [ -z "$image" ]; then
  echo "Usage: $0 --image <IMAGE[:TAG]>"
  echo "Optional arguments:"
  echo "  --projects_dir: Directory to hold projects (default: projects)"
  echo "  --user_name: RStudio user name (default: myuser)"
  echo "  --user_password: RStudio user password (default: mypass123)"
  echo "  --container_name: Name of the Docker container (default: r_analysis)"
  echo "  --host_port: Port to expose RStudio server (default: 8787)"
  exit 1
fi

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
    image: ${image}
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