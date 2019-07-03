Param(
    [string]$instName # {#INST} macro from Zabbix
  , [string]$errorLogPath # {#ERRORLOG} macro from Zabbix
)

$ErrorActionPreference = "Stop"

#$bookmarkFileName = ('C:\Zabbix_Agent\zabbix_errorlog_bookmark_MSSQL${0}' -f $instName)
$bookmarkFileName = ('{0}\zabbix_errorlog_bookmark_MSSQL${1}' -f $env:USERPROFILE, $instName)

$errorLogPath = $errorLogPath.Replace("'","")

#Write-Output ('errorLogPath = {0}' -f $errorLogPath)
#Write-Output ('bookmarkFileName = {0}' -f $bookmarkFileName)


# Get the time of the last check from the bookmark file. This way we can return only errors logged since the last time Zabbix checked.
try {
    [datetime]$lastCheckTime = Get-Content $bookmarkFileName
} catch {
    # default to checking last minute (e.g. if first time this check has been run, or if someone deleted the bookmark file)
    [datetime]$lastCheckTime = (Get-Date).AddMinutes(-1)
}

# Now update the bookmark with the current time. (Do it now to minimize window for missing logged errors between checks.)
Write-Output (Get-Date).ToString('yyyy-MM-dd HH:mm:ss') | Out-File $bookmarkFileName

$recent_errors = @()

try {
    # use .NET streamreader to keep it lightweight with large errorlog files
    $logFile = [System.IO.File]::Open(('{0}' -f $errorLogPath), 'Open', 'Read', 'ReadWrite') # allows reading errorlog while SQL Server has it open for writes
    $logReader = New-Object System.IO.StreamReader($logFile)
    $errorFound = $false
    while (-not $logReader.EndOfStream) {
        # SQL Server logs 2 lines in errorlog for an error. The first line contains the error number, and severity & state codes.
        # The second line contains the actual message text that is necessary to understand the error.
        # Thus, we need to get two lines of log for each error.

        $line = $logReader.ReadLine()

        try {
            $lineTimestamp = [datetime]($line.Substring(0,22))
        } catch [System.Management.Automation.RuntimeException] { # log line doesn't begin with timestamp (e.g. log file header)
            $lineTimestamp = $null
        }

        if ($lineTimestamp -gt $lastCheckTime) {
            if ($true) {
                if ($errorFound) {
                    $recent_errors += $line
                    $errorFound = $false # reset to looking for first line of an error
                }
                elseif ([regex]::IsMatch($line, 'Error:') -and -not $errorFound) {
                    $recent_errors += $line
                    $errorFound = $true
                }
            }
        }
    }
} catch {
    throw
} finally {
    $logReader.Close()
    $logFile.Close()
}

return $recent_errors