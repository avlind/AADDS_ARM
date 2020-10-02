param ($rgName)

$RgLocation = "East US"
$AADJoiningUPN = "domainjoin@aaronmsdn.onmicrosoft.com"
function DeployTemplate
{
    New-AzResourceGroupDeployment -ResourceGroupName $rgname -TemplateFile .\armtemplate.json -TemplateParameterFile .\armtemplate.parameters.json -Confirm
}
function SetupAADDSPreReqs
{
    Register-AzResourceProvider -ProviderNamespace Microsoft.AAD
    New-AzADServicePrincipal -ApplicationId "2565bd9d-da50-47d4-8b85-4c97f669dc36" -ErrorAction SilentlyContinue
    $GroupObjectID = Get-AzADGroup -DisplayName "AAD DC Administrators"
    
    if (-not $GroupObjectID) {
        New-AzADGroup -DisplayName "AAD DC Administrators" -Description "Delegated group to administer Azure AD Domain Services" -MailNickName "AADDCAdministrators"
        $GroupObjectID = Get-AzADGroup -DisplayName "AAD DC Administrators"
    }

    $UserObjectId = Get-AzADUser -UserPrincipalName $AADJoiningUPN 

    # Add the user to the 'AAD DC Administrators' group.
    Add-AzADGroupMember  -TargetGRoupObjectId $GroupObjectId.Id -MemberObjectId $UserObjectId.Id -ErrorAction SilentlyContinue
}

Get-AzResourceGroup -Name $rgName -ErrorVariable notPresentRG -ErrorAction SilentlyContinue

if ($notPresentRG) {
    Write-Host 'No Such Resource Group Exists in target subscription context'
    $PerformCreate = Read-Host -Prompt "Do you want to create the resource group `"$rgName`" and deploy the ARM template? [y/n]"
    if ($PerformCreate.ToLower().Trim() -eq 'y') {
        New-AzResourceGroup -Name $rgName -Location $RgLocation
        SetupAADDSPreReqs
        DeployTemplate
    }
    else {
        Write-Host 'Did not create resource group'
    }
}
else {
    SetupAADDSPreReqs
    DeployTemplate
}

