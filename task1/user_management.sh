#!/bin/bash

LOG_FILE="/var/log/user_script.log"
CSV_FILE="$1"

# Function to log messages
log_message() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Check if running inside Docker
if ! grep -q docker /proc/1/cgroup; then
    log_message "Error: This script must be run inside a Docker container."
    exit 1
fi

# Ensure script is run as root
if [[ $EUID -ne 0 ]]; then
    log_message "Error: This script must be run as root."
    exit 1
fi

# Download remote CSV if needed
if [[ "$CSV_FILE" == http* ]]; then
    log_message "Downloading CSV file from: $CSV_FILE"
    wget -O /tmp/users.csv "$CSV_FILE"
    CSV_FILE="/tmp/users.csv"
fi

# Verify CSV file exists
if [[ ! -f "$CSV_FILE" ]]; then
    log_message "Error: CSV file not found."
    exit 1
fi

log_message "Processing user accounts from $CSV_FILE"

# Read and process CSV file, skipping the header
tail -n +2 "$CSV_FILE" | while IFS=, read -r email birthdate groups shared_folder || [[ -n "$email" ]]; do
    # Skip empty lines
    [[ -z "$email" ]] && continue

    # Extract the first name from the email to use as the username
    username="${email%%.*}"  # Extract everything before the first dot
    username="${username//[^a-zA-Z0-9]/}"  # Ensure only valid characters

    password="$(date -d "$birthdate" +'%m%Y')"
    user_home="/home/$username"

    # Create the user if not exists
    if id "$username" &>/dev/null; then
        log_message "User $username already exists. Skipping creation."
    else
        log_message "Creating user: $username"
        useradd -m -s /bin/bash "$username"
        echo "$username:$password" | chpasswd
    fi

    # Create and assign groups
    IFS=';' read -ra GROUPS_ARRAY <<< "$groups"
    for group in "${GROUPS_ARRAY[@]}"; do
        if ! getent group "$group" > /dev/null; then
            log_message "Creating group: $group"
            groupadd "$group"
        fi
        usermod -aG "$group" "$username"
    done

    # Create shared folder if not exists
    if [[ -n "$shared_folder" && ! -d "$shared_folder" ]]; then
        log_message "Creating shared folder: $shared_folder"
        mkdir -p "$shared_folder"
        chmod 770 "$shared_folder"
    fi

    # Ensure correct group permissions for shared folder
    if [[ -n "$shared_folder" ]]; then
        chown ":${GROUPS_ARRAY[0]}" "$shared_folder"  # Assign to the first group
        chmod 770 "$shared_folder"

        # Create symbolic link in user's home directory
        ln -sf "$shared_folder" "$user_home/shared"
    fi

    log_message "User $username setup completed."
done

log_message "User creation process completed."

