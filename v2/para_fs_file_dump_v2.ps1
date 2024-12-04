# Load the list of servers from the file
$servers = Get-Content "SchoolFileServers.txt" | Where-Object { $_.Trim() -ne '' }

# Create a runspace pool
$runspacePool = [runspacefactory]::CreateRunspacePool(1, 5)  # Min 1, Max 5 threads
$runspacePool.Open()

# Store runspaces and their async results
$runspaces = @()

# Output and log file paths
$outputFilePath = "AllFiles.csv"
$logFilePath = "ProcessingLog.txt"

# Initialize the output file
if (Test-Path $outputFilePath) { Remove-Item $outputFilePath }
if (Test-Path $logFilePath) { Remove-Item $logFilePath }

Write-Host "Starting processing for $($servers.Count) servers..." -ForegroundColor Cyan

foreach ($server in $servers) {
    # Create a PowerShell instance and add the script block
    $runspace = [powershell]::Create().AddScript({
        param ($serverName, $outputFilePath, $logFilePath)

        # Informative logging
        Write-Host "Starting processing for server: $serverName" -ForegroundColor Green

        # Run the command on the remote computer
        try {
            $allFiles = Invoke-Command -ComputerName $serverName -ScriptBlock {
                # Function to categorize file extensions
                function Get-FileCategory {
                    param (
                        [string]$extension
                    )

                    switch ($extension.ToLower()) {
                        { $_ -in ".mp4", ".avi", ".mov", ".wmv" } { return "Video" }
                        { $_ -in ".mp3", ".wav", ".flac", ".aac" } { return "Audio" }
                        { $_ -in ".doc", ".docx", ".txt", ".rtf" } { return "Documents" }
                        { $_ -in ".xls", ".xlsx", ".csv" } { return "Spreadsheets" }
                        { $_ -in ".ppt", ".pptx" } { return "Presentations" }
                        ".pdf" { return "PDFs" }
                        { $_ -in ".exe", ".msi" } { return "Executables" }
                        { $_ -in ".zip", ".rar", ".7z", ".tar", ".gz" } { return "Compressed" }
                        default { return "Other" }
                    }
                }

                $drives = @("E:\", "F:\", "P:\")

                $allFiles = @()

                foreach ($drive in $drives) {
                    Write-Host "Processing drive $drive for $env:COMPUTERNAME" -ForegroundColor Yellow
                    $drivePath = "$drive"
                    if (Test-Path $drivePath) {
                        # Get file information recursively
                        $files = Get-ChildItem -Path $drivePath -Recurse -File -ErrorAction SilentlyContinue | 
                            ForEach-Object {
                                # Handle long paths by adding the \\?\ prefix
                                $fullPath = $_.FullName
                                if ($fullPath.Length -gt 260) {
                                    $fullPath = "\\?\$fullPath"
                                }

                                $FTcat = Get-FileCategory -extension $_.Extension

                                try {
                                    [pscustomobject]@{
                                        Drive                 = $drive
                                        FileName              = $_.Name
                                        FullPath              = $fullPath
                                        FileSizeKB            = [math]::Round($_.Length / 1KB, 2)
                                        FileType              = $_.Extension
                                        FileCategory          = $FTcat
                                        CreationTime          = $_.CreationTime
                                        LastModificationTime  = $_.LastWriteTime
                                        ParentFolder          = $_.DirectoryName
                                        Owner                 = (Get-Acl $_.FullName).Owner
                                    }
                                }
                                catch {
                                    Write-Host "Error processing file: $($_.FullName) - $($_.Exception.Message)" -ForegroundColor Red
                                    Add-Content -Path $logFilePath -Value "Error processing file: $($_.FullName) - $($_.Exception.Message)"
                                }
                            }

                        $allFiles += $files
                    } else {
                        Write-Host "Drive $drive does not exist on $env:COMPUTERNAME." -ForegroundColor Red
                        Add-Content -Path $logFilePath -Value "Drive $drive does not exist on $env:COMPUTERNAME."
                    }
                }

                return $allFiles
            }

            # Check if we got any data back
            if ($allFiles) {
                $allFiles | Export-Csv -Path $outputFilePath -NoTypeInformation -Encoding UTF8 -Append
                Write-Host "Data appended to CSV file for $serverName" -ForegroundColor Green
            } else {
                Write-Host "No data returned from $serverName or unable to connect." -ForegroundColor Yellow
                Add-Content -Path $logFilePath -Value "No data returned from $serverName or unable to connect."
            }
        }
        catch {
            Write-Host "Error while processing $serverName $_" -ForegroundColor Red
            Add-Content -Path $logFilePath -Value "Error while processing $serverName $_"
        }
        finally {
            Write-Host "Finished processing for server: $serverName" -ForegroundColor Cyan
        }
    }).AddArgument($server).AddArgument($outputFilePath).AddArgument($logFilePath)

    # Associate the runspace with the pool
    $runspace.RunspacePool = $runspacePool

    # Begin the invocation and store the async result
    $asyncResult = $runspace.BeginInvoke()
    $runspaces += [PSCustomObject]@{
        PowerShell = $runspace
        AsyncResult = $asyncResult
        Server = $server
    }
}

# Wait for all runspaces to complete
foreach ($runspace in $runspaces) {
    try {
        Write-Host "Waiting for completion of server: $($runspace.Server)" -ForegroundColor Cyan
        $runspace.PowerShell.EndInvoke($runspace.AsyncResult)
        Write-Host "Completed server: $($runspace.Server)" -ForegroundColor Green
    }
    catch {
        Write-Host "Error completing task for server $($runspace.Server): $_" -ForegroundColor Red
        Add-Content -Path $logFilePath -Value "Error completing task for server $($runspace.Server): $_"
    }
    finally {
        # Dispose of the runspace
        $runspace.PowerShell.Dispose()
    }
}

# Close and dispose of the runspace pool
$runspacePool.Close()
$runspacePool.Dispose()

Write-Host "All tasks completed." -ForegroundColor Magenta
Add-Content -Path $logFilePath -Value "All tasks completed."
