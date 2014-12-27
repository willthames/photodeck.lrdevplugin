$source = "https://github.com/willthames/photodeck.lrdevplugin/archive/master.zip"
$destination = Join-Path -Path $env:USERPROFILE -Child-Path "\Downloads\photodeck-lrdevplugin.zip"

(New-Object System.Net.WebClient).DownloadFile($source, $destination)

$shell = New-Object -com shell.application
$zip = $shell.NameSpace($destination)
foreach($item in $zip.items())
{
  $shell.Namespace($destination).CopyHere($item, 16)
}
