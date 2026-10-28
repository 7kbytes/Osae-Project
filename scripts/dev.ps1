# Run from any directory: powershell -File scripts/dev.ps1 doctor
[CmdletBinding()]
param([ValidateSet('doctor','setup','check','build','rules','typecheck')][string]$Task = 'doctor', [switch]$Plan)
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot -Parent
function Run([string]$Exe, [string[]]$Arguments) {
    Write-Host (('> ' + $Exe + ' ' + ($Arguments -join ' ')))
    if ($Plan) { return }
    & $Exe @Arguments
    if ($LASTEXITCODE -ne 0) { throw "$Exe exited with code $LASTEXITCODE" }
}
function Need([string[]]$Tools) {
    $missing = @()
    foreach ($tool in $Tools) {
        $found = Get-Command $tool -ErrorAction SilentlyContinue
        if ($found) { Write-Host ('OK ' + $tool + ': ' + $found.Source) }
        else { $missing += $tool; Write-Warning ('Missing: ' + $tool) }
    }
    if ($missing.Count) { throw ('Missing tools: ' + ($missing -join ', ')) }
}
Push-Location $repoRoot
try {

    $managedFlutter = 'C:\Users\Administrator\Documents\Codex\tools\flutter-3.44.9\bin'
    if (-not (Get-Command flutter -ErrorAction SilentlyContinue) -and (Test-Path "$managedFlutter/flutter.bat")) {
        $env:PATH = "$managedFlutter;$env:PATH"
    }
    # Flutter invokes Git internally. Limit the sandbox ownership exception to this process.
    if (Test-Path "$managedFlutter/flutter.bat") {
        $configIndex = 0
        if ($env:GIT_CONFIG_COUNT) { $configIndex = [int]$env:GIT_CONFIG_COUNT }
        [Environment]::SetEnvironmentVariable("GIT_CONFIG_KEY_$configIndex", 'safe.directory', 'Process')
        [Environment]::SetEnvironmentVariable("GIT_CONFIG_VALUE_$configIndex", (Split-Path $managedFlutter -Parent).Replace('\','/'), 'Process')
        $env:GIT_CONFIG_COUNT = [string]($configIndex + 1)
    }
    $javaRoot = 'C:\Users\Administrator\Documents\Codex\tools\java21'
    if (-not (Get-Command java -ErrorAction SilentlyContinue) -and (Test-Path $javaRoot)) {
        $jdk = Get-ChildItem $javaRoot -Directory | Where-Object { Test-Path (Join-Path $_.FullName 'bin/java.exe') } | Select-Object -First 1
        if ($jdk) { $env:JAVA_HOME = $jdk.FullName; $env:PATH = "$($jdk.FullName)/bin;$env:PATH" }
    }
    if (-not $env:PUB_CACHE -and (Test-Path "$managedFlutter/flutter.bat")) { $env:PUB_CACHE = 'C:\Users\Administrator\Documents\Codex\tools\pub-cache' }
    switch ($Task) {
        'doctor' {
            Need @('flutter','dart','node','npm','firebase','java')
            Run 'flutter' @('doctor','-v')
        }
        'setup' {
            Run 'flutter' @('pub','get','--enforce-lockfile')
            Push-Location 'rules-tests'
            try { Run 'npm' @('ci') } finally { Pop-Location }
        }
        'check' {
            Run 'dart' @('format','--output=none','--set-exit-if-changed','lib','test')
            Run 'flutter' @('analyze')
            Run 'flutter' @('test')
        }
        'build' { Run 'flutter' @('build','web','--release') }
        'rules' {
            Need @('java','firebase')
            # Emulator-only runs need no account state; keep CLI cache writes in a writable folder.
            $env:XDG_CONFIG_HOME = Join-Path $repoRoot 'node_modules/.cache/firebase-emulator-config'
            $env:NO_UPDATE_NOTIFIER = '1'
            New-Item -ItemType Directory -Force $env:XDG_CONFIG_HOME | Out-Null
            # rules-tests/package.json fixes the target to demo-ljc, never the production project.
            Push-Location 'rules-tests'
            try { Run 'npm' @('test') } finally { Pop-Location }
        }
        default { throw "$Task is not supported here. Use doctor, setup, check, build, or rules." }
    }

} finally { Pop-Location }
