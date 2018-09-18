$iconloc = "C:\Users\$env:UserName\AppData\Local\powerfind\powerfind.ico"
$iconfold = "C:\Users\$env:UserName\AppData\Local\powerfind"

if( -not (Test-Path $iconfold -PathType Container))
{
    New-Item -ItemType "directory" -Path $iconfold
    Invoke-WebRequest http://www.iconj.com/ico/q/b/qbv8qn2hje.ico -OutFile $iconloc
}

Add-Type -AssemblyName System.Windows.Forms
[System.Windows.Forms.Application]::EnableVisualStyles()

[Net.ServicePointManager]::SecurityProtocol = 'tls12'

$Form                            = New-Object system.Windows.Forms.Form
$Form.ClientSize                 = '400,724'
$Form.text                       = "PowerFind"
$Form.TopMost                    = $false
$Form.icon                       = $iconloc

$PictureBox1                     = New-Object system.Windows.Forms.PictureBox
$PictureBox1.width               = 368
$PictureBox1.height              = 152
$PictureBox1.location            = New-Object System.Drawing.Point(17,13)
$PictureBox1.imageLocation       = "https://i.imgur.com/KGme4ag.png"
$PictureBox1.SizeMode            = [System.Windows.Forms.PictureBoxSizeMode]::zoom
$TextBox1                        = New-Object system.Windows.Forms.TextBox
$TextBox1.multiline              = $false
$TextBox1.width                  = 374
$TextBox1.height                 = 20
$TextBox1.location               = New-Object System.Drawing.Point(10,174)
$TextBox1.Font                   = 'Microsoft Sans Serif,10'

$Button1                         = New-Object system.Windows.Forms.Button
$Button1.text                    = "IP"
$Button1.width                   = 60
$Button1.height                  = 30
$Button1.location                = New-Object System.Drawing.Point(10,210)
$Button1.Font                    = 'Microsoft Sans Serif,10'

$Button2                         = New-Object system.Windows.Forms.Button
$Button2.text                    = "FQDN"
$Button2.width                   = 60
$Button2.height                  = 30
$Button2.location                = New-Object System.Drawing.Point(166,210)
$Button2.Font                    = 'Microsoft Sans Serif,10'

$Button3                         = New-Object system.Windows.Forms.Button
$Button3.text                    = "User"
$Button3.width                   = 60
$Button3.height                  = 30
$Button3.location                = New-Object System.Drawing.Point(324,210)
$Button3.Font                    = 'Microsoft Sans Serif,10'

$TextBox2                        = New-Object system.Windows.Forms.TextBox
$TextBox2.multiline              = $true
$TextBox2.width                  = 364
$TextBox2.height                 = 364
$TextBox2.location               = New-Object System.Drawing.Point(10,255)
$TextBox2.Font                   = 'Microsoft Sans Serif,10'

$clearbutton                     = New-Object system.Windows.Forms.Button
$clearbutton.text                = "Clear"
$clearbutton.width               = 60
$clearbutton.height              = 30
$clearbutton.location            = New-Object System.Drawing.Point(163,679)
$clearbutton.Font                = 'Microsoft Sans Serif,10'

$Form.controls.AddRange(@($PictureBox1,$TextBox1,$Button1,$Button2,$Button3,$TextBox2, $clearbutton))

$Button1.Add_Click({ipify})
$Button2.Add_Click({hostify})
$Button3.Add_Click({userfy})
$clearButton.Add_Click({$TextBox2.Clear()})

function ipify
{
    $nsresults = nslookup $TextBox1.Text | Select-String "Name:" | Out-String
    $nsresults = $nsresults.Substring(9)
    $nsresults = $nsresults.trim()
    $nsresults1 = $nsresults -replace ".{19}$"
    $TextBox2.text += "`r`n" + $TextBox1.Text + "`r`n" + $nsresults1
    if($TextBox1.Text -like "*192.168.*")
    {
        $username = Get-ADComputer $nsresults1 -Properties Description | Select-Object -ExpandProperty Description
        $location = Get-ADComputer $nsresults1 -Properties CanonicalName |select-object -expandproperty CanonicalName
        $TextBox2.text += "`r`n" + $location + "`r`n" + $username
        $TextBox2.text += "`r`n" + "-----------------------------"
    }
}

function hostify
{
    $TextBox2.text += "`r`n" + $TextBox1.Text
    $ipresults = Resolve-DNSName $TextBox1.Text
    $ipresults = $ipresults.IPAddress
    $TextBox2.text += "`r`n" + $ipresults
    if($ipresults -like "*192.168.*")
    {
        $username = Get-ADComputer $TextBox1.Text -Properties Description | Select-Object -ExpandProperty Description
        $location = Get-ADComputer $TextBox1.Text -Properties CanonicalName |select-object -expandproperty CanonicalName
        $TextBox2.text += "`r`n" + $location + "`r`n" + $username
        $TextBox2.text += "`r`n" + "-----------------------------"
    }
}

function userfy
{
    Write-Host "Hi!"
    $username = $TextBox1.Text.Trim()
    $outage = Get-ADComputer -Filter "Description -like '*$username*'" -properties description | Select -ExpandProperty Name
    $TextBox2.text += "`r`n" + "COMPUTERS ASSOCIATED WITH THIS USER:"
    $TextBox2.text += "`r`n" + $outage
    $TextBox2.text += "`r`n" + "-----------------------------"
    $stringArray = $outage.Split(" ") | ForEach-Object{$_.trim()}
    ForEach($computer in $stringArray)
    {
        $location = Get-ADComputer $computer -Properties CanonicalName | select-object -expandproperty CanonicalName
        $ipresults = Resolve-DNSName $computer
        $ipresults = $ipresults.IPAddress
        $TextBox2.Text += "`r`n" + $computer + ": " + "`r`n" + "------------------------" + "`r`n" + "--$ipresults" + "`r`n" + "--$location" + "`r`n" + "------------------------"
    }
}

[void]$Form.ShowDialog()
