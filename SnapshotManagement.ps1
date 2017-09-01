# User Variables
$vCenterFQDN = "vcs01.domain.local"
$vCenterUser = "administrator@vsphere.local"
$vCenterPassword = "Password123!"
$VMList = @("vra01", "vra02", "web01", "web02", "mgr01", "mgr02", "dem01", "dem02", "agt01", "agt02")
$SnapshotName = "Snap01"
###############################
# DO NOT EDIT BELOW THIS LINE #
###############################

# Add Required Snappins
Get-Module -ListAvailable VM* | Import-Module

Function CreateVMSnapshot {
# Connect to vCenter
Connect-VIServer $vCenterFQDN -username $vCenterUser -password $vCenterPassword
	Foreach ($VM in $VMList) {
	Write-Host "Creating Snapshot for $VM"
	New-Snapshot -VM $VM -Memory -quiesce -Name $SnapshotName -RunAsync
							 }
Disconnect-VIServer $vCenterFQDN							 
									}
									
Function RevertLastVMSnapshot {
# Connect to vCenter
Connect-VIServer $vCenterFQDN -username $vCenterUser -password $vCenterPassword
	Foreach ($VM in $VMList) {
	Write-Host "Reverting Snapshot for $VM"
	$snap = Get-Snapshot -VM $VM | Sort-Object -Property Created -Descending | Select -First 1
    Set-VM -VM $vm -SnapShot $snap -Confirm:$false  -RunAsync | Out-Null
							 }
#Disconnect-VIServer $vCenterFQDN							 
									}

Function RevertSpecificVMSnapshot {
# Connect to vCenter
Connect-VIServer $vCenterFQDN -username $vCenterUser -password $vCenterPassword
	Foreach ($VM in $VMList) {
	Write-Host "Reverting Snapshot for $VM"
	#$snap = Get-Snapshot -VM $VM | Sort-Object -Property Created -Descending | Select -First 1
    Set-VM -VM $vm -SnapShot $SnapshotName -Confirm:$false  -RunAsync | Out-Null
							 }
#Disconnect-VIServer $vCenterFQDN							 
									}									

Function anyKey 
{
    Write-Host -NoNewline -Object 'Press any key to return to the main menu...' -ForegroundColor Yellow
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    Menu
}
									
Function Menu 
{
    Clear-Host         
    Do
    {
        Clear-Host                                                                        
        Write-Host -Object 'Please choose an option'
        Write-Host     -Object '**********************'	
        Write-Host -Object 'Snapshot VM Options' -ForegroundColor Yellow
        Write-Host     -Object '**********************'
        Write-Host -Object '1.  Snapshot VMs '
		Write-Host -Object ''
        Write-Host -Object '2.  Revert to Last Snapshot '
		Write-Host -Object ''
		Write-Host -Object '3.  Revert To Specific Snapshot '
		Write-Host -Object ''
        Write-Host -Object '4.  Exit'
        Write-Host -Object $errout
        $Menu = Read-Host -Prompt '(0-3)'

        switch ($Menu) 
        {
           1 
            {
                CreateVMSnapshot 			
                anyKey
            }
            2 
            {
                RevertLastVMSnapshot
                anyKey
            }
			3 
            {
                RevertSpecificVMSnapshot
                anyKey
            }
            4 
            {
                Exit
			}	
            default 
            {
                $errout = 'Invalid option please try again........Try 0-4 only'
            }

        }
    }
    until ($Menu -ne '')
}   

# Launch The Menu
Menu
