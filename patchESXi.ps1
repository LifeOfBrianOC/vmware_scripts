##############################################
# Script to patch multiple hosts with a VIB
# Inspired by http://www.virtadmin.com/rolling-reboot-vsphere-cluster-powercli/
# Hosts are listed in a text file
# Requires Powercli
##############################################
# Region User Variables

# Set vCenter Hostname Variable. You will be asked for credentials when executing the script. e.g. "vc01.lab.local"
$vCenterServer = "ChangeME"

# Full Path to the text file with the list of ESXi hosts to be patched. e.g. "C:\Scripts\VIHosts.txt"
$VIHosts = "ChangeME"

# Full path to the VIB to be installed. Use a common shared datastore. Suggest a shared NFS/VMFS datastore. Copy the VIB to this location before starting. e.g. "/vmfs/volumes/NFS_Shared/patch1/metadata.zip"
$vibPath = "ChangeME"

# Full path to where you would like the script to create a log. e.g. "C:\Scripts"
$LogDIR = "ChangeME"

# End Region User Variables

# DO NOT MODIFY BELOW THIS LINE!
##############################################

# Load VMware PowerCLI CmdLets
Add-PSSnapin vmware* | Out-Null

$TargetDIR = "$LogDIR\log"
if(!(Test-Path -Path $TargetDIR )){
    New-Item -ItemType directory -Path $TargetDIR
}

$Logfile = "$TargetDIR\patchESXi-Log.txt"
if(!(Test-Path -Path $Logfile )){
    New-Item -ItemType file -Path $Logfile
}

Function verifyTXTPath {
# Verify TXT Path
		if (!(Test-Path $VIHosts))  {
		Write-Host "ESXi Hosts File Not Found. Please verify the path and retry
								             " -ForegroundColor Red
		Write-Host -NoNewLine 'Press any key to exit...' -ForegroundColor Yellow;
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');
Exit
		}
		  }


# Function to write Logfile entries
Function LogWrite
{
   Param ([string]$logstring)

   Add-content $Logfile -value $logstring
   }

   
# Connect to  the vCenter defined at the top of this script
Connect-VIServer -Server $vCenterServer | Out-Null

# Write progress to LogFile
LogWrite "$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") Connected to vCenter $vCenterServer"
 
# Get ESXi hostname from txt file
$ESXiServers = Get-Content $VIHosts | %{Get-VMHost $_}
 
# Install ESXi Patch Function
Function PatchESXiServer ($CurrentServer) {
    # Get ESXi Server name
    $ServerName = $CurrentServer.Name
 
    # Put server in maintenance mode
    Write-Host "** Patching $ServerName **"
    Write-Host "Entering Maintenance Mode"
    Set-VMhost $CurrentServer -State maintenance -Evacuate | Out-Null
	
# Write progress to LogFile
LogWrite "$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") Put ESXi host $CurrentServer in Maintenance Mode"
	
	# Install Patch
	Get-VMHost $CurrentServer | Install-VMHostPatch -Hostpath $vibPath

# Write progress to LogFile
LogWrite "$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") Installing Patch on $CurrentServer"
 
    # Reboot host
    Write-Host "Rebooting $ServerName"
    Restart-VMHost $CurrentServer -confirm:$false | Out-Null

# Write progress to LogFile
LogWrite "$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") Rebooting $CurrentServer"
	
    # Wait for Server to show as down
    do {
    sleep 15
    $ServerState = (get-vmhost $ServerName).ConnectionState
    }
    while ($ServerState -ne "NotResponding")
    Write-Host "$ServerName is Down"
 
    # Wait for server to reboot
    do {
    sleep 60
    $ServerState = (get-vmhost $ServerName).ConnectionState
    Write-Host "Waiting for $ServerName to Reboot ..."
    }
    while ($ServerState -ne "Maintenance")
    Write-Host "$ServerName is back up"
 
    # Exit maintenance mode
    Write-Host "Exiting Maintenance mode"
    Set-VMhost $CurrentServer -State Connected | Out-Null
    Write-Host "** Reboot Complete **"
    Write-Host ""
	
# Write progress to LogFile
LogWrite "$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") Exit ESXi host $CurrentServer from Maintenance Mode"
	
}
 
## MAIN
verifyTXTPath
foreach ($ESXiServer in $ESXiServers) {
PatchESXiServer ($ESXiServer)
}
 
# Disconnect from vCenter
Disconnect-VIServer -Server $vCenterServer -Confirm:$False

# Write progress to LogFile
LogWrite "$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") Disconnect from vCenter $vCenterServer"
