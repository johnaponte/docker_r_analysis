#!/bin/bash

# Environment variables (with defaults)
USER_NAME=${USER_NAME:-rstudio}
USER_PWD=${USER_PWD:-rstudio}

# Create user if it doesn't exist
if id "$USER_NAME" &>/dev/null; then
    echo "User $USER_NAME already exists"
else
    # Create user with home directory
    useradd -m "$USER_NAME"

    # Set user password
    echo "$USER_NAME:$USER_PWD" | chpasswd

    # Add user to 'staff' group (optional, depending on your use case)
    adduser "$USER_NAME" staff

    echo "User $USER_NAME created with password $USER_PWD"

    # Add user to sudo group
    usermod -aG sudo "$USER_NAME"

    # Allow passwordless sudo (common in Docker containers)
    echo "$USER_NAME ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
fi

# Start RStudio Server
exec /init