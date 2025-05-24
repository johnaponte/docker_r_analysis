#!/bin/bash

# Environment variables (with defaults)
USER_NAME=${USER_NAME:-rstudio}
USER_PASSWORD=${USER_PASSWORD:-rstudio}

# Create user if it doesn't exist
if id "$USER_NAME" &>/dev/null; then
    echo "User $USER_NAME already exists"
else
    # Create user with home directory
    useradd -m "$USER_NAME"

    # Set user password
    echo "$USER_NAME:$USER_PASSWORD" | chpasswd

    # Add user to 'staff' group (optional, depending on your use case)
    adduser "$USER_NAME" staff

    echo "User $USER_NAME created with password $USER_PASSWORD"

    # Add user to sudo group
    usermod -aG sudo "$USER_NAME"

    # Allow passwordless sudo (common in Docker containers)
    echo "$USER_NAME ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
fi

# Modify R_LIBS to include the user home as first enty
mkdir -p /home/$USER_NAME/R/library
chown -R $USER_NAME:$USER_NAME /home/$USER_NAME/R
export R_LIBS="~/R/library:${R_LIBS:-/usr/local/lib/R/site-library:/usr/local/lib/R/library}"

# Confirm rstudio run script is executable
chmod +x /etc/services.d/rstudio/run
chmod +x /etc/services.d/rstudio/finish

# Start RStudio Server
exec /init