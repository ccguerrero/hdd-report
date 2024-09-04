#!/bin/bash

# Function to get the school name from schools.csv
get_school_name() {
    local number="$1"
    local csv_file="schools.csv"
    while IFS=, read -r num name; do
        num=$(echo "$num" | tr -d '\r' | xargs)  # Removes carriage returns and trims whitespace
        name=$(echo "$name" | tr -d '\r' | xargs)
        # Strip leading zeros from the numbers for comparison
        stripped_num=$(echo "$num" | sed 's/^0*//')
        stripped_input=$(echo "$number" | sed 's/^0*//')

        # Check if the stripped number matches the input number
        if [ "$stripped_num" == "$stripped_input" ]; then
            echo "$num $name"
            return
        fi
    done < "$csv_file"
}
# Check if a file parameter is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <source_file>"
    exit 1
fi

source_file="$1"
output_file="folders_output.csv"

# Extract the number after 's' in the source file name
school_number=$(echo "$source_file" | grep -oP '(?<=s)\d{2}')
printf "Processing file school number: %s\n" "$school_number"

# Get the location (school name) from the CSV file
location=$(get_school_name "$school_number")

# If no match is found, set a default location
if [ -z "$location" ]; then
    location="Unknown School"
fi

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

# Convert totals to GB for the output
for folder in "${folders[@]}"; do
    case $folder in
        Videos) video_totals_gb=$(echo "scale=2; ${folder_totals[$folder]:-0} / (1024 * 1024 * 1024)" | bc) ;;
        Pictures) pics_totals_gb=$(echo "scale=2; ${folder_totals[$folder]:-0} / (1024 * 1024 * 1024)" | bc) ;;
        Music) music_totals_gb=$(echo "scale=2; ${folder_totals[$folder]:-0} / (1024 * 1024 * 1024)" | bc) ;;
        Downloads) down_totals_gb=$(echo "scale=2; ${folder_totals[$folder]:-0} / (1024 * 1024 * 1024)" | bc) ;;
        Documents) docs_totals_gb=$(echo "scale=2; ${folder_totals[$folder]:-0} / (1024 * 1024 * 1024)" | bc) ;;
        Desktop) desk_totals_gb=$(echo "scale=2; ${folder_totals[$folder]:-0} / (1024 * 1024 * 1024)" | bc) ;;
    esac
done

# Write the header only if the output file doesn't exist
if [ ! -f "$output_file" ]; then
    echo "Location,Videos (GB), Pictures (GB),Music (GB),Downloads (GB),Documents (GB),Desktop (GB)" > "$output_file"
    #echo ",Size (GB)," > "$output_file"
fi

# Output the result to a CSV file
#for folder in "${folders[@]}"; do
    echo "$location, $video_totals_gb,$pics_totals_gb,$music_totals_gb,$down_totals_gb,$docs_totals_gb,$desk_totals_gb" >> "$output_file"
#done

echo "Results have been written to $output_file"