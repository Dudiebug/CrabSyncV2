[CmdletBinding()]
param(
    [Parameter()]
    [string] $LuaExe
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$testFile = Join-Path $repoRoot 'tests\crabsyncv2_core_test.lua'

if (-not (Test-Path -LiteralPath $testFile -PathType Leaf)) {
    throw "CrabSyncV2 test file not found: $testFile"
}

if (-not $LuaExe) {
    foreach ($commandName in @('lua5.4', 'lua54', 'lua')) {
        $command = Get-Command $commandName -ErrorAction SilentlyContinue
        if ($command) {
            $LuaExe = $command.Source
            break
        }
    }
}

if (-not $LuaExe) {
    throw 'Lua 5.4 was not found. Pass -LuaExe C:\path\to\lua.exe.'
}

if ((Test-Path -LiteralPath $LuaExe -PathType Leaf) -eq $false) {
    $resolvedCommand = Get-Command $LuaExe -ErrorAction SilentlyContinue
    if (-not $resolvedCommand) {
        throw "Lua executable was not found: $LuaExe"
    }
    $LuaExe = $resolvedCommand.Source
}

Push-Location $repoRoot
try {
    & $LuaExe $testFile
    if ($LASTEXITCODE -ne 0) {
        throw "CrabSyncV2 Lua tests failed with exit code $LASTEXITCODE."
    }
}
finally {
    Pop-Location
}

Write-Host 'CrabSyncV2 core tests passed.'
