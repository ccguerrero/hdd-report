import csv
import re

# Input and output file paths
input_file = '/mnt/data/s0201_storage_report.txt'
output_file = '/mnt/data/storage_report.csv'

# Regex patterns for extracting file details
file_pattern = re.compile(r'-[ah]+-?\s+([\d.]+\s+\w+)\s+(├──|│|└──)?\s+(.+)')
drive_pattern = re.compile(r'Source: ([A-Z]):\\')

# Initialize variables
current_drive = None
files_data = []

# Read the input file and parse data
with open(input_file, 'r') as infile:
    for line in infile:
        # Check for drive letter
        drive_match = drive_pattern.search(line)
        if drive_match:
            current_drive = drive_match.group(1)
        
        # Check for file details
        file_match = file_pattern.search(line)
        if file_match:
            size = file_match.group(1).strip()
            filepath = file_match.group(3).strip()
            file_name = filepath.split('/')[-1]
            filetype = file_name.split('.')[-1] if '.' in file_name else ''
            files_data.append([file_name, filetype, size, current_drive, filepath])

# Write the data to a CSV file
with open(output_file, 'w', newline='') as csvfile:
    csvwriter = csv.writer(csvfile)
    csvwriter.writerow(['file name', 'filetype (extension)', 'size', 'drive letter', 'filepath'])
    csvwriter.writerows(files_data)

print(f'Data has been written to {output_file}')
