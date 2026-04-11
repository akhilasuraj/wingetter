# Winget-UI

Winget-UI is a GUI-based utility script written in PowerShell that simplifies the process of discovering and installing application updates via Windows Package Manager (`winget`).

## Features
- **Visual Interface:** Displays all available package updates on your system in a native Windows Form (GUI) with a checklist.
- **Batch Updates:** Allows you to select specific packages you want to update simultaneously.
- **Easy Selection:** Provides "Select All" and "Clear Selection" options for quicker management.
- **Auto-Elevation:** Automatically requests Administrator privileges if required, ensuring updates install reliably.

## Prerequisites
- Windows 10 or Windows 11
- [Windows Package Manager (winget)](https://learn.microsoft.com/en-us/windows/package-manager/winget/) installed.
- PowerShell 5.1 or newer.

## Usage

1. **Run directly from the web**:
   You can execute this script immediately without downloading or cloning by running this command in PowerShell:
   ```powershell
   irm "https://gist.githubusercontent.com/akhilasuraj/1003be9675118c0ac5db3e76edcb37b8/raw/winget-ui.ps1" | iex
   ```

2. **Run locally**:
   - Clone this repository or download the `winget-ui.ps1` file.
   - Navigate to the folder containing the script.
   - Right-click `winget-ui.ps1` and select **Run with PowerShell**.
   - **OR**, execute it directly from a PowerShell console:
     ```powershell
     .\winget-ui.ps1
     ```
3. **Approve Prompt**: If the script is not run as Administrator, it will prompt you with a standard User Account Control (UAC) window to elevate privileges. Click **Yes**.
4. **Select Packages**: 
   - A new window titled "Winget-UI - Select Packages to Update" will open, listing all available updates. 
   - Check the boxes next to the applications you wish to update.
5. **Update**: Click the **Update Selected** button. The script will close the window and sequentially run the update command for each application, displaying the progress in the PowerShell console.

## How it works
1. Runs `winget upgrade --disable-interactivity` to get a cleanly formatted list of available updates.
2. Parses the text output to extract the Package Name, ID, Current Version, and Available Version.
3. Builds an interactive graphical user interface using `System.Windows.Forms`.
4. Executes `winget upgrade --id "<ID>" --exact` for each selected application, showing the success or failure status in the console.
