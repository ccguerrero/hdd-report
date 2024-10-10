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
#printf "Processing file school number: %s\n" "$school_number"

# Get the location (school name) from the CSV file
location=$(get_school_name "$school_number")
printf "Processing location file: %s\n" "$location"

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
        #size=$(echo $line | grep -oP '([0-9]+(\.[0-9]+)?)')
        size=$(echo $line | awk '{print $2}')
        unit=$(echo $line | grep -oP '([KMGT]B|B)')

        case $unit in
            B) size=$(echo "$size" | bc) ;;
            KB) size=$(echo "$size * 1024" | bc) ;;
            MB) size=$(echo "$size * 1024 * 1024" | bc) ;;
            GB) size=$(echo "$size * 1024 * 1024 * 1024" | bc) ;;
            TB) size=$(echo "$size * 1024 * 1024 * 1024 * 1024" | bc) ;;
        esac

        found=false
        for folder in "${folders[@]}"; do
            if [[ $line =~ (^|[^a-zA-Z0-9])$folder([^a-zA-Z0-9]|$) ]]; then
                folder_size[$folder]+="$size "
                folder_unit[$folder]+="$unit "
                folder_totals[$folder]=$(echo "${folder_totals[$folder]:-0} + $size" | bc)
                found=true
                break
            fi
        done

        if [[ $found == "false" && $line != *"│   │   │   ├──"* ]]; then
            other_totals=$(echo "${other_totals:-0} + $size" | bc)
        fi
    fi
done < "$source_file"

# Convert totals to GB for the output
for folder in "${folders[@]}"; do
    case $folder in
        Videos) video_totals=$(echo "scale=2; ${folder_totals[$folder]:-0}" | bc) ;;
        Pictures) pics_totals=$(echo "scale=2; ${folder_totals[$folder]:-0}" | bc) ;;
        Music) music_totals=$(echo "scale=2; ${folder_totals[$folder]:-0}" | bc) ;;
        Downloads) down_totals=$(echo "scale=2; ${folder_totals[$folder]:-0}" | bc) ;;
        Documents) docs_totals=$(echo "scale=2; ${folder_totals[$folder]:-0}" | bc) ;;
        Desktop) desk_totals=$(echo "scale=2; ${folder_totals[$folder]:-0}" | bc) ;;
    esac
done

#printf "Pics: %s B\n" "$pics_totals"
#printf "Music: %s B\n" "$music_totals"

# Write the header only if the output file doesn't exist
if [ ! -f "$output_file" ]; then
    echo "Location,Videos (B), Pictures (B),Music (B),Downloads (B),Documents (B),Desktop (B),Others (B),Total GB" > "$output_file"
fi

# Calculate the total size in GB
total=0
total=$(echo "scale=2; ${video_totals}+${pics_totals}+${music_totals}+${down_totals}+${docs_totals}+${desk_totals}+${other_totals}" | bc)
total=$(echo "scale=2; ${total}/(1024*1024*1024)" | bc)

# Output the result to a CSV file
echo "$location,$video_totals,$pics_totals,$music_totals,$down_totals,$docs_totals,$desk_totals,$other_totals,$total" >> "$output_file"

echo "Results have been written to $output_file"
