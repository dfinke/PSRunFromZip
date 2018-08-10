<#
    .SYNOPSIS
    Deploy an Azure Function from the command line, a zip file to, blob storage to deployment

    .Description
    Assumptions
        - You have an Azure subscription
        - Azure PowerShell is installed
        - Az CLI is installed

        Already exists:
        A resource group named `DeployGallery-rg` with a Storage Account named `deploygallery` and a container name `zips`

    .Example
    .\DeployRunFromZip hw.zip runfromzip-rg runfromzip -verbose
    Invoke-RestMethod "https://runfromzip.azurewebsites.net/api/HelloWorld"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    $ZipFileName,
    [Parameter(Mandatory)]
    $FunctionAppResourceGroupName,
    [Parameter(Mandatory)]
    $FunctionAppName,
    $DeployResourceGroup = "DeployGallery-rg",
    $DeployStorageAccountName = "deploygallery",
    $ContainerName = "zips"
)

function Add-FunctionAppSetting {
    [CmdletBinding()]
    param(
        $appName,
        $resourceGroupName,
        [hashtable]$setting
    )

    $settingKVP = $setting.GetEnumerator() | ForEach-Object {"{0}='{1}'" -f $_.key, $_.value}

    ("az functionapp config appsettings set --name $appName --resource-group $resourceGroupName --settings $settingKVP" | Invoke-Expression) 2> $null
}

Write-Verbose "Checking login"
if ($null -eq (Get-AzureRmContext).Tenant) {
    $null = Login-AzAccount
}

Write-Verbose "Writing $($ZipFileName) to blob storage"
$fileName = $ZipFileName.Split(".")[0]
$blobName = "{0}.{1}.zip" -f $fileName, (Get-Date).ToString("yyyyMMddHHmmss.fff")

$storageAccountKey = (Get-AzureRmStorageAccountKey -ResourceGroupName $DeployResourceGroup -Name $DeployStorageAccountName).Value[0]
$blobContext = New-AzureStorageContext -StorageAccountName $DeployStorageAccountName -StorageAccountKey $storageAccountKey
$null = Set-AzureStorageBlobContent -File ((Resolve-Path $ZipFileName).Path) -Container $containerName -Blob $blobName -Context $blobContext -Force

Write-Verbose "Getting SAS Token"
$SASToken = New-AzureStorageBlobSASToken -Container $containerName -Blob $blobName -Permission r -Context $blobContext

Write-Verbose "Setting Azure Function application setting"
$settings = @{
    "WEBSITE_RUN_FROM_ZIP" = ("{0}{1}/{2}{3}" -f $blobContext.BlobEndPoint, $containerName, $blobName, $SASToken)
}

$null = Add-FunctionAppSetting $FunctionAppName $FunctionAppResourceGroupName $settings
