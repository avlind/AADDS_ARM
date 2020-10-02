param ($rgName)

Get-AzResourceGroup -Name $rgName -ErrorVariable notPresent -ErrorAction SilentlyContinue
if ($notPresent)
{
    Write-Host 'No Such Resource Group Exists in target subscription context'
}
else
{
    New-AzResourceGroupDeployment -ResourceGroupName $rgname -TemplateFile .\armtemplate.empty.json -Mode Complete -Force
}
