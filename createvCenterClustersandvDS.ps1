# Script to create vCenter Clusters, Distributed Switches & portgroups from CSV
# Edit the CSV location variable and the vCenter FQDN and run the script
# Tested with PowerCli 6.3.0
# This is version 1.0 There is no error checking in place so if an item 
# already exists or cannot be found the script will error but should continue


$CSVPath = "C:\Scripts\Example.csv"
$vCenter = "vc01.domain.local"

########################################################################
# DO NOT EDIT ANYTHING BELOW THIS LINE
########################################################################

# Load VMware PowerCli Snapins
add-psSnapin VMWare* | out-null

# Connect to vCenter
Connect-VIserver $vCenter

# Get vCenter Datacenter Name
$datacenter = Get-Datacenter

@"
===============================================================================
Creating Clusters
===============================================================================
"@

# Import CSV and only read lines that have an entry in clusterName column
    $csv = @()
    $csv = Import-Csv -Path $CSVPath |
    Where-Object -FilterScript {
        $_.clusterName
    }

    # Loop through all _s in the CSV
    ForEach ($_ in $csv)
    {
	New-Cluster -Location $datacenter -Name $_.clusterName -HAEnabled | out-null
	}
						 						
@"
===============================================================================
Creating Distributed Switches
===============================================================================
"@	

# Import CSV and only read lines that have an entry in switchName column
    $csv = @()
    $csv = Import-Csv -Path $CSVPath |
    Where-Object -FilterScript {
        $_.switchName
    }

    # Loop through all _s in the CSV
    ForEach ($_ in $csv) 	
    {
	Import-Module VMware.VimAutomation.Vds
	New-VDSwitch -Location $datacenter -Name $_.switchName -Mtu 1600 | out-null
	}

@"
===============================================================================
Creating Distributed Switch Portgroups & Assigning VLANs
===============================================================================
"@

# Import CSV and only read lines that have an entry in portgroupName column
    $csv = @()
    $csv = Import-Csv -Path $CSVPath |
    Where-Object -FilterScript {
        $_.portgroupName
    }

    # Loop through all _s in the CSV
    ForEach ($_ in $csv) 
    {
	Import-Module VMware.VimAutomation.Vds
	New-VDPortgroup -Name $_.portgroupName -VDSwitch $_.addToSwitch -VlanId $_.vlan | out-null
	}

	
@"
===============================================================================
Setting Trunk Ports
===============================================================================
"@		

# Import CSV and only read lines that have an entry in trunkPortgroup column
    $csv = @()
    $csv = Import-Csv -Path $CSVPath |
    Where-Object -FilterScript {
        $_.trunkPortgroup
    }

    # Loop through all _s in the CSV
    ForEach ($_ in $csv) 
    {
	Import-Module VMware.VimAutomation.Vds
	Set-VDPortgroup $_.trunkPortgroup -VlanTrunkRange $_.trunkRange | out-null
	}
	
@"
===============================================================================
Disconnecting from vCenter....Done!
===============================================================================
"@	
# Disconnect vCenter
Disconnect-VIServer $vCenter
