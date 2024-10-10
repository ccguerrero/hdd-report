# Iterate over each computer in the list
ForEach ($line in Get-Content "SchoolFS.txt") {
    
    # Run the command on the remote computer
    $allFiles = Invoke-Command -ComputerName $line -ScriptBlock {
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
                default { return "Other" }
            }
        }

        $drives = @("E:\", "F:\", "P:\")

        $allFiles = @()

        foreach ($drive in $drives) {
            Write-Host "processing drive $drive for $env:COMPUTERNAME"
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
                            Write-Host "Error processing file: $($_.FullName) - $($_.Exception.Message)"
                        }
                    }

                $allFiles += $files
            }
        }

        return $allFiles
    }

    # Check if we got any data back
    if ($allFiles) {
        # Export data to CSV file locally
        $outputPath = "FS_files_${line}.csv"
        $allFiles | Export-Csv -Path $outputPath -NoTypeInformation -Encoding UTF8
        Write-Host "CSV file created for $line at $outputPath"
    } else {
        Write-Host "No data returned from $line."
    }
}