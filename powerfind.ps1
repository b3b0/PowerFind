$1 = {
cls
$ip = Read-Host "Enter IP"
nslookup $ip
}

$10 = {
cls
$name = Read-Host "Enter Hostname"
ping $name
}

$2 = {
cls
$who = Read-Host "Enter Host Name"
Get-ADComputer $who –Properties Description | Select -ExpandProperty Description
}

$3 = {
cls
$user = Read-Host "Enter User Name"
Get-ADComputer -Filter "Description -like '*$user*'" -properties description | Select -ExpandProperty Name
}

$4 = {
cls
$superfind = Read-Host "Enter hostname"
Invoke-Command -ComputerName $superfind -Credential YOURDOMAIN\ -ScriptBlock {function Get-FolderSize {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true,
                   ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true)]
            [string[]] $Path,
        [int] $Precision = 4,
        [switch] $RoboOnly,
        [switch] $ComOnly,
        [ValidateRange(1, 128)] [byte] $RoboThreadCount = 16)
    begin {
        if ($RoboOnly -and $ComOnly) {
            Write-Error -Message "You can't use both -ComOnly and -RoboOnly. Default is COM with a fallback to robocopy." -ErrorAction Stop
        }
        if (-not $RoboOnly) {
            $FSO = New-Object -ComObject Scripting.FileSystemObject -ErrorAction Stop
        }
        function Get-RoboFolderSizeInternal {
            [CmdletBinding()]
            param(
                [string[]] $Path,
                [int] $Precision = 4)
            begin {
                if (-not (Get-Command -Name robocopy -ErrorAction SilentlyContinue)) {
                    Write-Warning -Message "Fallback to robocopy failed because robocopy.exe could not be found. Path '$p'. $([datetime]::Now)."
                    return
                }
            }
            process {
                foreach ($p in $Path) {
                    Write-Verbose -Message "Processing path '$p' with Get-RoboFolderSizeInternal. $([datetime]::Now)."
                    $RoboCopyArgs = @("/L","/S","/NJH","/BYTES","/FP","/NC","/NDL","/TS","/XJ","/R:0","/W:0","/MT:$RoboThreadCount")
                    [datetime] $StartedTime = [datetime]::Now
                    [string] $Summary = robocopy $p NULL $RoboCopyArgs | Select-Object -Last 8
                    [datetime] $EndedTime = [datetime]::Now
                    [regex] $HeaderRegex = '\s+Total\s*Copied\s+Skipped\s+Mismatch\s+FAILED\s+Extras'
                    [regex] $DirLineRegex = 'Dirs\s*:\s*(?<DirCount>\d+)(?:\s*\d+){3}\s*(?<DirFailed>\d+)\s*\d+'
                    [regex] $FileLineRegex = 'Files\s*:\s*(?<FileCount>\d+)(?:\s*\d+){3}\s*(?<FileFailed>\d+)\s*\d+'
                    [regex] $BytesLineRegex = 'Bytes\s*:\s*(?<ByteCount>\d+)(?:\s*\d+){3}\s*(?<BytesFailed>\d+)\s*\d+'
                    [regex] $TimeLineRegex = 'Times\s*:\s*(?<TimeElapsed>\d+).*'
                    [regex] $EndedLineRegex = 'Ended\s*:\s*(?<EndedTime>.+)'
                    if ($Summary -match "$HeaderRegex\s+$DirLineRegex\s+$FileLineRegex\s+$BytesLineRegex\s+$TimeLineRegex\s+$EndedLineRegex") {
                        $TimeElapsed = [math]::Round([decimal] ($EndedTime - $StartedTime).TotalSeconds, $Precision)
                        New-Object PSObject -Property @{
                            Path = $p
                            TotalBytes = [decimal] $Matches['ByteCount']
                            TotalMBytes = [math]::Round(([decimal] $Matches['ByteCount'] / 1MB), $Precision)
                            TotalGBytes = [math]::Round(([decimal] $Matches['ByteCount'] / 1GB), $Precision)
                            BytesFailed = [decimal] $Matches['BytesFailed']
                            DirCount = [decimal] $Matches['DirCount']
                            FileCount = [decimal] $Matches['FileCount']
                            DirFailed = [decimal] $Matches['DirFailed']
                            FileFailed  = [decimal] $Matches['FileFailed']
                            TimeElapsed = $TimeElapsed
                            StartedTime = $StartedTime
                            EndedTime   = $EndedTime

                        } | Select Path, TotalBytes, TotalMBytes, TotalGBytes, DirCount, FileCount, DirFailed, FileFailed, TimeElapsed, StartedTime, EndedTime
                    }
                    else {
                        continue
                    }
                }
            }
        }
    }
    process {
        foreach ($p in $Path) {
            Write-Verbose -Message "Processing path '$p'. $([datetime]::Now)."
            if (-not (Test-Path -Path $p -PathType Container)) {
                continue
            }
            if ($RoboOnly) {
                Get-RoboFolderSizeInternal -Path $p -Precision $Precision
                continue
            }
            $ErrorActionPreference = 'Stop'
            try {
                $StartFSOTime = [datetime]::Now
                $TotalBytes = $FSO.GetFolder($p).Size
                $EndFSOTime = [datetime]::Now
                if ($TotalBytes -eq $null) {
                    if (-not $ComOnly) {
                        Get-RoboFolderSizeInternal -Path $p -Precision $Precision
                        continue
                    }
                    else {
                        Write-Warning -Message "Failed to retrieve folder size for path '$p': $($Error[0].Exception.Message)."
                    }
                }
            }
            catch {
                if ($_.Exception.Message -like '*PERMISSION*DENIED*') {
                    if (-not $ComOnly) {
                        Write-Verbose "Caught a permission denied. Trying robocopy."
                        Get-RoboFolderSizeInternal -Path $p -Precision $Precision
                        continue
                    }
                    else {
                        Write-Warning "Failed to process path '$p' due to a permission denied error: $($_.Exception.Message)"
                    }
                }
                Write-Warning -Message "Encountered an error while processing path '$p': $_"
                continue
            }
            $ErrorActionPreference = 'Continue'
            New-Object PSObject -Property @{
                Path = $p
                TotalBytes = [decimal] $TotalBytes
                TotalMBytes = [math]::Round(([decimal] $TotalBytes / 1MB), $Precision)
                TotalGBytes = [math]::Round(([decimal] $TotalBytes / 1GB), $Precision)
                BytesFailed = $null
                DirCount = $null
                FileCount = $null
                DirFailed = $null
                FileFailed  = $null
                TimeElapsed = [math]::Round(([decimal] ($EndFSOTime - $StartFSOTime).TotalSeconds), $Precision)
                StartedTime = $StartFSOTime
                EndedTime = $EndFSOTime
            } | Select Path, TotalBytes, TotalMBytes, TotalGBytes, DirCount, FileCount, DirFailed, FileFailed, TimeElapsed, StartedTime, EndedTime
        }
    }
    end {
        if (-not $RoboOnly) {
            [void][System.Runtime.Interopservices.Marshal]::ReleaseComObject($FSO)
        }
        [gc]::Collect()
        [gc]::WaitForPendingFinalizers()
    }
}
$RoboSizes = gci c:\Users | % fullname | Get-FolderSize -RoboOnly
$BIGGEST = $RoboSizes | Sort TotalGBytes -Descending | select Path -ExpandProperty Path | select-object -first 1
Write-Host $BIGGEST}
}
$5 = {
$sessioner = Read-Host "Who will you be PSSessioning?"
Enter-PSSession -ComputerName $sessioner -Credential YOURDOMAIN\ 
}
cls
$start = {
$choice = Read-Host "
-------------------------------------------------------------------

██████╗  ██████╗ ██╗    ██╗███████╗██████╗ ███████╗██╗███╗   ██╗██████╗ 
██╔══██╗██╔═══██╗██║    ██║██╔════╝██╔══██╗██╔════╝██║████╗  ██║██╔══██╗
██████╔╝██║   ██║██║ █╗ ██║█████╗  ██████╔╝█████╗  ██║██╔██╗ ██║██║  ██║
██╔═══╝ ██║   ██║██║███╗██║██╔══╝  ██╔══██╗██╔══╝  ██║██║╚██╗██║██║  ██║
██║     ╚██████╔╝╚███╔███╔╝███████╗██║  ██║██║     ██║██║ ╚████║██████╔╝
╚═╝      ╚═════╝  ╚══╝╚══╝ ╚══════╝╚═╝  ╚═╝╚═╝     ╚═╝╚═╝  ╚═══╝╚═════╝ 
                                                                        
-----------------------------------------------------------------
1) IP to HOSTNAME

2) HOSTNAME TO IP

3) HOSTNAME TO USER 

4) USER TO HOSTNAME

5) ADVANCED USER FINDER (client machine requires PS 5.1)

6) E-Z PSSESSION

7) QUIT

Your choice"
if ($choice -eq "1")
    {&$1}
if ($choice -eq "2")
    {&$10}
if ($choice -eq "3")
    {&$2}
if ($choice -eq "4")
    {&$3}
if ($choice -eq "5")
    {&$4}
if ($choice -eq "6")
    {&$5}
if ($choice -eq "7")
    {exit}
else 
    {&$start}
}
&$start
