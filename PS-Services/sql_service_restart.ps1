[CmdletBinding(SupportsShouldProcess,DefaultParameterSetName='NoServerNameFile')]
param (
    [Parameter(Mandatory,Position=0,ParameterSetName='UsingServerNamesFile')]
    [ValidateScript({$ret = Test-Path -LiteralPath $_ -PathType Leaf; if (!$ret) {throw "Cannot find config file: '$_'"} return $ret})]
    [string]$ServerNamesFile
)

if ($PSCmdlet.ParameterSetName -eq 'UsingServerNamesFile') {
    # Read the input file
    $lines = Get-Content $ServerNamesFile
    $OutputPath = Split-Path $ServerNamesFile -Parent -Resolve
} else {
    $lines = @('.') # just an array meaning 'this computer'
    $OutputPath = $PSScriptRoot
}

$OutputFileName = "report_{0:yyyy-MM-dd_hh-mm-ss}.txt" -f [datetime]::Now
$OutputFilePath = Join-Path $OutputPath $OutputFileName

# process for each line of the file
foreach ($line in $lines) {
    $serverName = $line.Trim()
    Write-Verbose "Server ........ : $serverName"

    $services = Get-Service -DisplayName 'SQL Server*' -ComputerName $serverName
    foreach ($service in $services) {
        Write-Verbose "  Service ..... : $($service.DisplayName)"
        Write-Verbose "    Startup ... : $($service.StartType)"
        Write-Verbose "    Status .... : $($service.Status)"
        Write-Verbose "    Dependencies: $($service.ServicesDependedOn.DisplayName)"
        if (($service.StartType -eq 'Automatic') -and ($service.Status -eq 'Stopped') -and ($service.ServicesDependedOn.StartType -notcontains 'Manual')) {

            if ($PSCmdlet.ShouldProcess("$($service.DisplayName) on $($service.MachineName)",'Restart Service')) {
                $service | Start-Service
            }
        } elseif ($service.Status -ne 'Running') {
            $notStarted                           =  "Service $($service.DisplayName)"
            if($serverName -ne '.') {$notStarted += " on computer $serverName"}
            $notStarted                          += " was not started because:`n"
            if($service.StartType -ne 'Automatic') {$notStarted += "...it is not set to Automatic (current setting: " + $service.StartType + ")`n"}
            if($service.Status    -ne 'Stopped'  ) {$notStarted += "...it is not Stopped          (current setting: " + $service.Status +")`n"}
            if($service.ServicesDependedOn.StartType -contains 'Manual') {$notStarted += "...it depends on a Manual service`n"}
            Add-Content -Path $OutputFilePath -Value $notStarted
        }
    }
}
