# Define the input and output file paths
$inputFilePath = "storage_sample.txt"
$outputFilePath = "parsed_report.csv"

# Initialize an array to store the parsed data
$parsedData = @()

# Function to convert GB to bytes
function Convert-GBToBytes {
    param (
        [float]$gb
    )
return [int64]($gb * 1GB)
}

# Read the file line by line
Get-Content -Path $inputFilePath | ForEach-Object {
    $line = $_

    # Skip lines that don't start with a drive letter
    if ($line -match '^[A-Za-z]:\\') {
        # Split the line by whitespace
        $parts = $line -split '\s+'

        # Extract the drive, total size, and total used
        $drive = $parts[0]
        $totalSizeGB = [float]$parts[1]
        $totalUsedGB = [float]$parts[2]

        # Convert sizes from GB to bytes
        $totalSize = Convert-GBToBytes -gb $totalSizeGB
        $totalUsed = Convert-GBToBytes -gb $totalUsedGB
    
        # Initialize variables for NLE and ToBeDeleted sizes
        $totalNLE = 0
        $totalToBeDeleted = 0
    } else {
        # Iterate over the rest of the parts to find NLE and ToBeDeleted sizes
        for ($i = 3; $i -lt $parts.Length; $i += 2) {
            $folderName = $parts[$i]
            $folderSizeWithUnit = $parts[$i + 1]

            try {
                $folderSize = Convert-ToBytes -sizeWithUnit $folderSizeWithUnit
        
                if ($folderName -match '-NLE\s*$') {
                    Write-Host "Matched line: $folderName"
                    $totalNLE += $folderSize
                } elseif ($folderName -match 'ToBeDeleted') {
                    Write-Host "Matched line: $folderName"
                    $totalToBeDeleted += $folderSize
                }
            } catch {
                Write-Host "Skipping invalid size format: $folderSizeWithUnit"
            }
        }
    }

        # Store the parsed data in the array
        $parsedData += [pscustomobject]@{
            Drive = $drive
            TotalSize = $totalSize
            TotalUsed = $totalUsed
            TotalNLE = $totalNLE
            TotalToBeDeleted = $totalToBeDeleted
        }
    }

# Export the parsed data to a CSV file
$parsedData | Export-Csv -Path $outputFilePath -NoTypeInformation

Write-Host "Parsed data has been saved to $outputFilePath"