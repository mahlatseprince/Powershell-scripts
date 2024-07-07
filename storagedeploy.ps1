param (
    [string]$StorageAccountName
)

Set-AzContext -Subscription "SB-SBG-InfrastructureTest-NonProd"

New-AzStorageAccount -ResourceGroupName "SAN-RG-MahlatseS-Test" `
  -Name $StorageAccountName `
  -Location 'southafricanorth'`
  -SkuName Standard_LRS `
  -Kind StorageV2 `
  -AllowBlobPublicAccess $false `
  -MinimumTlsVersion TLS1_2
