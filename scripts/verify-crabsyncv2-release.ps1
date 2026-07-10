[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$ZipPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$pinnedFiles = [ordered]@{
    'dwmapi.dll'                                   = 'CE596412BEFA68C30B7F88F65BEB77D9BDAD55E9B96A276A5A9CF690C63F24BB'
    'UE4SS.dll'                                    = '8AC18FBFFC1EF96B0662D4A2D537B3F224C26D65CAABA7989A9404C566102B26'
    'Mods\Keybinds\Scripts\main.lua'              = '560E8FFFFE3B7E0378C63DB8A8F8DA6465397A098D554B3A1D38E95794E3EB48'
    'Mods\shared\UEHelpers\UEHelpers.lua'         = '0360091748880FE82AF01546F594561B771B5774304324E7665EC5738C9C6203'
}

$safeConfig = [ordered]@{
    'enableCrabSyncV2'              = 'false'
    'transportMode'                 = 'disabled'
    'allowPeerVisibleStateRead'     = 'false'
    'allowCarrierDiscovery'         = 'false'
    'allowCarrierPublish'           = 'false'
    'allowCarrierReceive'           = 'false'
    'allowHealthRead'               = 'false'
    'allowEquipmentRead'            = 'false'
    'allowResourceRead'             = 'false'
    'allowInventoryRead'            = 'false'
    'allowInventoryItemTraversal'   = 'false'
    'allowMetadataRead'             = 'false'
    'allowEnhancementRead'          = 'false'
    'allowDebugLoopbackTransport'   = 'false'
    'allowApply'                    = 'false'
    'allowHealthApply'              = 'false'
    'allowEquipmentApply'           = 'false'
    'allowResourceApply'            = 'false'
    'allowInventoryApply'           = 'false'
    'allowMetadataApply'            = 'false'
    'allowEnhancementApply'         = 'false'
    'allowJoinedClientApply'        = 'false'
    'allowMultiplayerApply'         = 'false'
    'hostOnlyApply'                 = 'true'
    'dryRunApply'                   = 'true'
    'backupBeforeApply'             = 'true'
    'allowOfficialFunctionApply'    = 'false'
    'allowRawPropertyWrites'        = 'false'
    'allowRawInventoryWrites'       = 'false'
    'allowOnRepInventory'           = 'false'
    'allowOnRepCrystals'            = 'false'
    'allowClientRefreshPSUI'        = 'false'
    'debugCrashBreadcrumbs'         = 'false'
    'debugVerboseSnapshots'         = 'false'
}

$failures = [System.Collections.Generic.List[string]]::new()

function Add-Failure {
    param([Parameter(Mandatory = $true)][string]$Message)
    $script:failures.Add($Message)
}

function Get-ConfigValues {
    param([Parameter(Mandatory = $true)][string]$Path)

    $values = @{}
    foreach ($line in Get-Content -LiteralPath $Path) {
        if ($line -match '^\s*(?:#|;|$)') {
            continue
        }
        if ($line -match '^\s*([A-Za-z][A-Za-z0-9_]*)\s*=\s*(.*?)\s*$') {
            $value = ($Matches[2] -replace '\s+#.*$', '').Trim()
            if ($values.ContainsKey($Matches[1])) {
                Add-Failure "Duplicate config key in ${Path}: $($Matches[1])"
            }
            $values[$Matches[1]] = $value
        }
    }
    return $values
}

function Test-RequiredFile {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string]$RelativePath
    )

    $path = Join-Path $Root $RelativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        Add-Failure "Missing required release file: $RelativePath"
        return $false
    }
    Write-Host "[OK] $RelativePath"
    return $true
}

function Test-TextPattern {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Pattern,
        [Parameter(Mandatory = $true)][string]$Label
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        Add-Failure "Cannot verify ${Label}; file is missing: $Path"
        return
    }
    if (Select-String -LiteralPath $Path -Pattern $Pattern -Quiet) {
        Write-Host "[OK] $Label"
    } else {
        Add-Failure "Missing or incorrect ${Label}: $Path"
    }
}

function Remove-SafeVerifyWorkspace {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return
    }
    $full = [System.IO.Path]::GetFullPath($Path).TrimEnd('\', '/')
    $temp = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath()).TrimEnd('\', '/')
    $leaf = Split-Path -Leaf $full
    if (-not $full.StartsWith($temp + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase) -or
        -not $leaf.StartsWith('CrabSyncV2-verify-', [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to recursively remove unexpected verify path: $full"
    }
    Remove-Item -LiteralPath $full -Recurse -Force
}

$zipFull = if ([System.IO.Path]::IsPathRooted($ZipPath)) {
    [System.IO.Path]::GetFullPath($ZipPath)
} else {
    [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $ZipPath))
}
if (-not (Test-Path -LiteralPath $zipFull -PathType Leaf)) {
    throw "Release ZIP not found: $zipFull"
}
if ([System.IO.Path]::GetExtension($zipFull) -ine '.zip') {
    throw "Release path must be a ZIP file: $zipFull"
}

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$entryNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
$archive = [System.IO.Compression.ZipFile]::OpenRead($zipFull)
try {
    foreach ($entry in $archive.Entries) {
        $name = $entry.FullName.Replace('\', '/')
        if ([string]::IsNullOrWhiteSpace($name)) {
            Add-Failure 'ZIP contains an empty entry name.'
            continue
        }
        if ($name.StartsWith('/') -or $name -match '^[A-Za-z]:' -or $name.Contains([char]0)) {
            Add-Failure "ZIP contains an absolute/invalid entry: $name"
        }
        $segments = @($name.Split('/') | Where-Object { $_ -ne '' })
        if ($segments -contains '..' -or $segments -contains '.') {
            Add-Failure "ZIP contains a traversal entry: $name"
        }
        if (-not $entryNames.Add($name)) {
            Add-Failure "ZIP contains a duplicate case-insensitive entry: $name"
        }
        $isBackupDirectoryMarker = $name -ieq 'Mods/CrabSyncV2/Scripts/backups/README.txt'
        if ($name -match '(^|/)(server|node_modules)(/|$)' -or
            $name -match '(^|/)bridge\.ps1$' -or
            $name -match '(^|/)(push|recv)[^/]*\.json$' -or
            (($name -match '(^|/)(?:README(?:_[^/]*)?\.txt|CRABSYNCV2_.*\.md)$') -and -not $isBackupDirectoryMarker) -or
            (($name -match '(^|/)(backups|logs)/') -and -not $isBackupDirectoryMarker) -or
            $name -match '\.(?:log|jsonl)$' -or
            $name -match '(^|/)autolaunch\.vbs$') {
            Add-Failure "Release contains forbidden relay/runtime content: $name"
        }
        if ($name -match '^Mods/(CrabInventorySync|CrabSyncV1)(/|$)') {
            Add-Failure "Release contains a competing inventory-sync mod: $name"
        }
        if ($name -match '(^|/)xinput1_3\.dll$') {
            Add-Failure "Release contains obsolete UE4SS 2.x loader: $name"
        }
    }
} finally {
    $archive.Dispose()
}

$workspace = Join-Path ([System.IO.Path]::GetTempPath()) ("CrabSyncV2-verify-" + [guid]::NewGuid().ToString('N'))
$extractRoot = Join-Path $workspace 'extract'
New-Item -ItemType Directory -Path $extractRoot -Force | Out-Null

try {
    Expand-Archive -LiteralPath $zipFull -DestinationPath $extractRoot -Force

    $required = @(
        'dwmapi.dll',
        'UE4SS.dll',
        'UE4SS-settings.ini',
        'imgui.ini',
        'Mods\mods.txt',
        'Mods\Keybinds\Scripts\main.lua',
        'Mods\shared\UEHelpers\UEHelpers.lua',
        'Mods\CrabSyncV2\enabled.txt',
        'Mods\CrabSyncV2\Scripts\main.lua',
        'Mods\CrabSyncV2\Scripts\config.txt',
        'Mods\CrabSyncV2\Scripts\examples\diagnostics-only.txt',
        'Mods\CrabSyncV2\Scripts\examples\p2p-visible-dry-run.txt',
        'Mods\CrabSyncV2\Scripts\examples\carrier-discovery.txt',
        'Mods\CrabSyncV2\Scripts\examples\experimental-full-p2p-sync.txt',
        'Mods\CrabSyncV2\Scripts\backups\README.txt',
        'LICENSE-CrabSyncV2.txt',
        'UE4SS-LICENSE.txt',
        'UE4SS-ATTRIBUTION.txt',
        'RELEASE-MANIFEST.txt'
    )
    foreach ($relative in $required) {
        [void](Test-RequiredFile -Root $extractRoot -RelativePath $relative)
    }

    foreach ($entry in $pinnedFiles.GetEnumerator()) {
        $relative = [string]$entry.Key
        $path = Join-Path $extractRoot $relative
        if (Test-Path -LiteralPath $path -PathType Leaf) {
            $actual = (Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash.ToUpperInvariant()
            if ($actual -eq ([string]$entry.Value).ToUpperInvariant()) {
                Write-Host "[OK] pinned UE4SS hash: $relative"
            } else {
                Add-Failure "Pinned UE4SS hash mismatch for ${relative}: $actual"
            }
        }
    }

    $settingsPath = Join-Path $extractRoot 'UE4SS-settings.ini'
    Test-TextPattern -Path $settingsPath -Pattern '^\s*EnableHotReloadSystem\s*=\s*0\s*$' -Label 'UE4SS hot reload disabled'
    Test-TextPattern -Path $settingsPath -Pattern '^\s*ConsoleEnabled\s*=\s*0\s*$' -Label 'UE4SS external console disabled'
    Test-TextPattern -Path $settingsPath -Pattern '^\s*GuiConsoleVisible\s*=\s*0\s*$' -Label 'UE4SS GUI console hidden by default'
    Test-TextPattern -Path $settingsPath -Pattern '^\s*GUIUFunctionCaller\s*=\s*0\s*$' -Label 'UE4SS experimental function caller disabled'
    Test-TextPattern -Path $settingsPath -Pattern '^\s*LoadAllAssetsBeforeDumpingObjects\s*=\s*0\s*$' -Label 'unsafe object-dump asset loading disabled'
    Test-TextPattern -Path $settingsPath -Pattern '^\s*LoadAllAssetsBeforeGeneratingCXXHeaders\s*=\s*0\s*$' -Label 'unsafe CXX asset loading disabled'

    $configPath = Join-Path $extractRoot 'Mods\CrabSyncV2\Scripts\config.txt'
    if (Test-Path -LiteralPath $configPath -PathType Leaf) {
        $config = Get-ConfigValues -Path $configPath
        foreach ($entry in $safeConfig.GetEnumerator()) {
            $key = [string]$entry.Key
            $expected = [string]$entry.Value
            if (-not $config.ContainsKey($key)) {
                Add-Failure "Safe live config is missing required key: $key"
            } elseif ([string]$config[$key] -ine $expected) {
                Add-Failure "Unsafe live config value: $key=$($config[$key]) (expected $expected)"
            } else {
                Write-Host "[OK] safe config: $key=$expected"
            }
        }

        foreach ($key in @($config.Keys)) {
            if ($key -match '^allow.*(?:Apply|Write)' -and [string]$config[$key] -ieq 'true') {
                Add-Failure "Unrecognized/high-risk live config gate is enabled: $key=true"
            }
        }
    }

    $dryRunExamplePath = Join-Path $extractRoot 'Mods\CrabSyncV2\Scripts\examples\p2p-visible-dry-run.txt'
    if (Test-Path -LiteralPath $dryRunExamplePath -PathType Leaf) {
        $example = Get-ConfigValues -Path $dryRunExamplePath
        $expectedDryRun = [ordered]@{
            'enableCrabSyncV2' = 'true'
            'transportMode' = 'game_visible'
            'allowInventoryItemTraversal' = 'false'
            'allowApply' = 'true'
            'allowInventoryApply' = 'false'
            'allowJoinedClientApply' = 'false'
            'allowMultiplayerApply' = 'true'
            'hostOnlyApply' = 'true'
            'dryRunApply' = 'true'
            'backupBeforeApply' = 'true'
        }
        foreach ($entry in $expectedDryRun.GetEnumerator()) {
            if (-not $example.ContainsKey([string]$entry.Key) -or [string]$example[[string]$entry.Key] -ine [string]$entry.Value) {
                Add-Failure "Visible-state dry-run example has unexpected $($entry.Key); expected $($entry.Value)."
            }
        }
    }

    $carrierExamplePath = Join-Path $extractRoot 'Mods\CrabSyncV2\Scripts\examples\carrier-discovery.txt'
    if (Test-Path -LiteralPath $carrierExamplePath -PathType Leaf) {
        $example = Get-ConfigValues -Path $carrierExamplePath
        $expectedCarrier = [ordered]@{
            'transportMode' = 'p2p_carrier'
            'allowCarrierDiscovery' = 'true'
            'allowCarrierPublish' = 'false'
            'allowCarrierReceive' = 'false'
            'allowApply' = 'false'
            'dryRunApply' = 'true'
        }
        foreach ($entry in $expectedCarrier.GetEnumerator()) {
            if (-not $example.ContainsKey([string]$entry.Key) -or [string]$example[[string]$entry.Key] -ine [string]$entry.Value) {
                Add-Failure "Carrier-discovery example has unexpected $($entry.Key); expected $($entry.Value)."
            }
        }
    }

    $dangerExamplePath = Join-Path $extractRoot 'Mods\CrabSyncV2\Scripts\examples\experimental-full-p2p-sync.txt'
    if (Test-Path -LiteralPath $dangerExamplePath -PathType Leaf) {
        $example = Get-ConfigValues -Path $dangerExamplePath
        $expectedDanger = [ordered]@{
            'enableCrabSyncV2' = 'true'
            'transportMode' = 'game_visible'
            'allowCarrierPublish' = 'false'
            'allowCarrierReceive' = 'false'
            'allowInventoryItemTraversal' = 'true'
            'allowApply' = 'true'
            'allowInventoryApply' = 'true'
            'allowJoinedClientApply' = 'false'
            'allowMultiplayerApply' = 'true'
            'hostOnlyApply' = 'true'
            'dryRunApply' = 'false'
            'backupBeforeApply' = 'true'
            'allowRawPropertyWrites' = 'true'
            'allowRawInventoryWrites' = 'true'
        }
        foreach ($entry in $expectedDanger.GetEnumerator()) {
            if (-not $example.ContainsKey([string]$entry.Key) -or [string]$example[[string]$entry.Key] -ine [string]$entry.Value) {
                Add-Failure "Experimental full P2P example has unexpected $($entry.Key); expected $($entry.Value)."
            }
        }
        Test-TextPattern -Path $dangerExamplePath -Pattern '^#\s*DANGEROUS PRIVATE HOST TEST' -Label 'dangerous example warning'
    }

    $modsPath = Join-Path $extractRoot 'Mods\mods.txt'
    if (Test-Path -LiteralPath $modsPath -PathType Leaf) {
        $entries = @()
        foreach ($line in Get-Content -LiteralPath $modsPath) {
            if ($line -match '^\s*(?:;|#|$)') {
                continue
            }
            if ($line -match '^\s*([^:]+?)\s*:\s*([01])\s*$') {
                $entries += [pscustomobject]@{ Name = $Matches[1].Trim(); Enabled = $Matches[2] }
            }
        }
        $v2 = @($entries | Where-Object { $_.Name -ieq 'CrabSyncV2' })
        if ($v2.Count -ne 1 -or $v2[0].Enabled -ne '1') {
            Add-Failure 'Mods/mods.txt must contain exactly one enabled CrabSyncV2 entry.'
        } else {
            Write-Host '[OK] CrabSyncV2 is enabled in release mods.txt'
        }
        $competing = @($entries | Where-Object {
            $_.Enabled -eq '1' -and ($_.Name -ieq 'CrabInventorySync' -or $_.Name -ieq 'CrabSyncV1')
        })
        if ($competing.Count -gt 0) {
            Add-Failure "Competing inventory-sync mod enabled: $($competing.Name -join ', ')"
        }
    }

    $modLicensePath = Join-Path $extractRoot 'LICENSE-CrabSyncV2.txt'
    Test-TextPattern -Path $modLicensePath -Pattern '^MIT License\s*$' -Label 'CrabSyncV2 MIT license'
    $ue4ssLicensePath = Join-Path $extractRoot 'UE4SS-LICENSE.txt'
    Test-TextPattern -Path $ue4ssLicensePath -Pattern '^MIT License\s*$' -Label 'UE4SS MIT license'
    Test-TextPattern -Path $ue4ssLicensePath -Pattern 'Copyright \(c\) 2022 Narknon' -Label 'UE4SS copyright notice'
    $attributionPath = Join-Path $extractRoot 'UE4SS-ATTRIBUTION.txt'
    Test-TextPattern -Path $attributionPath -Pattern 'UE4SS_v3\.0\.1\.zip' -Label 'pinned UE4SS asset attribution'
    Test-TextPattern -Path $attributionPath -Pattern '4B47D4BCEDDD2F561A4E395BFA00924CCFC945AF576A2D0C613E6537846C57EC' -Label 'pinned UE4SS asset digest attribution'
    Test-TextPattern -Path $attributionPath -Pattern 'd935b5b23bac03b65c14ae38382b02007204cc2e' -Label 'pinned UE4SS source commit attribution'

    $manifestPath = Join-Path $extractRoot 'RELEASE-MANIFEST.txt'
    if (Test-Path -LiteralPath $manifestPath -PathType Leaf) {
        Test-TextPattern -Path $manifestPath -Pattern '^UE4SS-Version: v3\.0\.1$' -Label 'manifest UE4SS version'
        Test-TextPattern -Path $manifestPath -Pattern '^UE4SS-Asset-SHA256: 4B47D4BCEDDD2F561A4E395BFA00924CCFC945AF576A2D0C613E6537846C57EC$' -Label 'manifest UE4SS asset digest'

        $manifestPaths = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        $recordCount = 0
        foreach ($line in Get-Content -LiteralPath $manifestPath) {
            $match = [regex]::Match($line, '^(?<hash>[A-Fa-f0-9]{64})\t(?<bytes>[0-9]+)\t(?<path>.+)$')
            if (-not $match.Success) {
                continue
            }
            $recordCount++
            $relative = $match.Groups['path'].Value.Replace('\', '/')
            if ($relative -eq 'RELEASE-MANIFEST.txt') {
                Add-Failure 'Manifest must not claim a self-hash.'
                continue
            }
            if ($relative.StartsWith('/') -or $relative -match '^[A-Za-z]:' -or @($relative.Split('/')) -contains '..') {
                Add-Failure "Manifest contains unsafe path: $relative"
                continue
            }
            if (-not $manifestPaths.Add($relative)) {
                Add-Failure "Manifest contains duplicate path: $relative"
                continue
            }
            $filePath = Join-Path $extractRoot ($relative.Replace('/', [System.IO.Path]::DirectorySeparatorChar))
            if (-not (Test-Path -LiteralPath $filePath -PathType Leaf)) {
                Add-Failure "Manifest references missing file: $relative"
                continue
            }
            $item = Get-Item -LiteralPath $filePath
            if ([uint64]$item.Length -ne [uint64]$match.Groups['bytes'].Value) {
                Add-Failure "Manifest size mismatch: $relative"
            }
            $actualHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $filePath).Hash
            if ($actualHash -ine $match.Groups['hash'].Value) {
                Add-Failure "Manifest hash mismatch: $relative"
            }
        }

        $actualPayload = @(Get-ChildItem -LiteralPath $extractRoot -File -Recurse -Force | Where-Object { $_.FullName -ne $manifestPath })
        if ($recordCount -ne $actualPayload.Count) {
            Add-Failure "Manifest record count ($recordCount) does not match payload file count ($($actualPayload.Count))."
        } else {
            Write-Host "[OK] manifest covers all $recordCount payload files"
        }
    }

    if ($failures.Count -gt 0) {
        throw ("CrabSyncV2 release verification failed:`n - " + ($failures -join "`n - "))
    }

    $zipItem = Get-Item -LiteralPath $zipFull
    $zipHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $zipFull).Hash
    Write-Host "CrabSyncV2 release verification passed."
    Write-Host "ZIP: $zipFull"
    Write-Host "Size: $($zipItem.Length) bytes"
    Write-Host "SHA-256: $zipHash"
} finally {
    Remove-SafeVerifyWorkspace -Path $workspace
}
