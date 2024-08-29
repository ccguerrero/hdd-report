#!/bin/bash

# Check if a file parameter is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <source_file>"
    exit 1
fi
source_file="$1"
output_file="output2.csv"

# Extract the number after 's' in the source file name
school_number=$(echo "$source_file" | grep -oP '(?<=s)\d{2}')
printf "Processing file school number: %s\n" "$school_number"

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

convert_to_bytes() {
    local size="$1"
    local unit="$2"
    case $unit in
        B) echo "$size" | bc ;;
        KB) echo "$size * 1024" | bc ;;
        MB) echo "$size * 1024 * 1024" | bc ;;
        GB) echo "$size * 1024 * 1024 * 1024" | bc ;;
        TB) echo "$size * 1024 * 1024 * 1024 * 1024" | bc ;;
        *) echo 0 ;;  # Default to 0 if no valid unit is found
    esac
}

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
declare -A total_used

# Initialize array of folder names
folders=("-NLE" "*ToBeDeleted*")
# Initialize total used variable
total_used=0

# Read the file and sum up the sizes in bytes for each specified folder
while IFS= read -r line; do
    if [[ $line =~ ^[A-Z]:\\ ]]; then
        # Extract the third value (Used (GB))
        used_gb=$(echo $line | awk '{print $3}')
        
        # Convert the value to bytes (assuming it's in GB)
        used_bytes=$(echo "$used_gb * 1024 * 1024 * 1024" | bc)
        
        # Add to the total used
        total_used=$(echo "$total_used + $used_bytes" | bc)
    elif [[ $line =~ ^d-[r-]--- ]]; then
        #size=$(echo $line | grep -oP '([0-9]+(\.[0-9]+)?)' | head -n 1)
        size=$(echo $line | awk '{print $2}')
        #printf "Size: %s\n" "$size"
        unit=$(echo $line | grep -oP '([KMGT]B|B)' | head -n 1)
        #printf "Unit: %s\n" "$unit"

        # case $unit in
        #     B) size=$(echo "$size" | bc) ;;
        #     KB) size=$(echo "$size * 1024" | bc) ;;
        #     MB) size=$(echo "$size * 1024 * 1024" | bc) ;;
        #     GB) size=$(echo "$size * 1024 * 1024 * 1024" | bc) ;;
        #     TB) size=$(echo "$size * 1024 * 1024 * 1024 * 1024" | bc) ;;
        # esac
        size_in_bytes=$(convert_to_bytes "$size" "$unit")
        #printf "1Size in B: %s\n" "$size_in_bytes"
 
        #for folder in "${folders[@]}"; do
            if [[ $line =~ '-NLE' ]]; then
                #printf "Line: %s \n" "$line"
                #printf "Size in B: %s\n" "$size_in_bytes"
                #folder_sizeNLE+="$size_in_bytes"
                folder_totalsNLE=$(echo "${folder_totalsNLE:-0} + $size_in_bytes" | bc)
                #printf "Adding %s to NLE\n" "$size_in_bytes"
                #printf "Total for NLE is %s\n"  "$folder_totalsNLE"
            fi
            if [[ $line =~ 'ToBeDeleted' ]]; then
                printf "Line: %s \n" "$line"
                printf "2Size in B: %s \n" "$size_in_bytes"
                #folder_sizeGraduated+="$size_in_bytes"
                folder_totalsGraduates=$(echo "${folder_totalsGraduates:-0} + $size_in_bytes" | bc)
                printf "Adding %s to Graduated\n" "$size_in_bytes"
                printf "Total for Graduated is %s\n" "$folder_totalsGraduates"
            fi
        #done
    fi
done < "$source_file"

# # Output the sizes and units found for each folder in a CSV-compatible format
# echo "Location,Used,NLE,ToBeDeleted,Total storage"  # CSV header

# for folder in "${folders[@]}"; do
#     total_size="${folder_totals[$folder]}"
#     echo "$folder,$total_size"
# done

# # Calculate and output the total size of all folders combined in human-readable format
# total_size=0
# for folder in "${folders[@]}"; do
#     total_size=$(echo "$total_size + ${folder_totals[$folder]:-0}" | bc)
# done

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

# total_human_size=$(human_readable $total_size)
# echo "Total,$total_human_size"  # Output total line in human-readable

# Convert totals to GB for the output
total_used_gb=$(echo "scale=2; $total_used / (1024 * 1024 * 1024)" | bc)
nle_gb=$(echo "scale=2; ${folder_totalsNLE:-0} / (1024 * 1024 * 1024)" | bc)
tobedeleted_gb=$(echo "scale=2; ${folder_totalsGraduates:-0} / (1024 * 1024 * 1024)" | bc)
total_storage_gb=$(echo "scale=2; $total_used_gb - $nle_gb - $tobedeleted_gb" | bc)

# Output the result to a CSV file
# Write the header only if the output file doesn't exist
if [ ! -f "$output_file" ]; then
    echo "Location,Type,Used (GB),NLE (GB),ToBeDeleted (GB),Total storage (GB)" > "$output_file"
fi
#echo "Location,Used,NLE,ToBeDeleted,Total storage" > "$output_file"
echo "$location,SchoolFS,$total_used_gb,$nle_gb,$tobedeleted_gb,$total_storage_gb" >> "$output_file"

echo "Results have been written to $output_file"