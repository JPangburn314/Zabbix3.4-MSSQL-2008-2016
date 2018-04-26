# So this script works by accepting instance name and database name arguments,
# and checking whether that database is online
Param(
  [string]$instName,
  [string]$dbName
)

# This function converts from one encoding to another.
function convertto-encoding ([string]$from, [string]$to){
    begin{
        $encfrom = [system.text.encoding]::getencoding($from)
        $encto = [system.text.encoding]::getencoding($to)
    }
    process{
        $bytes = $encto.getbytes($_)
        $bytes = [system.text.encoding]::convert($encfrom, $encto, $bytes)
        $encto.getstring($bytes)
    }
}

# First, grab our hostname
$SQLServer = $(hostname.exe)
# Now, we find all services that start with MSSQL$ and loop through them
Get-Service | Where-Object {$_.Name -like 'MSSQL$*'}| ForEach-Object{
    # Take our service name string and massage it a bit,
    # we end up with SERVERNAME\INSTANCE
    $dirtyInstanceName = "$($_.Name)"
    $cleanInstanceSplit = $dirtyInstanceName -split "\$"
    $cleanInstance = $cleanInstanceSplit[1]
    $fullInstance = $SQLServer + "\$cleanInstance"

    ## Check to see if this instance matches the instance name that was
    ## passed on the command line. If not, skip it
    if ($fullInstance -notlike "*$instName*"){
        return
    }

    # Create a connection string to connect to this instance, on this server.
    # Turn on Integrated Security so we authenticate as the account running
    # the script without a prompt.
    $connectionString = "Server = $fullInstance; Integrated Security = True;"

    # Create a new connection object with that connection string
    $connection = New-Object System.Data.SqlClient.SqlConnection
    $connection.ConnectionString = $connectionString
    # Try to open our connection, if it fails we won't try to run any queries
    try{
        $connection.Open()
    }
    catch{
        #Write-Host "Error connecting to $fullInstance!"
        $DataSet = $null
        $connection = $null
  
    }
    try{
        # Only run our queries if connection isn't null
        if ($connection -ne $null){
                # Create a MSSQL request
                $SqlCmd = New-Object System.Data.SqlClient.SqlCommand
                # Select the current instance name and database status 
                # where database = the database that was passed on the cmdline
                $SqlCmd.CommandText = "SELECT @@servicename as inst, name, state_desc as state FROM  sys.databases WHERE name='$dbName' "
                $SqlCmd.Connection = $Connection
                $SqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter
                $SqlAdapter.SelectCommand = $SqlCmd
                $DataSet = New-Object System.Data.DataSet
                $SqlAdapter.Fill($DataSet) > $null
                $Connection.Close()
        }
    }
    catch{
        # If our query failed, set our dataset to null
        # Write-Host "Error executing query on $fullInstance!"
        $DataSet = $null
    }
    # We get a set of database statuses. Append them to the basename variable.
    if ($DataSet -ne $null){
        $basename = $basename + $DataSet.Tables[0]
    }
}

# Because of the type of discovery this is, Zabbix doesn't need the result to be
# formatted as JSON. So, we simply write out a string containing the result.
foreach ($thisRow in $basename)
{
    # Honestly, not sure why we're converting the encoding here, but in the
    # spirit of not fixing what isn't broken, I'm leaving it in
    $line = $thisRow.state | convertto-encoding "cp866" "utf-8"
    write-host $line
}