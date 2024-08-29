#!/bin/bash

# Check if a file parameter is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <source_file>"
    exit 1
fi

source_file="$1"

# Initialize associative array for folder totals
declare -A folder_totals
declare -A folder_size
declare -A folder_unit

# Initialize array of folder names
folders=("Videos" "Pictures" "Music" "Downloads" "Documents" "Desktop")

# Read the file and sum up the sizes in bytes for each specified folder
while IFS= read -r line; do
    if [[ $line =~ ^d-r--- ]]; then
        size=$(echo $line | grep -oP '([0-9]+(\.[0-9]+)?)')
        unit=$(echo $line | grep -oP '([KMGT]B|B)')

        case $unit in
            B) size=$(echo "$size" | bc) ;;
            KB) size=$(echo "$size * 1024" | bc) ;;
            MB) size=$(echo "$size * 1024 * 1024" | bc) ;;
            GB) size=$(echo "$size * 1024 * 1024 * 1024" | bc) ;;
            TB) size=$(echo "$size * 1024 * 1024 * 1024 * 1024" | bc) ;;
        esac

        for folder in "${folders[@]}"; do
            if [[ $line =~ $folder ]]; then
                folder_size[$folder]+="$size "
		folder_unit[$folder]+="$unit "
                folder_totals[$folder]=$(echo "${folder_totals[$folder]:-0} + $size" | bc)
            fi
        done
    fi
done < "$source_file"

# Output the sizes and units found for each folder in a CSV-compatible format
echo "Folder,Total Size in B"  # CSV header

for folder in "${folders[@]}"; do
    total_size="${folder_totals[$folder]}"
    echo "$folder,$total_size"
done

# Calculate and output the total size of all folders combined in human-readable format
total_size=0
for folder in "${folders[@]}"; do
    total_size=$(echo "$total_size + ${folder_totals[$folder]:-0}" | bc)
done

# Function to convert bytes to a human-readable format
human_readable() {
    local size=$1
    local units=("B" "KB" "MB" "GB" "TB" "PB" "EB")
    local unit_index=0

    while (( $(echo "$size >= 1024" | bc -l) )); do
        size=$(echo "scale=2; $size / 1024" | bc)
        ((unit_index++))
    done

    echo "$size ${units[$unit_index]}"
}

total_human_size=$(human_readable $total_size)
echo "Total,$total_human_size"  # Output total line in human-readable 
