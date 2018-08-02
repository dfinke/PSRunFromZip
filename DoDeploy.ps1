Remove-Item hw.zip -ErrorAction Ignore

Compress-Archive -Path .\HelloWorld\ -DestinationPath .\hw.zip  -Update -Verbose
Compress-Archive -Path .\host.json   -DestinationPath .\hw.zip  -Update -Verbose

.\DeployRunFromZip.ps1 hw.zip runfromzip-rg runfromzip -verbose

Write-Verbose "Invoke-RestMethod on target function"
Invoke-RestMethod "https://runfromzip.azurewebsites.net/api/HelloWorld" -Verbose