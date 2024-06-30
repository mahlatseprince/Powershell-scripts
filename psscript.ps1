param (
    [string]$ApplicationName,
    [string]$BusinessSegment,
    [string]$ResourceEnvironments,
    [string]$ResourceRegions,
    [string]$BillingApplicationName,
    [string]$SystemOwner,
    [string]$TechnicalOwner,
    [string]$TCKey,
    [string]$TeamEmail,
    [string]$CallOutGroup,
    [string]$RemedyGroup,
    [string]$RGRegions,
    [string]$ElevatedAccount,
    [string]$UTRKey,
    [string]$BSLSystemOwner,
    [string]$ResourceGroups,
    [string]$SystemOwnerImmutableId,
    [string]$ElevatedImmutableId
)

Install-Module -Name Az.Subscription  -RequiredVersion 0.11.0 -Force
            
$ApplicationName = ($ApplicationName.Replace("_", "")).Replace(" ", "")

$ManagementGroup = ""
$TemplateFile = "./AzureEnablement/BaseInfraResources.bicep"

$specialCharsPattern = "[^\w\s]"


if ($ResourceRegions -eq "South Africa North") {
    $BaseRGName = "SAN-BaseInfra"
    $ResourceRegions = "SAN"
}
elseif ($ResourceRegions -eq "South Africa West") {
    $BaseRGName = "SAW-BaseInfra"
    $ResourceRegions = "SAW"
}
elseif ($ResourceRegions -eq "North Europe") {
    $BaseRGName = "NEU-BaseInfra"
    $ResourceRegions = "NEU"
}
elseif ($ResourceRegions -eq "West Europe") {
    $BaseRGName = "WEU-BaseInfra"
    $ResourceRegions = "WEU"
}


if ($BusinessSegment -eq 'SBG') {
    $ManagementGroup += "SBG-"
}
else {
    $ManagementGroup += "ZAR-"
}
if ($ResourceEnvironments -eq 'NonProd') {
    $ManagementGroup += "Non-Prod"
}
else {
    $ManagementGroup += "Prod"
}

$subName = "SB-" + $BusinessSegment.ToUpper() + "-" + $ApplicationName.Substring(0, 1).ToUpper() + $ApplicationName.Substring(1) + "-" + $ResourceEnvironments.Substring(0, 1).ToUpper() + $ResourceEnvironments.Substring(1)
$ApplicationName = $ApplicationName -replace $specialCharsPattern, ""
$RGName = $ResourceRegions + "-" + $ApplicationName.Substring(0, 1).ToUpper() + $ApplicationName.Substring(1) + "-" + $ResourceEnvironments.Substring(0, 1).ToUpper() + $ResourceEnvironments.Substring(1)
$RGtags = @{CostAllocationReferenceSource = $subName ; BillingApplicationName = $BillingApplicationName; ApplicationName = "Resource Group"; SystemOwner = $SystemOwner; TechnicalOwner = $TechnicalOwner; TCKey = $TCKey; TeamEmail = $TeamEmail; CallOutGroup = $CallOutGroup; RemedyGroup = $RemedyGroup; UTRKey = $UTRKey; BSLSystemOwner = $BSLSystemOwner }
$Subtags = @{CostAllocationReferenceSource = $subName ; BillingApplicationName = $BillingApplicationName; ApplicationName = "Subscription"; SystemOwner = $SystemOwner; TechnicalOwner = $TechnicalOwner; TCKey = $TCKey; TeamEmail = $TeamEmail; CallOutGroup = $CallOutGroup; RemedyGroup = $RemedyGroup; UTRKey = $UTRKey; BSLSystemOwner = $BSLSystemOwner }

Write-Host "##[section]Checking if the Subscription exist"
$ExistingSubscription = Get-AzSubscription -SubscriptionName $subName -ErrorAction SilentlyContinue
if ($subName -ne $ExistingSubscription.Name) {
    Write-Host "##[section]Subscription does not exist, creating a new Subscription"
    New-AzSubscriptionAlias -AliasName $subName -SubscriptionName $subName -BillingScope "/providers/Microsoft.Billing/billingAccounts/55179219/enrollmentAccounts/204063" -Workload "Production"

    Write-Host "##[section]Checking if the new Subscription is available"
    $subscriptionId = Get-AzSubscription -SubscriptionName $subName -ErrorAction SilentlyContinue
    $count = 0
    while ($null -eq $subscriptionId -and $count -lt 10) {
        $count ++
        $subscriptionId = Get-AzSubscription -SubscriptionName $subName -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 60
    }
    New-AzTag -ResourceId "/subscriptions/$subscriptionId" -Tag $Subtags

    $subscriptionId = $subscriptionId.id
    Write-Host "##[section]Moving the Subscription to $ManagementGroup"
    $moveToManagementGroup = New-AzManagementGroupSubscription -GroupId $ManagementGroup -SubscriptionId $subscriptionId
}
else {
    Write-Host "##[section]Subscription already exist, continuing to create the Resource Groups"
}
Write-Host "##[section]Setting the Context to $subName"

$Context = Set-AzContext -Subscription $subName
                  
Write-Host "##[section]Creating the new Base resource group $BaseRGName"
$NewBaseRG = New-AzResourceGroup -Name $BaseRGName -Location $RGRegions -Tag $RGtags -Force
Write-Host "##[section]Creating the new Application resource groups"
if ($ResourceEnvironments -eq "NonProd") {
    $RGs = $ResourceGroups.split(",")
    foreach ($rg in $RGs) {
        if ($rg -ne "false") {
            $RGName = $ResourceRegions + "-" + $ApplicationName.Substring(0, 1).ToUpper() + $ApplicationName.Substring(1) + "-" + $rg
            $NewRG = New-AzResourceGroup -Name $RGName -Location $RGRegions -Tag $RGtags -Force
            if ($rg -eq "DEV") {
                $DEVReaderGroup = "AZ-READ-RG-$ResourceRegions-$ApplicationName-$rg"
                $DEVReaderDescription = "This group will be used to grant read access to $RGName"
                $DEVContributorGroup = "AZ-CONT-RG-$ResourceRegions-$ApplicationName-$rg"
                $DEVContributorDescription = "This group will be used to grant contributor access to $RGName"
                $DevRG = $RGName
            }
            if ($rg -eq "SIT") {
                $SITReaderGroup = "AZ-READ-RG-$ResourceRegions-$ApplicationName-$rg"
                $SITReaderDescription = "This group will be used to grant read access to $RGName"
                $SITContributorGroup = "AZ-CONT-RG-$ResourceRegions-$ApplicationName-$rg"
                $SITContributorDescription = "This group will be used to grant contributor access to $RGName"
                $SITRG = $RGName
            }
            if ($rg -eq "UAT") {
                $UATReaderGroup = "AZ-READ-RG-$ResourceRegions-$ApplicationName-$rg"
                $UATReaderDescription = "This group will be used to grant read access to $RGName"
                $UATContributorGroup = "AZ-CONT-RG-$ResourceRegions-$ApplicationName-$rg"
                $UATContributorDescription = "This group will be used to grant contributor access to $RGName"
                $UATRG = $RGName
            }
        }
    }
                
}
else {
    $NewRG = New-AzResourceGroup -Name $RGName -Location $RGRegions -Tag $RGtags -Force
}
Write-Host "##[section]Applying the Policy Exemption to allow resource creation"
                
$ParamFileName = "SBG - Security Custom Network Initiative"
$ExTemplateFile = "./MicrosoftAuthorization/PolicyExemptions/resourceGroup/main.bicep"
$PolicyDef = Get-AzPolicyAssignment | Select-Object -ExpandProperty Properties | Where-Object DisplayName -Like $ParamFileName
$AssignmentId = (Get-AzPolicyAssignment -PolicyDefinitionId $PolicyDef.PolicyDefinitionId).PolicyAssignmentId
$exemptionDuration = "1"
$description = "Automated Base Infra Creation"

New-AzResourceGroupDeployment -Name "Apply_Exemption_Policy" -ResourceGroupName $BaseRGName -TemplateFile $ExTemplateFile `
    -exemptionDuration $exemptionDuration `
    -description $description `
    -policyName $ParamFileName `
    -policyAssignmentId $AssignmentId `
    -displayName $ParamFileName


$storagAccountName = ("sa" + $ResourceRegions + $ApplicationName + $ResourceEnvironments).ToLower()               
if ($storagAccountName.Length -gt 24) {
    $chartoSubtract = $storagAccountName.Length - 24
    $chartoSubtract = $ApplicationName.Length - $chartoSubtract
    $name = $ApplicationName.Substring(0, $chartoSubtract)
    $storagAccountName = ("sa" + $ResourceRegions + $name + $ResourceEnvironments).ToLower()
}
$networkwatcherName = ("nw" + "-" + $ResourceRegions + "-" + $ApplicationName + "-" + $ResourceEnvironments).ToLower()
if ($networkwatcherName.Length -gt 80) {
    $chartoSubtract = $networkwatcherName.Length - 80
    $chartoSubtract = $ApplicationName.Length - $chartoSubtract
    $name = $ApplicationName.Substring(0, $chartoSubtract)
    $networkwatcherName = ("nw" + "-" + $ResourceRegions + "-" + $name + "-" + $ResourceEnvironments).ToLower()
}
$keyVaultName = ("kv" + "-" + $ResourceRegions + "-" + $ApplicationName + "-" + $ResourceEnvironments + "-infra").ToLower()
if ($keyVaultName.Length -gt 24) {
    $chartoSubtract = $keyVaultName.Length - 24
    $chartoSubtract = $ApplicationName.Length - $chartoSubtract
    $name = $ApplicationName.Substring(0, $chartoSubtract)
    $keyVaultName = ("kv" + "-" + $ResourceRegions + "-" + $name + "-" + $ResourceEnvironments + "-infra").ToLower()
}
$desName = ("des" + "-" + $ResourceRegions + "-" + $ApplicationName + "-" + $ResourceEnvironments).ToLower()
if ($desName.Length -gt 80) {
    $chartoSubtract = $desName.Length - 80
    $chartoSubtract = $ApplicationName.Length - $chartoSubtract
    $name = $ApplicationName.Substring(0, $chartoSubtract)
    $desName = ("des" + "-" + $ResourceRegions + "-" + $name + "-" + $ResourceEnvironments).ToLower()
}
$recoveryVaultName = ("rsv" + "-" + $ResourceRegions + "-" + $ApplicationName + "-" + $ResourceEnvironments + "-asr").ToLower()
$recoveryVaultName = ($recoveryVaultName).Replace("_", "")
if ($recoveryVaultName.Length -gt 50) {
    $chartoSubtract = $recoveryVaultName.Length - 50
    $chartoSubtract = $ApplicationName.Length - $chartoSubtract
    $name = $ApplicationName.Substring(0, $chartoSubtract)
    $recoveryVaultName = ("rsv" + "-" + $ResourceRegions + "-" + $name + "-" + $ResourceEnvironments + "-asr").ToLower()
}
$routeTableName = ("rtt" + "-" + $ResourceRegions + "-" + $ApplicationName + "-" + $ResourceEnvironments + "-default").ToLower()
if ($routeTableName.Length -gt 80) {
    $chartoSubtract = $routeTableName.Length - 80
    $chartoSubtract = $ApplicationName.Length - $chartoSubtract
    $name = $ApplicationName.Substring(0, $chartoSubtract)
    $routeTableName = ("rtt" + "-" + $ResourceRegions + "-" + $name + "-" + $ResourceEnvironments + "-default").ToLower()
}
$routeName = ("rt" + "-" + $ResourceRegions + "-" + $ApplicationName + "-" + $ResourceEnvironments + "-default").ToLower()
if ($routeName.Length -gt 80) {
    $chartoSubtract = $routeName.Length - 80
    $chartoSubtract = $ApplicationName.Length - $chartoSubtract
    $name = $ApplicationName.Substring(0, $chartoSubtract)
    $routeName = ("rt" + "-" + $ResourceRegions + "-" + $name + "-" + $ResourceEnvironments + "-default").ToLower()
}
$nsgName = (
                    ("nsg" + "-" + $ResourceRegions + "-" + $ApplicationName + "-" + $ResourceEnvironments + "-subn-app").ToLower()
)
if ($nsgName.length -gt 64) {
    $chartoSubtract = $nsgName.Length - 64
    $chartoSubtract = $ApplicationName.Length - $chartoSubtract
    $name = $ApplicationName.Substring(0, $chartoSubtract)
    $nsgNames = (
                    ("nsg" + "-" + $ResourceRegions + "-" + $name + "-" + $ResourceEnvironments + "-subn-app").ToLower(),
                    ("nsg" + "-" + $ResourceRegions + "-" + $name + "-" + $ResourceEnvironments + "-subn-db").ToLower(),
                    ("nsg" + "-" + $ResourceRegions + "-" + $name + "-" + $ResourceEnvironments + "-subn-web").ToLower()
    )
 
}
else { 

    $nsgNames = (
                    ("nsg" + "-" + $ResourceRegions + "-" + $ApplicationName + "-" + $ResourceEnvironments + "-subn-app").ToLower(),
                    ("nsg" + "-" + $ResourceRegions + "-" + $ApplicationName + "-" + $ResourceEnvironments + "-subn-db").ToLower(),
                    ("nsg" + "-" + $ResourceRegions + "-" + $ApplicationName + "-" + $ResourceEnvironments + "-subn-web").ToLower()
    )
}

$vNetName = ("vnet" + "-" + $ResourceRegions + "-" + $ApplicationName + "-" + $ResourceEnvironments).ToLower()
$subnetNames = (
                    ("subn" + "-" + $ResourceRegions + "-" + $ApplicationName + "-" + $ResourceEnvironments + "-app").ToLower(),
                    ("subn" + "-" + $ResourceRegions + "-" + $ApplicationName + "-" + $ResourceEnvironments + "-db").ToLower(),
                    ("subn" + "-" + $ResourceRegions + "-" + $ApplicationName + "-" + $ResourceEnvironments + "-web").ToLower()
)

Write-Host "##[section]Setting the Context to GuardRails to create the securityGroup Payload"

$Context = Set-AzContext -Subscription "SB-SBG-GuardRails-Prod"
                                  
Write-Host "##[section]Saving the payload for security groups"

$ReaderGroup = "AZ-READ-RG-$ResourceRegions-$ApplicationName-$ResourceEnvironments"
$ReaderDescription = "This group will be used to grant read access to $RGName"
$ContributorGroup = "AZ-CONT-RG-$ResourceRegions-$ApplicationName-$ResourceEnvironments"
$ContributorDescription = "This group will be used to grant contributor access to $RGName"

                                  
$Payload = [PSCustomObject]@{
    ManagedBy                 = $SystemOwner
    TechnicalOwnerName        = $TechnicalOwnerName
    TechnicalOwnerSurname     = $TechnicalOwnerSurname
    ReaderGroup               = $ReaderGroup
    ReaderDescription         = $ReaderDescription
    ContributorGroup          = $ContributorGroup
    ContributorDescription    = $ContributorDescription
    ElevatedAccount           = $ElevatedAccount
    DevReaderGroup            = $DEVReaderGroup
    DEVReaderDescription      = $DEVReaderDescription
    DEVContributorGroup       = $DEVContributorGroup
    DEVContributorDescription = $DEVContributorDescription
    SITReaderGroup            = $SITReaderGroup
    SITReaderDescription      = $SITReaderDescription
    SITContributorGroup       = $SITContributorGroup
    SITContributorDescription = $SITContributorDescription
    UATReaderGroup            = $UATReaderGroup
    UATReaderDescription      = $UATReaderDescription
    UATContributorGroup       = $UATContributorGroup
    UATContributorDescription = $UATContributorDescription
    SystemOwnerImmutableId    = $SystemOwnerImmutableId
    ElevatedImmutableId       = $ElevatedImmutableId  

}
                                  
$Payload | ConvertTo-Json | Out-File -FilePath "./$RGName.json"
                                  
$StorageAccount = Get-AzStorageAccount -ResourceGroupName "GuardRails" -Name "guardrailsstorage"
$StorageAccount = $StorageAccount.Context
                                  
$Blob2HT = @{
    File             = "./$RGName.json" 
    Container        = "azuresubscriptionvending"  
    Blob             = "$RGName.json"
    Context          = $StorageAccount
    StandardBlobTier = 'Hot'
}
Set-AzStorageBlobContent @Blob2HT -Force

Write-Host "##[section]Setting the Context to $subName"

$Context = Set-AzContext -Subscription $subName
$subscriptionId = Get-AzSubscription -SubscriptionName $subName
$subscriptionId = $subscriptionId.id

Write-Host "##[section]Starting the Resource Deployments"

New-AzResourceGroupDeployment -Name "Deploy_BaseInfra_Resources" -ResourceGroupName $BaseRGName -TemplateFile $TemplateFile `
    -subscriptionId $subscriptionId `
    -environment $ResourceEnvironments `
    -region $RGRegions `
    -newRgName $BaseRGName `
    -storageAccountName $storagAccountName `
    -networkWatcherName $networkwatcherName `
    -keyVaultName $keyVaultName `
    -desName $desName `
    -vaultName $recoveryVaultName `
    -RTTName $routeTableName `
    -routeName $routeName `
    -NSGNames $nsgNames `
    -vNetName $vNetName `
    -subnetNames $subnetNames

Write-Host "##[section]Resource Deployments completed"

Write-Host "##[section]Adding the Security groups to the Resource Group"

$ReaderGroupName = "AZ-READ-RG-$RGName"
$ReaderRoleDefinitionName = "Reader"
$ContGroupName = "AZ-CONT-RG-$RGName"
$ContRoleDefinitionName = "Contributor"
$NetworkRoleDefinitionName = "Network Interface Operator"
$DNSRoleDefinitionName = "Private DNS Zone Contributor"
  
if($RGName -like '*-Prod') {
# Loop until the Reader group is available
$retry = 0
while (-not (Get-AzADGroup -DisplayName $ReaderGroupName) -and $retry -lt 10) {
    Write-Host "##[section]Waiting for security group $RGName to be available..."
    $retry ++
    Start-Sleep -Seconds 600
    Write-Host "##[warning]$ReaderGroupName is not yet available trying for the $retry time"
}
                                    
if (Get-AzADGroup -DisplayName $ReaderGroupName) {
    # Get the Reader group object
    Write-Host "##[section]$ReaderGroupName is available attempting to add it to $RGName" 
    $securityGroup = Get-AzADGroup -DisplayName $ReaderGroupName
                                    
    # Get the role definition
    $roleDefinition = Get-AzRoleDefinition -Name $ReaderRoleDefinitionName
          

    # Add the security group to the resource group with the Reader role assignment
    New-AzRoleAssignment -ObjectId $securityGroup.Id -RoleDefinitionId $roleDefinition.Id -Scope "/subscriptions/$subscriptionId/resourceGroups/$RGName"
                    

    Write-Host "##[section]Security group $ReaderGroupName added to resource group $RGName with role $ReaderRoleDefinitionName"
                                    
}
else {
    Write-Host "##[error]Failed to detect security group $ReaderGroupName please ensure it has been created in On-Prem AD"

}
# Loop until the Contributor group is available
$retry = 0
while (-not (Get-AzADGroup -DisplayName $ContGroupName) -and $retry -lt 10) {
    Write-Host "##[section]Waiting for security group $ContGroupName to be available.."
    $retry ++
    Start-Sleep -Seconds 600
    Write-Host "##[warning]$ContGroupName is not yet available trying for the $retry time"

}
                                    
if (Get-AzADGroup -DisplayName $ContGroupName) {
    # Get the Reader group object
    $securityGroup = Get-AzADGroup -DisplayName $ContGroupName
                                    
    # Get the role definition
    $roleDefinition = Get-AzRoleDefinition -Name $ContRoleDefinitionName
    $DNSroleDefinition = Get-AzRoleDefinition -Name $DNSRoleDefinitionName
    $NetworkroleDefinition = Get-AzRoleDefinition -Name $NetworkRoleDefinitionName
                                    
    # Add the security group to the resource group with the Contributor role assignment
    New-AzRoleAssignment -ObjectId $securityGroup.Id -RoleDefinitionId $roleDefinition.Id -Scope "/subscriptions/$subscriptionId/resourceGroups/$RGName"
    New-AzRoleAssignment -ObjectId $securityGroup.Id -RoleDefinitionId $NetworkroleDefinition.Id -Scope "/subscriptions/$subscriptionId/resourceGroups/$BaseRGName"
    New-AzRoleAssignment -ObjectId $securityGroup.Id -RoleDefinitionId $DNSroleDefinition.Id -Scope "/subscriptions/dbabcaa6-b91a-4d21-bfcc-b1f0a5065d53/resourceGroups/san-plt-coredns"

    Write-Host "##[section]Security group $ContGroupName added to resource group $RGName with role $ContRoleDefinitionName"
                                    
}
else {
    Write-Host "##[error]Failed to detect security group $ContGroupName please ensure it has been created in On-Prem AD"

}
}
if ($null -ne $DEVReaderGroup) {
    $retry = 0
    while (-not (Get-AzADGroup -DisplayName $DEVReaderGroup) -and $retry -lt 10) {
        Write-Host "##[section]Waiting for security group $DEVReaderGroup to be available..."
        $retry ++
        Start-Sleep -Seconds 600
        Write-Host "##[warning]$ReaderGroupName is not yet available trying for the $retry time"

    }
                                    
    if (Get-AzADGroup -DisplayName $DEVReaderGroup) {
        # Get the Reader group object
        Write-Host "##[section]$DEVReaderGroup is available attempting to add it to $RGName" 
        $securityGroup = Get-AzADGroup -DisplayName $DEVReaderGroup
                                    
        # Get the role definition
        $roleDefinition = Get-AzRoleDefinition -Name $ReaderRoleDefinitionName
          

        # Add the security group to the resource group with the Reader role assignment
        New-AzRoleAssignment -ObjectId $securityGroup.Id -RoleDefinitionId $roleDefinition.Id -Scope "/subscriptions/$subscriptionId/resourceGroups/$DevRG"
                    

        Write-Host "##[section]Security group $DEVReaderGroup added to resource group $DevRG with role $ReaderRoleDefinitionName"
                                    
    }
    else {
        Write-Host "##[error]Failed to detect security group $DEVReaderGroup please ensure it has been created in On-Prem AD"

    }
    $retry = 0
    # Loop until the Contributor group is available
    while (-not (Get-AzADGroup -DisplayName $DEVContributorGroup) -and $retry -lt 10) {
        Write-Host "##[section]Waiting for security group $DEVContributorGroup to be available.."
        $retry ++
        Start-Sleep -Seconds 600
        Write-Host "##[warning]$DEVContributorGroup is not yet available trying for the $retry time"

    }
                                    
    if (Get-AzADGroup -DisplayName $DEVContributorGroup) {
        # Get the Reader group object
        $securityGroup = Get-AzADGroup -DisplayName $DEVContributorGroup
                                    
        # Get the role definition
        $roleDefinition = Get-AzRoleDefinition -Name $ContRoleDefinitionName
        $DNSroleDefinition = Get-AzRoleDefinition -Name $DNSRoleDefinitionName
        $NetworkroleDefinition = Get-AzRoleDefinition -Name $NetworkRoleDefinitionName
                                    
        # Add the security group to the resource group with the Contributor role assignment
        New-AzRoleAssignment -ObjectId $securityGroup.Id -RoleDefinitionId $roleDefinition.Id -Scope "/subscriptions/$subscriptionId/resourceGroups/$DevRG"
        New-AzRoleAssignment -ObjectId $securityGroup.Id -RoleDefinitionId $NetworkroleDefinition.Id -Scope "/subscriptions/$subscriptionId/resourceGroups/$BaseRGName"
        New-AzRoleAssignment -ObjectId $securityGroup.Id -RoleDefinitionId $DNSroleDefinition.Id -Scope "/subscriptions/dbabcaa6-b91a-4d21-bfcc-b1f0a5065d53/resourceGroups/san-plt-coredns"

        Write-Host "##[section]Security group $DEVContributorGroup added to resource group $DevRG with role $ContRoleDefinitionName"
                                    
    }
    else {
        Write-Host "##[error]Failed to detect security group $DEVContributorGroup please ensure it has been created in On-Prem AD"

    }

}

if ($null -ne $SITReaderGroup) {
    $retry = 0
    while (-not (Get-AzADGroup -DisplayName $SITReaderGroup) -and $retry -lt 10) {
        Write-Host "##[section]Waiting for security group $SITReaderGroup to be available..."
        $retry ++
        Start-Sleep -Seconds 600
        Write-Host "##[warning]$ReaderGroupName is not yet available trying for the $retry time"

    }
                                    
    if (Get-AzADGroup -DisplayName $SITReaderGroup) {
        # Get the Reader group object
        Write-Host "##[section]$SITReaderGroup is available attempting to add it to $RGName" 
        $securityGroup = Get-AzADGroup -DisplayName $SITReaderGroup
                                    
        # Get the role definition
        $roleDefinition = Get-AzRoleDefinition -Name $ReaderRoleDefinitionName
          

        # Add the security group to the resource group with the Reader role assignment
        New-AzRoleAssignment -ObjectId $securityGroup.Id -RoleDefinitionId $roleDefinition.Id -Scope "/subscriptions/$subscriptionId/resourceGroups/$SITRG"
                    

        Write-Host "##[section]Security group $SITReaderGroup added to resource group $SITRG with role $ReaderRoleDefinitionName"
                                    
    }
    else {
        Write-Host "##[error]Failed to detect security group $SITReaderGroup please ensure it has been created in On-Prem AD"

    }
    $retry = 0
    # Loop until the Contributor group is available
    while (-not (Get-AzADGroup -DisplayName $SITContributorGroup) -and $retry -lt 10) {
        Write-Host "##[section]Waiting for security group $SITContributorGroup to be available.."
        $retry ++
        Start-Sleep -Seconds 600
        Write-Host "##[warning]$SITContributorGroup is not yet available trying for the $retry time"

    }
                                    
    if (Get-AzADGroup -DisplayName $SITContributorGroup) {
        # Get the Reader group object
        $securityGroup = Get-AzADGroup -DisplayName $SITContributorGroup
                                    
        # Get the role definition
        $roleDefinition = Get-AzRoleDefinition -Name $ContRoleDefinitionName
        $DNSroleDefinition = Get-AzRoleDefinition -Name $DNSRoleDefinitionName
        $NetworkroleDefinition = Get-AzRoleDefinition -Name $NetworkRoleDefinitionName
                                    
        # Add the security group to the resource group with the Contributor role assignment
        New-AzRoleAssignment -ObjectId $securityGroup.Id -RoleDefinitionId $roleDefinition.Id -Scope "/subscriptions/$subscriptionId/resourceGroups/$SITRG"
        New-AzRoleAssignment -ObjectId $securityGroup.Id -RoleDefinitionId $NetworkroleDefinition.Id -Scope "/subscriptions/$subscriptionId/resourceGroups/$BaseRGName"
        New-AzRoleAssignment -ObjectId $securityGroup.Id -RoleDefinitionId $DNSroleDefinition.Id -Scope "/subscriptions/dbabcaa6-b91a-4d21-bfcc-b1f0a5065d53/resourceGroups/san-plt-coredns"

        Write-Host "##[section]Security group $SITContributorGroup added to resource group $SITRG with role $ContRoleDefinitionName"
                                    
    }
    else {
        Write-Host "##[error]Failed to detect security group $SITContributorGroup please ensure it has been created in On-Prem AD"

    }

}

if ($null -ne $UATReaderGroup) {
    $retry = 0
    while (-not (Get-AzADGroup -DisplayName $UATReaderGroup) -and $retry -lt 10) {
        Write-Host "##[section]Waiting for security group $UATReaderGroup to be available..."
        $retry ++
        Start-Sleep -Seconds 600
        Write-Host "##[warning]$ReaderGroupName is not yet available trying for the $retry time"

    }
                                    
    if (Get-AzADGroup -DisplayName $UATReaderGroup) {
        # Get the Reader group object
        Write-Host "##[section]$UATReaderGroup is available attempting to add it to $RGName" 
        $securityGroup = Get-AzADGroup -DisplayName $UATReaderGroup
                                    
        # Get the role definition
        $roleDefinition = Get-AzRoleDefinition -Name $ReaderRoleDefinitionName
          

        # Add the security group to the resource group with the Reader role assignment
        New-AzRoleAssignment -ObjectId $securityGroup.Id -RoleDefinitionId $roleDefinition.Id -Scope "/subscriptions/$subscriptionId/resourceGroups/$UATRG"
                    

        Write-Host "##[section]Security group $UATReaderGroup added to resource group $UATRG with role $ReaderRoleDefinitionName"
                                    
    }
    else {
        Write-Host "##[error]Failed to detect security group $UATReaderGroup please ensure it has been created in On-Prem AD"

    }
    $retry = 0
    # Loop until the Contributor group is available
    while (-not (Get-AzADGroup -DisplayName $UATContributorGroup) -and $retry -lt 10) {
        Write-Host "##[section]Waiting for security group $UATContributorGroup to be available.."
        $retry ++
        Start-Sleep -Seconds 600
        Write-Host "##[warning]$UATContributorGroup is not yet available trying for the $retry time"

    }
                                    
    if (Get-AzADGroup -DisplayName $UATContributorGroup) {
        # Get the Reader group object
        $securityGroup = Get-AzADGroup -DisplayName $UATContributorGroup
                                    
        # Get the role definition
        $roleDefinition = Get-AzRoleDefinition -Name $ContRoleDefinitionName
        $DNSroleDefinition = Get-AzRoleDefinition -Name $DNSRoleDefinitionName
        $NetworkroleDefinition = Get-AzRoleDefinition -Name $NetworkRoleDefinitionName
                                    
        # Add the security group to the resource group with the Contributor role assignment
        New-AzRoleAssignment -ObjectId $securityGroup.Id -RoleDefinitionId $roleDefinition.Id -Scope "/subscriptions/$subscriptionId/resourceGroups/$UATRG"
        New-AzRoleAssignment -ObjectId $securityGroup.Id -RoleDefinitionId $NetworkroleDefinition.Id -Scope "/subscriptions/$subscriptionId/resourceGroups/$BaseRGName"
        New-AzRoleAssignment -ObjectId $securityGroup.Id -RoleDefinitionId $DNSroleDefinition.Id -Scope "/subscriptions/dbabcaa6-b91a-4d21-bfcc-b1f0a5065d53/resourceGroups/san-plt-coredns"

        Write-Host "##[section]Security group $UATContributorGroup added to resource group $UATRG with role $ContRoleDefinitionName"
                                    
    }
    else {
        Write-Host "##[error]Failed to detect security group $UATContributorGroup please ensure it has been created in On-Prem AD"

    }

}
