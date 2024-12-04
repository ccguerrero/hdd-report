# Load file server names from the text file
$fileServers = Get-Content "SchoolFileServers.txt" | Where-Object { $_.Trim() -ne '' }

# Debug: Ensure the file servers are correctly loaded
Write-Host "File servers loaded: $($fileServers.Count)"
$fileServers | ForEach-Object {
    Write-Host "Server: '$($_)'"  # List the server names to check
} 

$fileServers | ForEach-Object -Parallel {
    param (
        $server  # Explicitly define the parameter to receive the value from the parent scope
    )

    # Debugging: Check the value of $line within the parallel block
    Write-Host "Processing server: $server"
    $allFiles = Invoke-Command -ComputerName $using:server -ScriptBlock { Get-Service -Name RpcSs }

    # Check if we got any data back
    if ($allFiles) {
        # Export data to CSV file locally
        $outputPath = "All_files_${server}.csv"
        $allFiles | Export-Csv -Path $outputPath -NoTypeInformation -Encoding UTF8
        Write-Host "CSV file created for $server at $outputPath"
    } else {
        Write-Host "No data returned from $server."
    }
} -ArgumentList $using:server -ThrottleLimit 4

