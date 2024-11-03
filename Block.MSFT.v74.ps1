# Start Maximized
Add-Type -TypeDefinition @"
    using System;
    using System.Runtime.InteropServices;

    public class WinAPI
    {
        [DllImport("user32.dll")]
        public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

        [DllImport("kernel32.dll")]
        public static extern IntPtr GetConsoleWindow();
    }
"@
$consolePtr = [WinAPI]::GetConsoleWindow()
[WinAPI]::ShowWindow($consolePtr, 3)  # 3 represents SW_MAXIMIZE

# Require administrative privileges
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))
{
    Write-Warning "You need to run this script as an Administrator."
    Read-Host "Press enter to exit"
    Exit 1
}

# Define the paths
$sourceHostsFile = Join-Path $PSScriptRoot "hosts.txt"
$windowsHostsFile = "$env:windir\System32\drivers\etc\hosts"
$backupHostsFile = "$windowsHostsFile.backup"
$ipRangesFile = Join-Path $PSScriptRoot "msft-public-ips-processed.csv"
$ruleName = "Block Microsoft IP Ranges"
$currentScriptPath = $MyInvocation.MyCommand.Path

function Defender-AddToExcusion {

# Get the full path of the currently running script

try {
    # Get current exclusions
    $currentExclusions = Get-MpPreference | Select-Object -ExpandProperty ExclusionPath

    # Check if the current script path is already in the exclusion list
    if ($currentExclusions -contains $currentScriptPath) {
        Write-Host "The script $currentScriptPath is already in the Windows Defender exclusion list."
    }
    else {
        # Add the current script to Windows Defender exclusion list
        Add-MpPreference -ExclusionPath $currentScriptPath -ErrorAction Stop
        Write-Host "Successfully added $currentScriptPath to Windows Defender exclusion list."
    }
}
catch {
    Write-Host "An error occurred: $_"
}
}

function Delete-Downloaded {
    Write-Host "Attempting to delete downloaded files..."

    $filesToDelete = @($sourceHostsFile, $ipRangesFile)

    foreach ($file in $filesToDelete) {
        if (Test-Path $file) {
            try {
                Remove-Item $file -Force -ErrorAction Stop
                Write-Host "Successfully deleted: $file"
            }
            catch {
                Write-Warning "Failed to delete $file. Error: $_"
            }
        }
        else {
            Write-Warning "File not found: $file"
        }
    }

    Write-Host "File deletion process completed."
}

# Function to download hosts file
function Download-HostsFile {
    $url = "https://raw.githubusercontent.com/schrebra/Windows.10.DNS.Block.List/main/hosts.txt"
    try {
        Invoke-WebRequest -Uri $url -OutFile $sourceHostsFile -ErrorAction Stop
        Write-Host "Hosts file successfully downloaded to: $sourceHostsFile"
    } catch {
        Write-Error "An error occurred while downloading the hosts file: $_"
    }
}

# Function to check if hosts file has been modified
function Get-HostsFileStatus {
    if (Test-Path $backupHostsFile) {
        try {
            $originalHash = Get-FileHash -Path $backupHostsFile -Algorithm MD5 -ErrorAction Stop
            $currentHash = Get-FileHash -Path $windowsHostsFile -Algorithm MD5 -ErrorAction Stop
            
            if ($originalHash.Hash -eq $currentHash.Hash) {
                return "Unmodified"
            } else {
                return "Modified"
            }
        } catch {
            Write-Error "Error checking hosts file status: $_"
            return "Unknown"
        }
    } else {
        return "Unknown (No backup file)"
    }
}

# Function to modify hosts file
function Modify-HostsFile {
    if (-not (Test-Path $sourceHostsFile)) {
        Write-Error "Source hosts.txt file not found at $sourceHostsFile"
        return
    }

    try {
        $dnsNames = Get-Content $sourceHostsFile -ErrorAction Stop
        $newEntries = $dnsNames | ForEach-Object { "127.0.0.1 $_" }

        if (-not (Test-Path $backupHostsFile)) {
            Copy-Item $windowsHostsFile $backupHostsFile -ErrorAction Stop
        }

        Add-Content -Path $windowsHostsFile -Value "`n# Entries added by script" -Force -ErrorAction Stop
        Add-Content -Path $windowsHostsFile -Value $newEntries -Force -ErrorAction Stop

        Write-Host "Hosts file has been successfully updated."
        Write-Host "A backup of the original file was created at $backupHostsFile"
        Write-Host "Added $(($newEntries).Count) new entries to the hosts file."
    }
    catch {
        Write-Error "An error occurred while modifying the hosts file: $_"
    }
}

# Function to restore hosts file
function Restore-HostsFile {
    if (Test-Path $backupHostsFile) {
        try {
            Copy-Item $backupHostsFile $windowsHostsFile -Force -ErrorAction Stop
            Write-Host "Hosts file has been successfully restored from the backup."
        }
        catch {
            Write-Error "An error occurred while restoring the hosts file: $_"
        }
    }
    else {
        Write-Warning "No backup file found. Cannot restore the hosts file."
    }
}

# Function to check IPv6 status
function Get-IPv6Status {
    try {
        $adapters = Get-NetAdapterBinding -ComponentID ms_tcpip6 -ErrorAction Stop
        $enabledCount = ($adapters | Where-Object { $_.Enabled -eq $true }).Count
        $totalCount = $adapters.Count
        
        if ($enabledCount -eq $totalCount) {
            return "Enabled on all adapters"
        }
        elseif ($enabledCount -eq 0) {
            return "Disabled on all adapters"
        }
        else {
            return "Enabled on $enabledCount out of $totalCount adapters"
        }
    } catch {
        Write-Error "Error checking IPv6 status: $_"
        return "Unknown"
    }
}

# Function to disable IPv6
function Disable-IPv6 {
    try {
        Get-NetAdapterBinding -ComponentID ms_tcpip6 -ErrorAction Stop | ForEach-Object { 
            Disable-NetAdapterBinding -Name $_.Name -ComponentID ms_tcpip6 -ErrorAction Stop
        }
        Write-Host "IPv6 has been disabled on all network adapters."
        $status = Get-IPv6Status
        Write-Host "Current IPv6 status: $status"
    }
    catch {
        Write-Error "An error occurred while disabling IPv6: $_"
    }
}

# Function to enable IPv6
function Enable-IPv6 {
    try {
        Get-NetAdapterBinding -ComponentID ms_tcpip6 -ErrorAction Stop | ForEach-Object { 
            Enable-NetAdapterBinding -Name $_.Name -ComponentID ms_tcpip6 -ErrorAction Stop
        }
        Write-Host "IPv6 has been enabled on all network adapters."
        $status = Get-IPv6Status
        Write-Host "Current IPv6 status: $status"
    }
    catch {
        Write-Error "An error occurred while enabling IPv6: $_"
    }
}

function Get-FirewallRuleStatus {
    try {
        $rule = Get-NetFirewallRule -DisplayName $ruleName -ErrorAction Stop
        return $rule.Enabled
    } catch {
        if ($_.Exception.GetType().FullName -eq "Microsoft.PowerShell.Cmdletization.Cim.CimJobException") {
            return "Not Found"
        } else {
            Write-Error "Error checking firewall rule status: $_"
            return "Unknown"
        }
    }
}

# Function to create firewall rules from IP ranges
function Create-FirewallRules {
    if (-not (Test-Path $ipRangesFile)) {
        Write-Error "IP ranges CSV file not found at $ipRangesFile"
        return
    }

    try {
        $ipRanges = Get-Content $ipRangesFile -ErrorAction Stop
                    
        if ($ipRanges.Count -eq 0) {
            Write-Warning "No valid IP ranges found in the CSV file."
            return
        }

        $existingRule = Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue

        if ($existingRule) {
            Remove-NetFirewallRule -DisplayName $ruleName -ErrorAction Stop
            Write-Host "Removed existing firewall rule: $ruleName"
        }

        New-NetFirewallRule -DisplayName $ruleName -Direction Outbound -Action Block -RemoteAddress $ipRanges -Enabled True -ErrorAction Stop
        Write-Host "Created new firewall rule: $ruleName"
        Write-Host "Blocked $(($ipRanges).Count) IP ranges."
    }
    catch {
        Write-Error "An error occurred while creating firewall rules: $_"
    }
}

# Function to enable the firewall rule
function Enable-FirewallRule {
    try {
        $rule = Get-NetFirewallRule -DisplayName $ruleName -ErrorAction Stop
        Set-NetFirewallRule -DisplayName $ruleName -Enabled True -ErrorAction Stop
        Write-Host "Firewall rule '$ruleName' has been enabled."
    } catch {
        if ($_.Exception.GetType().FullName -eq "Microsoft.PowerShell.Cmdletization.Cim.CimJobException") {
            Write-Warning "Firewall rule '$ruleName' does not exist. Please create it first."
        } else {
            Write-Error "An error occurred while enabling the firewall rule: $_"
        }
    }
}

# Function to disable the firewall rule
function Disable-FirewallRule {
    try {
        $rule = Get-NetFirewallRule -DisplayName $ruleName -ErrorAction Stop
        Set-NetFirewallRule -DisplayName $ruleName -Enabled False -ErrorAction Stop
        Write-Host "Firewall rule '$ruleName' has been disabled."
    } catch {
        if ($_.Exception.GetType().FullName -eq "Microsoft.PowerShell.Cmdletization.Cim.CimJobException") {
            Write-Warning "Firewall rule '$ruleName' does not exist. No action taken."
        } else {
            Write-Error "An error occurred while disabling the firewall rule: $_"
        }
    }
}

# Function to clear DNS cache and re-register DNS leases
function Reset-DNSConfiguration {
    try {
        # Clear DNS cache
        ipconfig /flushdns
        Write-Host "DNS cache has been cleared."

        # Re-register DNS
        ipconfig /registerdns
        Write-Host "DNS leases have been re-registered."

        Write-Host "DNS configuration has been reset successfully."
    }
    catch {
        Write-Error "An error occurred while resetting DNS configuration: $_"
    }
}

function Restart-ActiveNetworkAdapters {
    try {
        # Get all active network adapters, excluding those with "vmware" in the name
        $activeAdapters = Get-NetAdapter -ErrorAction Stop | Where-Object { 
            $_.Status -eq "Up" -and $_.Name -notmatch "vmware"
        }

        if ($activeAdapters.Count -eq 0) {
            Write-Host "No active non-VMware network adapters found."
            return
        }

        Write-Host "Found $($activeAdapters.Count) active network adapter(s)."

        foreach ($adapter in $activeAdapters) {
            Write-Host "`nRestarting network adapter: $($adapter.Name)"
            
            # Disable the adapter
            Write-Host "  Disabling adapter..."
            Disable-NetAdapter -Name $adapter.Name -Confirm:$false -ErrorAction Stop
            
            # Wait for a moment
            Start-Sleep -Seconds 5
            
            # Enable the adapter
            Write-Host "  Enabling adapter..."
            Enable-NetAdapter -Name $adapter.Name -Confirm:$false -ErrorAction Stop
            
            # Wait for the adapter to fully initialize
            Write-Host "  Waiting for adapter to initialize..."
            $timeout = 30
            $timer = [Diagnostics.Stopwatch]::StartNew()
            while (($timer.Elapsed.TotalSeconds -lt $timeout) -and ((Get-NetAdapter -Name $adapter.Name -ErrorAction Stop).Status -ne "Up")) {
                Start-Sleep -Seconds 1
            }
            $timer.Stop()
            
            if ((Get-NetAdapter -Name $adapter.Name -ErrorAction Stop).Status -eq "Up") {
                Write-Host "  Adapter is now up and running."
            } else {
                Write-Host "  Warning: Adapter did not reach 'Up' status within the timeout period."
            }
        }

        Write-Host "`nAll active network adapters have been restarted."
    }
    catch {
        Write-Error "An error occurred while restarting network adapters: $_"
    }
}

# Function to update Microsoft IP Ranges
function Update-MicrosoftIPRanges {
    $url = "https://download.microsoft.com/download/B/2/A/B2AB28E1-DAE1-44E8-A867-4987FE089EBE/msft-public-ips.csv"
    $outputPath = Join-Path -Path $PSScriptRoot -ChildPath "msft-public-ips.csv"
    $processedOutputPath = $ipRangesFile

    try {
        # Download the file
        Invoke-WebRequest -Uri $url -OutFile $outputPath -ErrorAction Stop
        Write-Host "File downloaded successfully to $outputPath"

        # Check if the file was downloaded
        if (-not (Test-Path $outputPath)) {
            throw "Downloaded file not found at $outputPath"
        }

        # Process the CSV file
        $content = @(Import-Csv -Path $outputPath -ErrorAction Stop | ForEach-Object {
            $_.Prefix.Trim()
        })

        # Check if content was extracted
        if ($content.Count -eq 0) {
            throw "No IP ranges were extracted from the CSV file"
        }
        
        # Save the processed content
        $content | Set-Content -Path $processedOutputPath -ErrorAction Stop

        # Check if the processed file was created
        if (-not (Test-Path $processedOutputPath)) {
            throw "Processed file was not created at $processedOutputPath"
        }

        Write-Host "Processed file saved to $processedOutputPath"
        Write-Host "Total IP ranges found: $($content.Count)"

        # Delete the original CSV file
        Remove-Item -Path $outputPath -Force -ErrorAction Stop
        Write-Host "Original CSV file deleted: $outputPath"

    } catch {
        Write-Error "An error occurred while updating Microsoft IP ranges: $_"
    }
}

# Function to perform Fast Block
function Perform-FastBlock {
    Write-Host "Performing Fast Block..."
    Defender-AddToExcusion
    Download-HostsFile
    Modify-HostsFile
    Disable-IPv6
    Update-MicrosoftIPRanges
    Create-FirewallRules
    Reset-DNSConfiguration
    Restart-ActiveNetworkAdapters
    Delete-Downloaded
    ""
    Write-Host "Fast Block completed." -ForegroundColor Green
}

# Function to perform Complete Unblock
function Perform-CompleteUnblock {
    Write-Host "Performing Complete Unblock..."
    Defender-AddToExcusion
    Restore-HostsFile
    Enable-IPv6
    Disable-FirewallRule
    Reset-DNSConfiguration
    Restart-ActiveNetworkAdapters
    ""
    Write-Host "Complete Unblock finished." -ForegroundColor Green
}

# Main menu loop
do {
    Clear-Host
    $ipv6Status = Get-IPv6Status
    $hostsFileStatus = Get-HostsFileStatus
    $firewallRuleStatus = Get-FirewallRuleStatus
    ""
    Write-Host "   === MSFT Configuration Manager ==="
    ""
    Write-Host "Current IPv6 Status: " -NoNewline
    if ($ipv6Status -eq "Disabled on all adapters") {
        Write-Host " $($ipv6Status)" -ForegroundColor Green
    } else {
        Write-Host " $($ipv6Status)" -ForegroundColor Yellow
    }
    Write-Host "Hosts File Status: " -NoNewline
    if ($hostsFileStatus -eq "Modified") {
        Write-Host "   $($hostsFileStatus)" -ForegroundColor Green
    } else {
        Write-Host "   $($hostsFileStatus)" -ForegroundColor Yellow
    }
    Write-Host "Firewall Rule Status: " -NoNewline
    if ($firewallRuleStatus -eq 'True') {
        Write-Host "Rule is active" -ForegroundColor Green
    } elseif ($firewallRuleStatus -eq 'False') {
        Write-Host "Rule is not enabled" -ForegroundColor Yellow
    } else {
        Write-Host "Rule does not exist" -ForegroundColor Yellow
    }
    ""
    Write-Host "1. Fast Block (Perform all blocking actions)"
    Write-Host "2. Complete Unblock (Undo all blocking actions)"
    Write-Host "3. Manual Actions"
    Write-Host "4. Exit"
    ""
    $choice = Read-Host "Enter your choice (1-4)"

    switch ($choice) {
        "1" { 
            Clear-Host
            Perform-FastBlock
            ""
            Read-Host "Press Enter to continue..."
        }
        "2" { 
            Clear-Host
            Perform-CompleteUnblock
            ""
            Read-Host "Press Enter to continue..."
        }
        "3" {
            do {
                Clear-Host
                Write-Host "=== Manual Actions ==="
                Write-Host "1. Download hosts file"
                Write-Host "2. Modify hosts file"
                Write-Host "3. Restore hosts file"
                Write-Host "4. Disable IPv6"
                Write-Host "5. Enable IPv6"
                Write-Host "6. Create/Update Firewall Rule"
                Write-Host "7. Enable Firewall Rule"
                Write-Host "8. Disable Firewall Rule"
                Write-Host "9. Restart Network adapters and DNS"
                Write-Host "10. Download Microsoft IP Ranges"
                Write-Host "11. Delete Downloaded Files"
                Write-Host "12. Return to Main Menu"
                ""
                $manualChoice = Read-Host "Enter your choice (1-12)"

                switch ($manualChoice) {
                    "1" { 
                        Clear-Host
                        Download-HostsFile
                        ""
                        Read-Host "Press Enter to continue..."
                    }
                    "2" { 
                        Clear-Host
                        Modify-HostsFile
                        ""
                        Read-Host "Press Enter to continue..."
                    }
                    "3" { 
                        Clear-Host
                        Restore-HostsFile
                        ""
                        Read-Host "Press Enter to continue..."
                    }
                    "4" { 
                        Clear-Host
                        Disable-IPv6
                        ""
                        Read-Host "Press Enter to continue..."
                    }
                    "5" { 
                        Clear-Host
                        Enable-IPv6
                        ""
                        Read-Host "Press Enter to continue..."
                    }
                    "6" { 
                        Clear-Host
                        Create-FirewallRules
                        ""
                        Read-Host "Press Enter to continue..."
                    }
                    "7" { 
                        Clear-Host
                        Enable-FirewallRule
                        ""
                        Read-Host "Press Enter to continue..."
                    }
                    "8" { 
                        Clear-Host
                        Disable-FirewallRule
                        ""
                        Read-Host "Press Enter to continue..."
                    }
                    "9" { 
                        Clear-Host
                        Reset-DNSConfiguration
                        Restart-ActiveNetworkAdapters
                        ""
                        Read-Host "Press Enter to continue..."
                    }
                    "10" { 
                        Clear-Host
                        Update-MicrosoftIPRanges
                        ""
                        Read-Host "Press Enter to continue..."
                    }
                    "11" { 
                        Clear-Host
                        Delete-Downloaded
                        ""
                        Read-Host "Press Enter to continue..."
                    }
                    "12" { 
                        break 
                    }
                    default { 
                        Clear-Host
                        Write-Host "Invalid choice. Please try again." 
                        Start-Sleep -Seconds 5
                    }
                }
            } while ($manualChoice -ne "12")
        }
        "4" { 
            Clear-Host
            ""
            Write-Host "Exiting..."
            break 
        }
        default { 
            Clear-Host
            ""
            Write-Host "Invalid choice. Please try again." 
            Start-Sleep -Seconds 2
        }
    }
} while ($choice -ne "4")
