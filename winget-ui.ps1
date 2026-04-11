<#
.SYNOPSIS
    Winget-UI - A GUI-based Winget update utility.

.DESCRIPTION
    This script runs `winget upgrade` to fetch available package updates on the system,
    displays them in a native Windows checklist using `Out-GridView`, and installs
    the selected updates.

.EXAMPLE
    .\winget-ui.ps1
#>

# Function to clear the screen and write a styled message
function Write-Header {
    param([string]$Message)
    Write-Host "`n=== $Message ===`n" -ForegroundColor Cyan
}

# Ensure Script is Running as Administrator
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Winget-UI requires Administrator privileges to update multiple applications reliably." -ForegroundColor Yellow
    Write-Host "Requesting elevation..." -ForegroundColor Cyan
    
    # Restart the script with Administrative privileges
    $processInfo = New-Object System.Diagnostics.ProcessStartInfo
    $processInfo.FileName = "powershell.exe"

    # When run via `irm | iex`, $PSCommandPath is empty (script is in-memory).
    # Save to a temp file so the elevated process has a file to execute.
    $scriptPath = $PSCommandPath
    if ([string]::IsNullOrEmpty($scriptPath)) {
        $scriptPath = Join-Path $env:TEMP "winget-ui_temp.ps1"
        $MyInvocation.MyCommand.ScriptBlock.ToString() | Set-Content -Path $scriptPath -Encoding UTF8
    }

    $processInfo.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""
    $processInfo.Verb = "runas"
    
    try {
        [System.Diagnostics.Process]::Start($processInfo) | Out-Null
    } catch {
        Write-Host "Failed to elevate privileges. Updates may not install correctly." -ForegroundColor Red
        # If the user cancels the UAC prompt, the script will simply exit.
    }
    exit
}

# --- Winget presence and version check ---
$wingetCmd = Get-Command winget -ErrorAction SilentlyContinue

if (-not $wingetCmd) {
    Write-Host "Windows Package Manager (winget) is not installed on this system." -ForegroundColor Red
    Write-Host ""
    Write-Host "To install winget, open the Microsoft Store and install 'App Installer'." -ForegroundColor Yellow
    $response = Read-Host "Open the Microsoft Store now? (Y/N)"
    if ($response -match '^[Yy]$') {
        Start-Process "ms-windows-store://pdp/?productid=9NBLGGH4NNS1"
    }
    Read-Host "`nPress Enter to exit"
    exit
}

Write-Host "Checking winget version..." -ForegroundColor Gray
$currentVersionStr = (winget --version).TrimStart('v')

try {
    $latestRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/microsoft/winget-cli/releases/latest" -TimeoutSec 5 -ErrorAction Stop
    $latestVersionStr = $latestRelease.tag_name.TrimStart('v')

    if ([version]$currentVersionStr -lt [version]$latestVersionStr) {
        Write-Host "winget v$currentVersionStr is installed, but v$latestVersionStr is available." -ForegroundColor Yellow
        $response = Read-Host "Update winget now before continuing? (Y/N)"
        if ($response -match '^[Yy]$') {
            Write-Host "Updating winget..." -ForegroundColor Cyan
            winget upgrade --id Microsoft.AppInstaller --exact
            if ($LASTEXITCODE -eq 0) {
                Write-Host "winget updated successfully. Please re-run Winget-UI." -ForegroundColor Green
            } else {
                Write-Host "winget update failed (exit code $LASTEXITCODE). Continuing with current version." -ForegroundColor Red
            }
            Read-Host "`nPress Enter to exit"
            exit
        }
        Write-Host "Skipping winget update. Continuing with v$currentVersionStr." -ForegroundColor Gray
        Write-Host ""
    } else {
        Write-Host "winget v$currentVersionStr is up to date." -ForegroundColor Green
    }
} catch {
    Write-Host "winget v$currentVersionStr is installed. (Could not check for updates - skipping)" -ForegroundColor Gray
}
# -----------------------------------------

Write-Header "Fetching Available Updates via Winget"
Write-Host "This might take a moment..." -ForegroundColor Gray

# Run winget upgrade and capture its output
# We suppress the progress bar to make parsing cleaner
$wingetOutput = winget upgrade --disable-interactivity --accept-source-agreements 2>&1

# Check if there are any updates available
if ($wingetOutput -match "No installed packages have available upgrades") {
    Write-Host "All installed packages are up to date! 🎉" -ForegroundColor Green
    Read-Host "`nPress Enter to exit"
    exit
}

# The first few lines of winget output are headers/separators
# We need to find the line that starts with "Name" to determine column widths
$headerLineIndex = -1
for ($i = 0; $i -lt $wingetOutput.Count; $i++) {
    if ($wingetOutput[$i] -match "^Name\s+Id\s+Version\s+Available") {
        $headerLineIndex = $i
        break
    }
}

if ($headerLineIndex -eq -1) {
    Write-Host "Failed to parse winget output. Please ensure winget is installed and working." -ForegroundColor Red
    Write-Host "`n--- Raw winget output (for diagnostics) ---" -ForegroundColor Yellow
    $wingetOutput | ForEach-Object { Write-Host $_ }
    Write-Host "-------------------------------------------`n" -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit
}

$headerLine = $wingetOutput[$headerLineIndex]
$idStart = $headerLine.IndexOf(" Id ") + 1
$versionStart = $headerLine.IndexOf(" Version ") + 1
$availableStart = $headerLine.IndexOf(" Available ") + 1

if ($idStart -le 0 -or $versionStart -le 0) {
    Write-Host "Failed to identify columns in winget output." -ForegroundColor Red
    Read-Host "`nPress Enter to exit"
    exit
}

$updates = @()

# Parse the packages
for ($i = $headerLineIndex + 2; $i -lt $wingetOutput.Count; $i++) {
    $line = $wingetOutput[$i]
    
    # Skip empty lines or the end summary (e.g., "X upgrades available.")
    if ([string]::IsNullOrWhiteSpace($line) -or $line -match "^\d+\s+upgrades\s+available") {
        continue
    }

    try {
        # Extract substrings based on header positions
        $name = $line.Substring(0, $idStart).Trim()
        
        $idLen =  $versionStart - $idStart
        $id = if ($line.Length -ge $versionStart) { $line.Substring($idStart, $idLen).Trim() } else { $line.Substring($idStart).Trim() }
        
        $versionLen = $availableStart - $versionStart
        $version = if ($line.Length -ge $availableStart) { $line.Substring($versionStart, $versionLen).Trim() } else { "" }
        
        $availableText = if ($line.Length -gt $availableStart) { $line.Substring($availableStart).Trim() } else { "" }
        # The remainder is 'Available' optionally followed by 'Source'. Take the first token.
        $available = ($availableText -split '\s+')[0]

        if (-not [string]::IsNullOrEmpty($id) -and $id -ne "Unknown" -and $id -ne "Id") {
            $updates += [PSCustomObject]@{
                Name             = $name
                Id               = $id
                'Current Version'= $version
                'Available Version'      = $available
            }
        }
    } catch {
        # ignore lines that are too short to be real packages
    }
}

if ($updates.Count -eq 0) {
    Write-Host "No updatable packages found after parsing." -ForegroundColor Yellow
    Read-Host "`nPress Enter to exit"
    exit
}

Write-Header "Select Packages to Update"
Write-Host "Opening selection window..."

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$form = New-Object System.Windows.Forms.Form
$form.Text = "Winget-UI - Select Packages to Update"
$form.Size = New-Object System.Drawing.Size(800, 600)
$form.StartPosition = "CenterScreen"
$form.MinimumSize = New-Object System.Drawing.Size(600, 400)

$listView = New-Object System.Windows.Forms.ListView
$listView.Location = New-Object System.Drawing.Point(10, 10)
$listView.Size = New-Object System.Drawing.Size(760, 480)
$listView.View = 'Details'
$listView.CheckBoxes = $true
$listView.FullRowSelect = $true
$listView.GridLines = $true
$listView.Anchor = 'Top, Bottom, Left, Right'

$listView.Columns.Add("Name", 300) | Out-Null
$listView.Columns.Add("Id", 200) | Out-Null
$listView.Columns.Add("Current Version", 100) | Out-Null
$listView.Columns.Add("Available Version", 100) | Out-Null

foreach ($app in $updates) {
    $item = New-Object System.Windows.Forms.ListViewItem($app.Name)
    $item.SubItems.Add($app.Id) | Out-Null
    $item.SubItems.Add($app.'Current Version') | Out-Null
    $item.SubItems.Add($app.'Available Version') | Out-Null
    $item.Tag = $app
    $listView.Items.Add($item) | Out-Null
}

$selectAllBtn = New-Object System.Windows.Forms.Button
$selectAllBtn.Location = New-Object System.Drawing.Point(10, 510)
$selectAllBtn.Size = New-Object System.Drawing.Size(100, 30)
$selectAllBtn.Text = "Select All"
$selectAllBtn.Anchor = 'Bottom, Left'
$selectAllBtn.Add_Click({
    foreach ($item in $listView.Items) {
        $item.Checked = $true
    }
})

$clearBtn = New-Object System.Windows.Forms.Button
$clearBtn.Location = New-Object System.Drawing.Point(120, 510)
$clearBtn.Size = New-Object System.Drawing.Size(120, 30)
$clearBtn.Text = "Clear Selection"
$clearBtn.Anchor = 'Bottom, Left'
$clearBtn.Add_Click({
    foreach ($item in $listView.Items) {
        $item.Checked = $false
    }
})

$updateBtn = New-Object System.Windows.Forms.Button
$updateBtn.Location = New-Object System.Drawing.Point(540, 510)
$updateBtn.Size = New-Object System.Drawing.Size(120, 30)
$updateBtn.Text = "Update Selected"
$updateBtn.DialogResult = 'OK'
$updateBtn.Anchor = 'Bottom, Right'
$form.AcceptButton = $updateBtn

$cancelBtn = New-Object System.Windows.Forms.Button
$cancelBtn.Location = New-Object System.Drawing.Point(670, 510)
$cancelBtn.Size = New-Object System.Drawing.Size(100, 30)
$cancelBtn.Text = "Cancel"
$cancelBtn.DialogResult = 'Cancel'
$cancelBtn.Anchor = 'Bottom, Right'
$form.CancelButton = $cancelBtn

$form.Controls.Add($listView)
$form.Controls.Add($selectAllBtn)
$form.Controls.Add($clearBtn)
$form.Controls.Add($updateBtn)
$form.Controls.Add($cancelBtn)

$form.Topmost = $true
$result = $form.ShowDialog()

$selectedUpdates = @()
if ($result -eq 'OK') {
    foreach ($item in $listView.Items) {
        if ($item.Checked) {
            $selectedUpdates += $item.Tag
        }
    }
}

if (-not $selectedUpdates -or $selectedUpdates.Count -eq 0) {
    exit
}

Write-Header "Installing Selected Updates"

# Run the upgrade for each selected item
foreach ($app in $selectedUpdates) {
    Write-Host "Upgrading $($app.Name) ($($app.Id))..." -ForegroundColor Cyan
    
    # Run the upgrade command
    # Using --exact prevents winget from getting confused by similar IDs
    winget upgrade --id "$($app.Id)" --exact
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Successfully upgraded $($app.Name)!`n" -ForegroundColor Green
    } else {
        Write-Host "Failed or partially failed to upgrade $($app.Name). Exit code: $LASTEXITCODE`n" -ForegroundColor Red
    }
}

Write-Header "All processes complete! 🎉"
Read-Host "Press Enter to exit"
