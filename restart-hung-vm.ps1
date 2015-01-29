# Load Windows PowerShell cmdlets for VMware
add-psSnapin VMWare* | out-null

# Connect To vCenter
Connect-VIServer -Server ServerName -User UserName -Pass Password | Out-Null

# Test Connection to the VM and reset if no response

$vm = Get-VM -Name VMName
if(!(Test-Connection -ComputerName VmHostName -Quiet))
{
Stop-VM -VM $vm -Confirm:$false -Kill
Start-VM -VM $vm
}

# Disconnect from vCenter
Disconnect-VIServer -Confirm:$False
