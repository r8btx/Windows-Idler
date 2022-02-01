# This script prevents low-threat individuals (e.g. kids) from messing with your computer while leaving programs running in the background.
# Upon execution, the script does the following:
#   1. Turn off the screen
#   2. Lock down Windows (require authentication to log back on)
#   3. Prevent sleep and hibernation
#   4. If Windows is unlocked, the script will shut down automatically

# If you want to create a shortcut to this script, try the following:
# cmd /c PowerShell Set-ExecutionPolicy Bypass -Scope Process;$path='FOLDER CONTAINING THE SCRIPT\Idler.ps1';^& $path


Write-Host "Setting up Idler..."

# Display off @https://powershellmagazine.com/2013/07/18/pstip-how-to-switch-off-display-with-powershell/
Add-Type -TypeDefinition '
using System;
using System.Runtime.InteropServices;
 
namespace Utilities {
   public static class Display
   {
      [DllImport("user32.dll", CharSet = CharSet.Auto)]
      private static extern IntPtr SendMessage(
         IntPtr hWnd,
         UInt32 Msg,
         IntPtr wParam,
         IntPtr lParam
      );
 
      public static void PowerOff ()
      {
         SendMessage(
            (IntPtr)0xffff, // HWND_BROADCAST
            0x0112,         // WM_SYSCOMMAND
            (IntPtr)0xf170, // SC_MONITORPOWER
            (IntPtr)0x0002  // POWER_OFF
         );
      }
   }
}
'
# Lock Workstation @http://gallery.technet.microsoft.com/ScriptCenter/en-us/a2178d49-79cd-4b3d-918a-47e9c6800262
Function Lock-Workstation {
    $signature = @'
    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool LockWorkStation();
'@

    $LockWorkStation = Add-Type -memberDefinition $signature -name "Win32LockWorkStation" -namespace Win32Functions -passthru
    $LockWorkStation::LockWorkStation() | Out-Null
}

# Staying Awake @https://gist.github.com/CMCDragonkai/bf8e8b7553c48e4f65124bc6f41769eb
$Code=@'
[DllImport("kernel32.dll", CharSet = CharSet.Auto,SetLastError = true)]
public static extern void SetThreadExecutionState(uint esFlags);
'@

$ste = Add-Type -memberDefinition $Code -name System -namespace Win32 -passThru

# Requests that the other EXECUTION_STATE flags set remain in effect until
# SetThreadExecutionState is called again with the ES_CONTINUOUS flag set and
# one of the other EXECUTION_STATE flags cleared.
$ES_CONTINUOUS = [uint32]"0x80000000"
$ES_SYSTEM_REQUIRED = [uint32]"0x00000001"

try {

    Write-Host "Starting Idler..."

    [Utilities.Display]::PowerOff()
    Lock-Workstation
    $ste::SetThreadExecutionState($ES_CONTINUOUS -bor $ES_SYSTEM_REQUIRED)
    Start-Sleep -Seconds 2
    do {
        Start-Sleep -Seconds 1
    } until (!(Get-Process -Name LogonUI -ea 0))

} finally {

    Write-Host "Stopping Staying Awake..."
    $ste::SetThreadExecutionState($ES_CONTINUOUS)
    Write-Host "STOPPED."
}

