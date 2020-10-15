param ($rgName)

#Where to deploy the resource group
$RgLocation = "East US"
#AAD UserID that will be used to join machines to the managed domain
$AADJoiningUPN = "domainjoin@aaronmsdn.onmicrosoft.com"
#staging password for the domain join AAD UserID
$AADJoiningUPNPW = "Pa55.w0rd!"

function DeployTemplate {
    New-AzResourceGroupDeployment -ResourceGroupName $rgname -TemplateFile .\armtemplate.json -TemplateParameterFile .\armtemplate.parameters.json -Confirm
}
function SetupAADDSPreReqs {
    Register-AzResourceProvider -ProviderNamespace Microsoft.AAD
    Write-Host 'Resource provider has been registered' -ForegroundColor Green


    # Look for an existing ServicePrincipal for the ApplicationId
    $ServicePrincipal = Get-AzADServicePrincipal -ApplicationId "2565bd9d-da50-47d4-8b85-4c97f669dc36"
    
    if($ServicePrincipal)
    {
        Write-Host 'Service Principal already exists.' -ForegroundColor Yellow
    }

    if (-not $ServicePrincipal) {
        Write-Host 'No Service Principal found. Creating a new one... ' -ForegroundColor Yellow -NoNewLine

        # Create the service principal, set the role to Owner
        New-AzADServicePrincipal -ApplicationId "2565bd9d-da50-47d4-8b85-4c97f669dc36" -Role Owner 
        Write-Host 'Created new Service Principal.' -ForegroundColor Green
	
    }

    # Get the Group Object
    $GroupObjectID = Get-AzADGroup -DisplayName "AAD DC Administrators"

if($GroupObjectID)
{
    Write-Host 'Group already exists.' -ForegroundColor Yellow
}
    
    if (-not $GroupObjectId) {
        Write-Host 'Did not find GroupObjectId. Creating a new one... ' -ForegroundColor Yellow -NoNewLine 
        New-AzADGroup -DisplayName "AAD DC Administrators" -Description "Delegated group to administer Azure AD Domain Services" -MailNickName "AADDCAdministrators"
        Write-Host 'Created new Azure AD Group.'

        # Set the group to the local variable
        $GroupObjectId = Get-AzADGroup -DisplayName "AAD DC Administrators"

    }

    # Look for an existing domain joining account
    $UserObjectId = Get-AzADUser -UserPrincipalName $AADJoiningUPN 
    Write-Host 'Looking for domain joining account.' -ForegroundColor -Yellow
    
    if ($UserObjectId) {
        Write-Host 'Domain Join account exists in AAD.' -ForegroundColor Yellow
    }

    # Create Domain Join Acct 
    if (-not $UserObjectId) {
        Write-Host 'Did not find domain joining account. Creating one... ' -ForegroundColor Yellow -NoNewLine
        $SecureStringPassword = ConvertTo-SecureString -String $AADJoiningUPNPW -AsPlainText -Force
        New-AzADUser -DisplayName "Domain Join Acct" -UserPrincipalName "domainjoin@aaronmsdn.onmicrosoft.com" -Password $SecureStringPassword -MailNickname "DomainJoin"
        $UserObjectId = Get-AzADUser -UserPrincipalName $AADJoiningUPN
        Write-Host 'Created domain joining account.' -ForegroundColor Green
    }

    # Add the user to the 'AAD DC Administrators' group.
    Add-AzADGroupMember -TargetGroupObjectId $GroupObjectId.Id -MemberObjectId $UserObjectId.Id
    Write-Host 'Added the domain joining account to the Azure AD group.' -ForegroundColor Green
}

#Check if RG Exists Already
Get-AzResourceGroup -Name $rgName -ErrorVariable notPresentRG -ErrorAction SilentlyContinue

#RG goes not exist, prompt for creation
if ($notPresentRG) {
    Write-Host 'No Such Resource Group Exists in target subscription context'
    $PerformCreate = Read-Host -Prompt "Do you want to create the resource group `"$rgName`" and deploy the ARM template? [y/n]"
    if ($PerformCreate.ToLower().Trim() -eq 'y') {
        New-AzResourceGroup -Name $rgName -Location $RgLocation
        
        #Set up the pre reqs
        SetupAADDSPreReqs
        Write-Host 'Pre reqs are setup' -ForegroundColor Green
        
        # Deploy the template
        DeployTemplate
        Write-Host 'Template is deployed' -ForegroundColor Green
    }
    else {
        Write-Host 'Did not create resource group' - -ForegroundColor Yellow
    }
}
#RG exists. Move forward with deployment
else {
    #Set up the pre reqs
    SetupAADDSPreReqs
    Write-Host 'Pre reqs are setup' -ForegroundColor Green
        
    # Deploy the template
    DeployTemplate
    Write-Host 'Template is deployed' -ForegroundColor Green
}

