param([string]$Server, [string]$AppName, [string]$BackupDir, [string]$WebsiteFiles, [string]$Configuration, [string]$WebsiteName, [string]$AppPoolName, [string]$BackupSubfolder="")
Add-Type -assembly "system.io.compression.filesystem"
. .\BuildScripts\AnsiColors.ps1
. .\BuildScripts\IisHelpers.ps1

Write-Host $InfoBlue"***** Delivering Build *****"$ResetBlack

# Jenkins Environment Variables.
$WORKSPACE = "$env:WORKSPACE"
$BUILD_NUMBER = "$env:BUILD_NUMBER"

$WebsiteFilesZip = $WebsiteFiles + $Configuration + ".zip"

if(![string]::IsNullOrEmpty($BackupSubfolder)) {
	$BackupSubfolder += "\"
}

$FormattedDate = Get-Date -format yyyy.MM.dd
$BackupDirPath = $BackupDir + $FormattedDate + "\" + $BackupSubfolder + $AppName
$BackupDirPathWithBuild = $BackupDirPath + "\" + $BUILD_NUMBER
$WebsiteBackupFilesZipPath = $BackupDirPathWithBuild + "\" + $AppName + "Backup.zip"

$ReleaseDirPath = $WORKSPACE + "\" + $Configuration

Write-Host $InfoBlue"> > > > Preparing backup..."$ResetBlack
If (Test-Path $BackupDirPath) {
	try {
		# Rolling backups.
		$prevBuilds = Get-ChildItem $BackupDirPath -recurse -directory
		if($prevBuilds.Count -gt 3) {
			Write-Host $InfoBlue"> > > > Removing outdated backups..."$ResetBlack
			foreach ($name in $prevBuilds)
			{
				$name = $name | select -expand Name
				$diff = $BUILD_NUMBER - [int]$name
			
				if($diff -gt 2)
				{
					$ToRemove = $BackupDirPath + "\" + $name
					Remove-Item $ToRemove -Recurse -ErrorAction Stop
				}
			}
		}
	} catch {
		Write-Host $ErrorRed"> > > > Failed to remove previous backups!"
		throw $LASTEXITCODE
	}
}

try {
	New-Item $BackupDirPathWithBuild -ItemType Dir -ErrorAction Stop
} catch {
	Write-Host $ErrorRed"> > > > Failed to create new backup folder!"
	throw $LASTEXITCODE
}

Write-Host $InfoBlue"> > > > Shutting down IIS app pool and website..."$ResetBlack
TurnOffIisWebsite -Server $Server -AppPoolName $AppPoolName -WebsiteName $WebsiteName -WaitTime 0

# Archiving and backing up old website files.
Write-Host $InfoBlue"> > > > Archiving old website files..."$ResetBlack
try {
	[io.compression.zipfile]::CreateFromDirectory($WebsiteFiles, $WebsiteBackupFilesZipPath)
} catch {
	Write-Host $ErrorRed"> > > > Failed to package old website files!"
	Write-Host $InfoMagenta"> > > > Rolling back and turning on IIS app pool and website..."$ResetBlack
	TurnOnIisWebsite -Server $Server -AppPoolName $AppPoolName -WebsiteName $WebsiteName -WaitTime 5
	throw $LASTEXITCODE
}

Write-Host $InfoBlue"> > > > Removing old website files..."$ResetBlack
Get-ChildItem -Path $WebsiteFiles -Recurse| Foreach-object {
	try {
		Remove-item -Recurse -path $_.FullName -ErrorAction Stop
	} catch {
		Write-Host $ErrorRed"> > > > Failed to remove old website files!"
		throw $LASTEXITCODE
	}
}

# Copying build package to IIS website folder.
Write-Host $InfoBlue"> > > > Copying build package to: "$ResetBlack$WebsiteFiles
robocopy $ReleaseDirPath $WebsiteFiles /MIR

If (Test-Path $WebsiteFilesZip) {

	Write-Host $InfoBlue"> > > > Unarchiving new website files at: "$ResetBlack$WebsiteFiles
	try {
		[System.IO.Compression.ZipFile]::ExtractToDirectory($WebsiteFilesZip, $WebsiteFiles)
	} catch {
		Write-Host $ErrorRed"> > > > Failed to unpackage website files!"
		throw $LASTEXITCODE
	}
	
	try	{
		Remove-Item $WebsiteFilesZip
	} catch {
		Write-Host $ErrorRed"> > > > Failed to clean up after unpackaging!"$ResetBlack
	}
} else {
	Write-Host $ErrorRed"> > > > Failed to copy release package!"
	throw $LASTEXITCODE
}

# Waiting 5 secs before turning on site and app pool.
TurnOnIisWebsite -Server $Server -AppPoolName $AppPoolName -WebsiteName $WebsiteName -WaitTime 5
