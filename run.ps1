#Requires -Version 5.1
<#
Launch the checked-out project. On Windows, download and verify the standard
Godot 4.6.3 engine into the user's local application cache on first use.
#>
[CmdletBinding()]
param(
    [switch]$RunTests,
    [switch]$ImportOnly,
    [string]$GodotPath = ''
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$antProjectRoot = $PSScriptRoot

function Invoke-AntGodot {
    param([string[]]$EngineArguments)
    # Arguments here are engine flags and filesystem paths, which contain no
    # quote characters. Quote each so paths containing spaces remain intact.
    $antArgumentString = ($EngineArguments | ForEach-Object { '"' + $_ + '"' }) -join ' '
    $antLaunch = @{
        FilePath = $script:antEngine
        ArgumentList = $antArgumentString
        Wait = $true
        PassThru = $true
        NoNewWindow = $true
    }
    $antProcess = Start-Process @antLaunch
    if ($antProcess.ExitCode -ne 0) {
        throw ('Godot exited with code ' + $antProcess.ExitCode + '.')
    }
}

try {
    if ($GodotPath) {
        $antEngine = (Get-Item -LiteralPath $GodotPath).FullName
    } else {
        if ($env:OS -ne 'Windows_NT') {
            throw 'Use ./launch.sh on Linux or macOS, or pass -GodotPath with your Godot executable.'
        }
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $antCache = Join-Path $env:LOCALAPPDATA 'AntSimulator\Godot-4.6.3'
        New-Item -ItemType Directory -Path $antCache -Force | Out-Null
        $antZip = Join-Path $antCache 'Godot.zip'
        $antExpected = 'd44ea7ef5bab754cacd49d581b6062836b2eea12a82e1d183aebfad9cd8c7db2bd82513337bd657d6d2d5c04d46239c0570b029faf1343e81e8a2fa7b85dd83b'
        $antZipValid = (Test-Path -LiteralPath $antZip) -and ((Get-FileHash -LiteralPath $antZip -Algorithm SHA512).Hash.ToLowerInvariant() -eq $antExpected)
        if (-not $antZipValid) {
            Write-Host 'Downloading the official Godot 4.6.3 engine (first launch only)...'
            $antDownload = $antZip + '.download'
            Invoke-WebRequest -UseBasicParsing -Uri 'https://github.com/godotengine/godot-builds/releases/download/4.6.3-stable/Godot_v4.6.3-stable_win64.exe.zip' -OutFile $antDownload
            if ((Get-FileHash -LiteralPath $antDownload -Algorithm SHA512).Hash.ToLowerInvariant() -ne $antExpected) {
                throw 'The engine download failed its SHA-512 verification. Please run the launcher again.'
            }
            Move-Item -LiteralPath $antDownload -Destination $antZip -Force
        }
        $antEngine = Join-Path $antCache 'Godot_v4.6.3-stable_win64.exe'
        if (-not (Test-Path -LiteralPath $antEngine)) {
            Expand-Archive -LiteralPath $antZip -DestinationPath $antCache -Force
        }
        if (-not (Test-Path -LiteralPath $antEngine)) {
            throw 'The downloaded engine could not be extracted.'
        }
    }

    Write-Host 'Preparing the ant simulator...'
    $antImportLog = Join-Path $antProjectRoot 'import.log'
    Invoke-AntGodot -EngineArguments @('--headless', '--editor', '--import', '--quit', '--path', $antProjectRoot, '--log-file', $antImportLog)
    if ((Test-Path -LiteralPath $antImportLog) -and (Select-String -LiteralPath $antImportLog -Pattern 'SCRIPT ERROR:|Parse Error:|ERROR: Failed to load script' -Quiet)) {
        throw ('Godot could not import the project. See ' + $antImportLog)
    }
    if ($RunTests) {
        Invoke-AntGodot -EngineArguments @('--headless', '--path', $antProjectRoot, '--script', 'res://tests/run_tests.gd')
        Invoke-AntGodot -EngineArguments @('--headless', '--path', $antProjectRoot, '--script', 'res://tests/app_smoke.gd')
        Write-Host 'All simulation and application checks passed.' -ForegroundColor Green
    } elseif (-not $ImportOnly) {
        Start-Process -FilePath $antEngine -ArgumentList ('--path "' + $antProjectRoot + '"')
        Write-Host 'Simulator started. Space pauses; H opens the controls guide.' -ForegroundColor Green
    }
} catch {
    Write-Error -ErrorAction Continue $_.Exception.Message
    exit 1
}
