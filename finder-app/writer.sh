#!/bin/bash

# Assigning command line arguments to variables
writefile="$1"
writestr="$2"

# Check if both arguments were provided
if [ -z "$writefile" ] || [ -z "$writestr" ]; then
    echo "Error: Missing arguments. Usage: $0 <path/to/file> <string to write>"
    exit 1
fi

# Creating the directory path if it doesn't exist
mkdir -p "$(dirname "$writefile")"

# Attempting to write to the file
echo "$writestr" > "$writefile"

if [ $? -ne 0 ]; then
    echo "Error: Could not write to file '$writefile'."
    exit 1
fi

echo "Write successful: '$writestr' > '$writefile'"
