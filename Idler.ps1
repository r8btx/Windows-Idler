<#
    Upon execution, the script does the following:
      1. Turns off the screen
      2. Locks Windows (requires authentication to unlock)
      3. Prevents sleep and hibernation modes
      4. Shuts down if unlocked
    To create a shortcut: cmd /c PowerShell Set-ExecutionPolicy Bypass -Scope Process;$path='SCRIPT_FOLDER\Idler.ps1';^& $path
#>

[CmdletBinding()]
param()

# Gets the last Windows logon timestamp
function Get-LastLogonString {
    return (Get-WmiObject -Class Win32_NetworkLoginProfile | 
        Where-Object { $_.Caption -eq [Environment]::UserName }).LastLogon
}

# Locks the Windows workstation
# @http://gallery.technet.microsoft.com/ScriptCenter/en-us/a2178d49-79cd-4b3d-918a-47e9c6800262
function Lock-Workstation {
    $signature = @'
    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool LockWorkStation();
'@

    $lockWorkStation = Add-Type -MemberDefinition $signature -Name "Win32LockWorkStation" -Namespace Win32Functions -PassThru
    $lockWorkStation::LockWorkStation() | Out-Null
}

Write-Host "Initializing Idler..."

# Type definition to turn off the display
# @https://powershellmagazine.com/2013/07/18/pstip-how-to-switch-off-display-with-powershell/
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
 
namespace Utilities {
    public static class Display {
        [DllImport("user32.dll", CharSet = CharSet.Auto)]
        private static extern IntPtr SendMessage(
            IntPtr hWnd,
            UInt32 Msg,
            IntPtr wParam,
            IntPtr lParam
        );
 
        public static void PowerOff() {
            SendMessage(
                (IntPtr)0xffff, // HWND_BROADCAST
                0x0112,         // WM_SYSCOMMAND
                (IntPtr)0xf170, // SC_MONITORPOWER
                (IntPtr)0x0002  // POWER_OFF
            );
        }
    }
}
'@

# Type definition for maintaining system awake
# @https://gist.github.com/CMCDragonkai/bf8e8b7553c48e4f65124bc6f41769eb
$code = @'
[DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)]
public static extern void SetThreadExecutionState(uint esFlags);
'@

# Requests that the other EXECUTION_STATE flags set remain in effect until
# SetThreadExecutionState is called again with the ES_CONTINUOUS flag set and
# one of the other EXECUTION_STATE flags cleared.
$ste = Add-Type -MemberDefinition $code -Name System -Namespace Win32 -PassThru
$ES_CONTINUOUS = [uint32]"0x80000000"
$ES_SYSTEM_REQUIRED = [uint32]"0x00000001"

$lastLogonString = Get-LastLogonString

try {
    Write-Host "Activating Idler..."
    [Utilities.Display]::PowerOff()
    Lock-Workstation
    $ste::SetThreadExecutionState($ES_CONTINUOUS -bor $ES_SYSTEM_REQUIRED)

    do {
        Start-Sleep -Seconds 1
    } until ($lastLogonString -ne (Get-LastLogonString))

}
finally {
    Write-Host "Deactivating Idler..."
    $ste::SetThreadExecutionState($ES_CONTINUOUS)
    Write-Host "STOPPED."
}
