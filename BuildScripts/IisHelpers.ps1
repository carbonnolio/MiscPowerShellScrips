. .\BuildScripts\AnsiColors.ps1

function TurnOnIisWebsite ([string]$Server, [string]$AppPoolName, [string]$WebsiteName, [int]$WaitTime) {
	
	if($WaitTime -gt 0) {
		Start-Sleep -s $WaitTime
	}
	
	Invoke-Command -ComputerName $Server -ScriptBlock { 
		try {
			Start-WebAppPool -Name $using:AppPoolName -ErrorAction Stop
		} catch {
			Write-Host $ErrorRed"> > > > Failed to turn on app pool!"
			throw $LASTEXITCODE
		}
	}
	Invoke-Command -ComputerName $Server -ScriptBlock { 
		try {
			Import-Module WebAdministration -ErrorAction Stop
			Start-Website $using:WebsiteName -ErrorAction Stop
		} catch {
			Write-Host $ErrorRed"> > > > Failed to turn on website!"
			throw $LASTEXITCODE
		}
	}
}

function TurnOffIisWebsite ([string]$Server, [string]$AppPoolName, [string]$WebsiteName, [int]$WaitTime) {
	
	if($WaitTime -gt 0) {
		Start-Sleep -s $WaitTime
	}
	
	Invoke-Command -ComputerName $Server -ScriptBlock { 
		try {
			Import-Module WebAdministration -ErrorAction Stop
			Stop-Website $using:WebsiteName -ErrorAction Stop
		} catch {
			Write-Host $ErrorRed"> > > > Failed to shut down website!"
			throw $LASTEXITCODE
		}
	}
	Invoke-Command -ComputerName $Server -ScriptBlock {
		try {
			Stop-WebAppPool -Name $using:AppPoolName -ErrorAction Stop
		} catch {
			Write-Host $ErrorRed"> > > > Failed to shut down app pool!"
			throw $LASTEXITCODE
		}
	}
}