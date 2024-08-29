import csv
import re

# Input and output file paths
input_file = 's0201_storage_report.txt'
output_file = 'storage_report.csv'

# Regex patterns for extracting file details
#file_pattern = re.compile(r'(?:-a----)?\s*(\d+(\.\d+)?\s*[BKMG]B)\s*(?:│\s*)*├──\s*(.+)')
file_pattern = re.compile(r'(?:-a----)?\s*(\d+(\.\d+)?)\s*([BKMG]B)\s*(?:│\s*)*├──\s*(.+)')
drive_pattern = re.compile(r'Source: ([A-Z]):\\')

# Function to convert size to bytes
def size_to_bytes(size, unit):
    unit = unit.upper()  # Ensure unit is uppercase
    if unit == 'K':  # Handle 'K' as 'KB'
        unit = 'KB'
    unit_factors = {'B': 1, 'KB': 1024, 'MB': 1024**2, 'GB': 1024**3}
    return int(float(size) * unit_factors[unit])

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
            size, unit = file_match.group(1).strip(), file_match.group(3).strip()
            bytes_size = size_to_bytes(size, unit) if size and unit else "N/A"  # Convert size to bytes
            name_path = file_match.group(4).strip()
            file_name = name_path.split('/')[-1]
            filetype = file_name.split('.')[-1] if '.' in file_name else ''
            files_data.append([file_name, filetype, bytes_size, current_drive, name_path])

# Write the data to a CSV file
with open(output_file, 'w', newline='') as csvfile:
    csvwriter = csv.writer(csvfile)
    csvwriter.writerow(['file name', 'filetype (extension)', 'size', 'drive letter', 'filepath'])
    csvwriter.writerows(files_data)

print(f'Data has been written to {output_file}')
