# Script to shutdown & startup a vSAN cluster when vCenter/PSC are running on the cluster
# Created by Brian O'Connell | Dell EMC
# Provided with zero warranty! Please test before using in anger!
# @LifeOfBrianOC
# https://lifeofbrianoc.com/

## User Variables ##
$vCenterFQDN = "vcs01.domain.local"
$vCenterUser = "administrator@vsphere.local"
$vCenterPassword = "Password123!"
$Cluster = "MARVIN-Virtual-SAN-Cluster"
$VMList = @("VCS01", "PSC01")
$VMHosts = @("esxi04.domain.local", "esxi05.domain.local", "esxi06.domain.local", "esxi07.domain.local")
$VMHost = "esxi04.domain.local"
$VMHostUser = "root"
$VMHostPassword = "Password123!"

### DO NOT MODIFY ANYTHING BELOW THIS LINE ###

# Add Required PowerCli Snappins
Get-Module -ListAvailable VM* | Import-Module

# Function to Connect to VI Host (vCenter or ESXi). Pass host, username & password to the function
Function ConnectVIServer ($VIHost, $User, $Password) {
    Write-Host " "
    Write-Host "Connecting to $vCenterFQDN..." -Foregroundcolor yellow
    Connect-VIServer $VIHost -User $User -Password $Password | Out-Null
	Write-Host "Connected to $VIHost..." -Foregroundcolor Green
    Write-Host "------------------------------------------------" -Foregroundcolor Green
}

# Define DRS Levels to stop Vms from moving away from the defined host
$PartiallyAutomated = "PartiallyAutomated"
$FullyAutomated = "FullyAutomated"

# Function to Change DRS Automation level						
Function ChangeDRSLevel ($Level) {						

    Write-Host " "
    Write-Host "Changing cluster DRS Automation Level to Partially Automated" -Foregroundcolor yellow
    Get-Cluster $cluster | Set-Cluster -DrsAutomation $Level -confirm:$false | Out-Null
    Write-Host "------------------------------------------------" -Foregroundcolor yellow
}
						
# Function to Move the Vms to a defined host so they can be easily found when starting back up
Function MoveVMs {

    Foreach ($VM in $VMList) {
        # Power down VM
        Write-Host " "
        Write-Host "Moving $VM to $VMHost" -Foregroundcolor yellow
        Get-VM $VM | Move-VM -Destination $VMHost -Confirm:$false | Out-Null
        Write-Host "------------------------------------------------" -Foregroundcolor yellow
    }   
    Disconnect-VIServer $vCenterFQDN -confirm:$false | Out-Null
}

# Function to Shutdown VMs
Function ShutdownVM  {

    Foreach ($VM in $VMList) {
        # Power down VM
        Write-Host " "
        Write-Host "Shutting down $VM" -Foregroundcolor yellow
        Shutdown-VMGuest $VM -Confirm:$false | Out-Null
        Write-Host "------------------------------------------------" -Foregroundcolor yellow
        Write-Host " "
        Write-Host "Waiting for $VM to be Shutdown" -Foregroundcolor yellow
        # Check VM powerstate and wait until it is powered off before proceeding with the next VM
        do {
            sleep 15
            $powerState = (get-vm $VM).PowerState
        }
        while ($powerState -eq "PoweredOn")
        Write-Host " "
        Write-Host "$VM Shutdown.." -Foregroundcolor green
        Write-Host "------------------------------------------------" -Foregroundcolor yellow	
    }
}

# Function to put all ESXi hosts into maintenance mode with the No Action flag for vSAN data rebuilds
Function EnterMaintenanceMode {

    Foreach ($VMHost in $VMHosts) {
        Connect-VIServer $VMHost -User root -Password $VMHostPassword | Out-Null
        # Put Host into Maintenance Mode
        Write-Host " "
        Write-Host "Putting $VMHost into Maintenance Mode" -Foregroundcolor yellow
        Get-View -ViewType HostSystem -Filter @{"Name" = $VMHost }|?{!$_.Runtime.InMaintenanceMode}|%{$_.EnterMaintenanceMode(0, $false, (new-object VMware.Vim.HostMaintenanceSpec -Property @{vsanMode=(new-object VMware.Vim.VsanHostDecommissionMode -Property @{objectAction=[VMware.Vim.VsanHostDecommissionModeObjectAction]::NoAction})}))}
        Disconnect-VIServer $VMHost -confirm:$false | Out-Null
        Write-Host "------------------------------------------------" -Foregroundcolor yellow
        Write-Host " "
        Write-Host "$VMHost in maintenance mode.." -Foregroundcolor green
        Write-Host "------------------------------------------------" -Foregroundcolor yellow	
    }
}

# Function to Exit hosts from maintenance mode
Function ExitMaintenanceMode {

    Foreach ($VMHost in $VMHosts) {
        Connect-VIServer $VMHost -User root -Password $VMHostPassword | Out-Null
        # Exit Maintenance Mode
        Write-Host " "
        Write-Host "Exiting Maintenance Mode for $VMHost" -Foregroundcolor yellow
        Set-VMHost $VMHost -State "Connected" | Out-Null
        Disconnect-VIServer $VMHost -confirm:$false | Out-Null
        Write-Host "------------------------------------------------" -Foregroundcolor yellow
        Write-Host " "
        Write-Host "$VMHost out of maintenance mode.." -Foregroundcolor green
        Write-Host "------------------------------------------------" -Foregroundcolor yellow	
    }
    Write-Host "Waiting for vSAN Cluster to be Online" -Foregroundcolor yellow	
	Sleep 60							
}

# Function to shutdown hosts
Function ShutdownESXiHosts {

    Foreach ($VMHost in $VMHosts) {
        # Exit Maintenance Mode
        Write-Host " "
        Write-Host "Shutting down ESXi Hosts" -Foregroundcolor yellow
        Connect-VIServer -Server $VMHost -User root -Password $VMHostPassword | %{
            Get-VMHost -Server $_ | %{
                $_.ExtensionData.ShutdownHost_Task($TRUE) | Out-Null
            }
        }
        Write-Host "------------------------------------------------" -Foregroundcolor yellow
        Write-Host " "
        Write-Host "ESXi host $VMHost shutdown.." -Foregroundcolor green
        Write-Host "------------------------------------------------" -Foregroundcolor yellow	
    }
		Write-Host "------------------------------------------------" -Foregroundcolor yellow
        Write-Host " "
        Write-Host "All ESXi Hosts shutdown.." -Foregroundcolor green
        Write-Host "------------------------------------------------" -Foregroundcolor yellow
# Call AnyKey Function
AnyKey
}

# Function to Start VMs in the reverse order they were powered down									
Function StartVMs {
    # Reverse the VM list to start in reverse order
    [array]::Reverse($VMList)

    Foreach ($VM in $VMList) {
        # Power on VM
        Write-Host " "
        Write-Host "Powering on $VM" -Foregroundcolor yellow
        Start-VM $VM -Confirm:$false | Out-Null
        Write-Host "------------------------------------------------" -Foregroundcolor yellow
        Write-Host " "
        Write-Host "Waiting for $VM to be Powered On" -Foregroundcolor yellow
        # Check VM powerstate and wait until it is powered on before proceeding with the next VM
        do {
            sleep 15
            $powerState = (get-vm $VM).PowerState
        }
        while ($VM -eq "PoweredOff")
        Write-Host " "
        Write-Host "$VM Powered On..proceeding with next VM" -Foregroundcolor green
        Write-Host "------------------------------------------------" -Foregroundcolor yellow	
    }

}

# Function to Poll the status of vCenter after starting up the VM
Function PollvCenter {

    do 
    {
        try 
        {
            Write-Host " "
            Write-Host "Polling vCenter $vCenterFQDN Availability...." -ForegroundColor Yellow
            Write-Host "------------------------------------------------" -Foregroundcolor yellow
            # Create Web Request
            [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
            $HTTP_Request = [System.Net.WebRequest]::Create("https://$($vCenterFQDN):9443")

            # Get a response
            $HTTP_Response = $HTTP_Request.GetResponse()

            # Get the HTTP code
            $HTTP_Status = [int]$HTTP_Response.StatusCode

            If ($HTTP_Status -eq 200) { 
                Write-Host " "
                Write-Host "vCenter $vCenterFQDN is Available!"  -ForegroundColor Green
                Write-Host "------------------------------------------------" -Foregroundcolor Green
                # Close HTTP request
                $HTTP_Response.Close()
            }
        }
        catch { 
            Write-Host " "
            Write-Host "vCenter $vCenterFQDN Not Available Yet...Retrying Poll..."  -ForegroundColor Cyan
            Write-Host "------------------------------------------------" -Foregroundcolor Cyan
    } }
    While ($HTTP_Status -ne 200)	
}

# Function to display the main menu 
Function Menu 
{
    Clear-Host         
    Do
    {
        Clear-Host                                                                        
        Write-Host -Object 'Please choose an option'
        Write-Host     -Object '**********************'	
        Write-Host -Object 'vCenter & vSAN Maintenance Options' -Foregroundcolor Yellow
        Write-Host     -Object '**********************'
        Write-Host -Object '1.  Shutdown vSAN Cluster & PSC/vCenter '
        Write-Host -Object ''
        Write-Host -Object '2.  Startup vSAN Cluster & PSC/vCenter '
        Write-Host -Object ''
        Write-Host -Object 'Q.  Exit'
        Write-Host -Object $errout
        $Menu = Read-Host -Prompt '(Enter 1 - 2 or Q to quit)'

        switch ($Menu) 
        {
            1 
            {
				ConnectVIServer $vCenterFQDN $vCenterUser $vCenterPassword
                ChangeDRSLevel $PartiallyAutomated
                MoveVMs
                ConnectVIServer $VMHost $VMHostUser $VMHostPassword
                ShutdownVM
                EnterMaintenanceMode
                ShutdownESXiHosts   
            }
            2 
            { 
				ExitMaintenanceMode
                ConnectVIServer $VMHost $VMHostUser $VMHostPassword
                StartVMs
				PollvCenter
                ConnectVIServer $vCenterFQDN $vCenterUser $vCenterPassword
                ChangeDRSLevel $FullyAutomated
            }
            Q 
            {
                Exit
            }	
            default 
            {
                $errout = 'Invalid option please try again........Try 1-2 or Q only'
            }

        }
    }
    until ($Menu -eq 'q')
}   

# Launch The Menu
Menu
