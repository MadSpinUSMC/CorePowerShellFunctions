<#	
	.NOTES
	===========================================================================
	 Created on:   	3/31/2017 11:49 AM
	 Created by:   	spledger
	 Organization: 	West Monroe Partners
	 Filename:     	Secure-Credentials.PS1
	 Version:		1.0
	===========================================================================
	
	This document is protected under the copyright laws of the United States
	and other countries as an unpublished work. This document contains
	information that is proprietary and confidential to West Monroe Partners, LLC
	or its alliance partners, which shall not be disclosed outside or duplicated,
	used, or disclosed in whole or in part for any purpose other than to evaluate
	West Monroe Partners, LLC and its performance on a particular engagement. Any
	use or disclosure in whole or in part of this information without the express
	written permission of West Monroe Partners, LLC is prohibited.

	© 2017 West Monroe Partners, LLC. All rights reserved.	

	.DESCRIPTION
		This is intended to create and store secure credentials in the Windows Registry
		To use this, the credentials will be assigned a name, which will bet set in the registry under the current user.
#>

#Usage: Add-SecureCredentials -CredentialName
#This function is used to add credentials to the secure credential
Function Add-SecureCredentials ()
{
	##Function is intended to set credentials if they do not currently exist
	##Usage Add-SecureCredentials -CredentialName "CredentialName"
	param (
		[Parameter(Mandatory = $False)][string]$CredentialName
	) #End Parameter
	
	If (!($CredentialName))
		{
		$CredentialName = Read-Host "Please provide a name for this credential"
			Do
			{
				$Confirm = Read-Host "Would you like to create a credential called $CredentialName (Y/N)"
			}
			Until ($Confirm.ToUpper() -eq "Y" -or $Confirm.ToUpper() -eq "N")
		IF ($Confirm.ToUpper() -eq "N") { Write-Host "Operation Cancelled" -F Yellow; Return $NULL }
	}
	
	#Check if the credenital already exists
	IF (Test-Path HKCU:\Software\WMP\SecureCredentials\$CredentialName)
		{
		$OverWrite = $False
			Do
			{
			$OverWrite = Read-Host "$CredentialName already exists, would you like to overwrite? (Y/N)"
			}
			Until ($OverWrite.ToUpper() -eq "Y" -or $OverWrite.ToUpper() -eq "N")
		
		IF ($OverWrite.ToUpper() -eq "N") { Write-Host "Operation Cancelled" -F Yellow; Return $NULL }
		Else{ Remove-Item HKCU:\Software\WMP\SecureCredentials\$CredentialName -Force | Out-Null}
	}
	
	$Description = Read-Host "Please proide a description for what these are used for"
	
	#Create Registry Key to hold credentials
		New-Item HKCU:\Software\WMP\SecureCredentials -Name $CredentialName -Force | Out-Null
	
	#Prompt for credentials
	$Credentials = Get-Credential -Message "Please Provide Credentials for $CredentialName"
	
	Write-Host "Adding Credentials for $CredentialName"
	#Save Credentials to Registry
	New-ItemProperty -Path HKCU:\Software\WMP\SecureCredentials\$CredentialName -Name "Description" -Value $Description -PropertyType String | Out-Null
	New-ItemProperty -Path HKCU:\Software\WMP\SecureCredentials\$CredentialName -Name "UserName" -Value $Credentials.UserName -PropertyType String | Out-Null
	New-ItemProperty -Path HKCU:\Software\WMP\SecureCredentials\$CredentialName -Name "SecurePassword" -Value ($Credentials.Password | ConvertFrom-SecureString) -PropertyType String | Out-Null
}


#Usage List-SecureCredentials
#This function will list all availiable secure credentials
function List-SecureCredentials ()
{
	#This function is meant to enumerate the current credentials on this system
	$Credentials = Get-ChildItem HKCU:\Software\WMP\SecureCredentials\
	$ArrCreds = @()
	foreach ($Credential in $Credentials)
	{
		$Hash = [ordered]@{
			CredentialName = $Credential.PSChildName
			UserName = (Get-ItemProperty -Path ("HKCU:\Software\WMP\SecureCredentials\" + $Credential.PSChildName)).UserName
			Description = (Get-ItemProperty -Path ("HKCU:\Software\WMP\SecureCredentials\" + $Credential.PSChildName)).Description
			}
		$ArrCreds += New-Object PSObject -Property $Hash
	}
	
	Return $arrCreds
}

#Usage: Get-SecureCredential -CredentialName CredentialName
#Note User the List-SecureCredentials to list out available credentials
Function Get-SecureCredential()
{
	param (
		[Parameter(Mandatory = $True)][string]$CredentialName
	) #End Parameter
	
	IF (!(Test-Path ("HKCU:\Software\WMP\SecureCredentials\" + $CredentialName)))
		{
		#Credential Name was not found
		Write-Warning -Message "$CredentialName was not found, please run the List-SecureCredential to show availiable credentials, or Add-SecureCredentials to create them."
		Return $NULL
		}
	
	$UserName = (Get-ItemProperty -Path ("HKCU:\Software\WMP\SecureCredentials\" + $CredentialName)).UserName
	$SecurePassword = (Get-ItemProperty -Path ("HKCU:\Software\WMP\SecureCredentials\" + $CredentialName)).SecurePassword | ConvertTo-SecureString
	Return (New-Object System.Management.Automation.PSCredential -ArgumentList $UserName, $SecurePassword)
}


#Usage: Remove-SecureCredentials
Function Remove-SecureCredentials ()
{
	$RemoveCredential = List-SecureCredentials | Out-GridView -Title "Please select a credential to remove." -Passthru
	
	$Delete = $False
	Do
	{
		$Delete = Read-Host "Would you like to remove "$RemoveCredential.CredentialName"? (Y/N)"
	}
	Until ($Delete.ToUpper() -eq "Y" -or $Delete.ToUpper() -eq "N")
	
	IF ($Delete.ToUpper() -eq "Y") { Remove-Item ("HKCU:\Software\WMP\SecureCredentials\" + $RemoveCredential.CredentialName) -Force }
	
	IF (!(Test-Path ("HKCU:\Software\WMP\SecureCredentials\" + $RemoveCredential.CredentialName)))
		{
		Write-Host $RemoveCredential.CredentialName "was successfully deleted." -F GREEN
		}
	Else
	{
		Write-Error -Message ("Unable to remove " + $RemoveCredential + "Please check the registry to manually delete HKCU:\Software\WMP\SecureCredentials\" + $RemoveCredential.CredentialName)
		
	}
}
