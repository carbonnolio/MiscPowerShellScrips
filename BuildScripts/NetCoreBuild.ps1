param([string]$CodebasePath, [string[]]$Dependencies, [string]$TargetProjectPath, [string]$Configuration, [string]$ProjectTestsPath)
Add-Type -assembly "system.io.compression.filesystem"
. .\BuildScripts\AnsiColors.ps1

Write-Host $InfoBlue"***** Starting Build *****"$ResetBlack

# Jenkins workspace.
$WORKSPACE = "$env:WORKSPACE"

$ReleasePrepDirPath = $WORKSPACE + "\" + $Configuration + "Prep"
$ReleaseDirPath = $WORKSPACE + "\" + $Configuration
$ReleaseDirPathZip = $ReleaseDirPath + "\" + $Configuration + ".zip"

Write-Host $InfoBlue"> > > > Preparing release folder..."$ResetBlack
If(!(test-path $ReleaseDirPath))
{
	New-Item -ItemType Directory -Force -Path $ReleaseDirPath
}

If (Test-Path $ReleasePrepDirPath) {
	try {
		Remove-Item $ReleasePrepDirPath -Recurse -ErrorAction Stop
	} catch {
		Write-Host $ErrorRed"> > > > Failed to clear previous release folder content: "$ReleasePrepDirPath
		throw $LASTEXITCODE
	}
}

If (Test-Path $ReleaseDirPathZip) {
	try {
		Remove-Item $ReleaseDirPathZip -ErrorAction Stop
	} catch {
		Write-Host $ErrorRed"> > > > Failed to clear previous release zip package: "$ReleaseDirPathZip
		throw $LASTEXITCODE
	}
}
# Running build.
Write-Host $InfoBlue"> > > > Restoring NuGet packages..."$ResetBlack$dep
dotnet restore $CodebasePath

if($Dependencies) {
	Write-Host $InfoBlue"> > > > Build dependencies found!"$ResetBlack$dep
	$SplitDependencies = $Dependencies.split(',')

	foreach ($dep in $SplitDependencies) {
		Write-Host $InfoBlue"> > > > Building dependency: "$ResetBlack$dep
		dotnet build $dep --configuration $Configuration --no-dependencies
		
		if($LASTEXITCODE -gt 0) {
			Write-Host $ErrorRed"> > > > Failed to build dependency: "$dep
			throw $LASTEXITCODE
		}
	}
}

Write-Host $InfoBlue"> > > > Building project: "$ResetBlack$dep
dotnet build $TargetProjectPath --configuration $Configuration --no-dependencies -r win10-x64

if($LASTEXITCODE -gt 0) {
	Write-Host $ErrorRed"> > > > Failed to build project!"
	throw $LASTEXITCODE
}

if($ProjectTestsPath) {
	Write-Host $InfoBlue"> > > > Running unit tests..."$ResetBlack$dep
	dotnet test $ProjectTestsPath
	
	if($LASTEXITCODE -gt 0) {
		Write-Host $ErrorRed"> > > > Unit tests failed!"
		throw $LASTEXITCODE
	}
}

Write-Host $InfoBlue"> > > > Publishing: "$ResetBlack$dep
dotnet publish $TargetProjectPath --configuration $Configuration -r win10-x64 --output $ReleasePrepDirPath

if($LASTEXITCODE -gt 0) {
	Write-Host $ErrorRed"> > > > Failed to publish project!"
	throw $LASTEXITCODE
}

# Archiving build output.
Write-Host $InfoBlue"> > > > Creating release package..."$ResetBlack
try {
	[io.compression.zipfile]::CreateFromDirectory($ReleasePrepDirPath, $ReleaseDirPathZip)
} catch {
	Write-Host $ErrorRed"> > > > Failed to create release zip package!"
	throw $LASTEXITCODE
}