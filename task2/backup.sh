#!/bin/bash

    # Function to display usage instructions
usage() {
    echo "Usage: $0 <directory_to_backup>"
    exit 1
}

# Function to check if a directory argument is provided
if [ -z "$1" ]; then
    echo "No directory provided. Please enter the directory name to backup:"
    read directory_to_backup
else
    directory_to_backup=$1
fi

# To check if the provided directory exists
if [ ! -d "$directory_to_backup" ]; then
    echo "The directory '$directory_to_backup' does not exist."
    exit 2
fi

# To get the backup destination directory from user input
echo "Enter the directory where you want to store the backup (*within the Docker container):"
read backup_directory

# 	Its to check if the backup directory exists, create if it doesn't
if [ ! -d "$backup_directory" ]; then
    echo "Directory does not exist. Creating directory '$backup_directory'."
    mkdir -p "$backup_directory"
fi

# This funtion define the backup filename with timestamp
backup_filename="backup_$(basename "$directory_to_backup")_$(date +'%Y%m%d%H%M%S').tar.gz"

# This will create a tar.gz archive of the provided directory
echo "Creating backup of '$directory_to_backup'..."
tar -czf "$backup_directory/$backup_filename" -C "$(dirname "$directory_to_backup")" "$(basename "$directory_to_backup")"

# Function to check if the backup was successful
if [ $? -eq 0 ]; then
    echo "Backup of '$directory_to_backup' was successfully created at '$backup_directory/$backup_filename'."
else
    echo "Error: Backup failed."
    exit 3
fi

