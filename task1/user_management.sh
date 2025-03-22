#!/bin/bash

LOG_FILE="/var/log/user_script.log"
CSV_FILE="$1"

# This is the function to log messages
log_message() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# It will check if running inside Docker
if ! grep -q docker /proc/1/cgroup; then
    log_message "Error: This script must be run inside a Docker container."
    exit 1
fi

# this function will insure script is run as root
if [[ $EUID -ne 0 ]]; then
    log_message "Error: This script must be run as root."
    exit 1
fi

# this function to download remote CSV if needed
if [[ "$CSV_FILE" == http* ]]; then
    log_message "Downloading CSV file from: $CSV_FILE"
    wget -O /tmp/users.csv "$CSV_FILE"
    CSV_FILE="/tmp/users.csv"
fi

# This is to verify CSV file exists
if [[ ! -f "$CSV_FILE" ]]; then
    log_message "Error: CSV file not found."
    exit 1
fi

log_message "Processing user accounts from $CSV_FILE"

# Read and process CSV file, skipping the header
tail -n +2 "$CSV_FILE" | while IFS=, read -r email birthdate groups shared_folder || [[ -n "$email" ]]; do
    # Skip e
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

    # This function is responsible of creating and assigning groups
IFS=';' read -ra GROUPS_ARRAY <<< "$groups"
for group in "${GROUPS_ARRAY[@]}"; do
    if ! getent group "$group" &> /dev/null; then
        log_message "Creating group: $group"
        groupadd "$group"
    fi
    usermod -aG "$group" "$username"
done

# Create shared folder if it doesn't exist
if [[ -n "$shared_folder" && ! -d "$shared_folder" ]]; then
    log_message "Creating shared folder: $shared_folder"
    mkdir -p "$shared_folder"
    chmod 770 "$shared_folder"
fi

# Ensure correct group permissions for shared folder
if [[ -n "$shared_folder" && -n "${GROUPS_ARRAY[0]}" ]]; then
    chown ":${GROUPS_ARRAY[0]}" "$shared_folder"  # Assign to the first group
    chmod 770 "$shared_folder"

    # create symbolic link in user's home directory
    ln -sf "$shared_folder" "$user_home/shared"
fi

log_message "User $username setup completed."
done

log_message "User creation process done."


