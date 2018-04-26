## This script exists to grab all MSSQL instances running on
## a server, loop through them, and find the databases within
## them, returning a JSON string of the results.

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
                # Select all the database names within this instance  
                $SqlCmd.CommandText = "SELECT @@servicename as inst, name FROM  sysdatabases"
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
        #Write-Host "Error executing query on $fullInstance!"
        $DataSet = $null
    }

    # We get a list of databases. Append to the basename variable.
    if ($DataSet -ne $null){
        $basename = $basename + $DataSet.Tables[0]
    }
}

# So now $basename is full of our instance and database name rows
# We loop through them and print the results as a JSON string
$idx = 1
write-host "{"
write-host " `"data`":[`n"
foreach ($name in $basename)
{
    if ($idx -lt $basename.Rows.Count)
        {
            $line= "{ `"{#INST}`" : `"" + $name.inst + "`", "  + "`"{#DBNAME}`" : `"" + $name.name + "`" }," | convertto-encoding "cp866" "utf-8"
            write-host $line
        }
    # If this is the last row, we print a slightly different string - one without the trailing comma
    # Although I don't think the trailing comma would technically break JSON, this is the right way
    # to do it.
    elseif ($idx -ge $basename.Rows.Count)
        {
            $line= "{ `"{#INST}`" : `"" + $name.inst + "`", "  + "`"{#DBNAME}`" : `"" + $name.name + "`" }" | convertto-encoding "cp866" "utf-8"
            write-host $line
        }
    $idx++;
}
# Write our closing JSON brackets
 write-host
write-host " ]"
write-host "}"
 
