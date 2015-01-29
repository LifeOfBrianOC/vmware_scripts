# This script will add multiple esxi hosts hased on their names
# In the example below it will add esx218.lab.local to esx225.lab.local

# Add multiple hosts
218..225 | Foreach-Object { Add-VMHost esx$_.lab.local -Location (Get-Datacenter DataCenterName) -User vcenterAdminUserName -Password vcenterAdminUserPassword -RunAsync -force:$true}
