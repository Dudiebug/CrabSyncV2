[CmdletBinding()]
param(
    [string]$OutputDirectory,
    [string]$Version,
    [string]$UE4SSArchivePath,
    [string]$UE4SSVendorRoot,
    [switch]$Offline,
    [switch]$KeepStaging
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ue4ssVersion = 'v3.0.1'
$ue4ssAssetName = 'UE4SS_v3.0.1.zip'
$ue4ssAssetUrl = 'https://github.com/UE4SS-RE/RE-UE4SS/releases/download/v3.0.1/UE4SS_v3.0.1.zip'
$ue4ssAssetSha256 = '4B47D4BCEDDD2F561A4E395BFA00924CCFC945AF576A2D0C613E6537846C57EC'

# This is the minimal upstream subset shipped by CrabSyncV2. Hashes were
# computed from the pinned official UE4SS_v3.0.1.zip release asset.
$pinnedUE4SSFiles = [ordered]@{
    'dwmapi.dll'                                  = 'CE596412BEFA68C30B7F88F65BEB77D9BDAD55E9B96A276A5A9CF690C63F24BB'
    'UE4SS.dll'                                   = '8AC18FBFFC1EF96B0662D4A2D537B3F224C26D65CAABA7989A9404C566102B26'
    'Mods\Keybinds\Scripts\main.lua'             = '560E8FFFFE3B7E0378C63DB8A8F8DA6465397A098D554B3A1D38E95794E3EB48'
    'Mods\shared\UEHelpers\UEHelpers.lua'        = '0360091748880FE82AF01546F594561B771B5774304324E7665EC5738C9C6203'
}

function Resolve-FullPath {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$BasePath
    )

    $candidate = if ([System.IO.Path]::IsPathRooted($Path)) {
        $Path
    } else {
        Join-Path $BasePath $Path
    }
    return [System.IO.Path]::GetFullPath($candidate)
}

function Assert-FileHash {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$ExpectedSha256,
        [Parameter(Mandatory = $true)][string]$Label
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Missing ${Label}: $Path"
    }
    $actual = (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToUpperInvariant()
    if ($actual -ne $ExpectedSha256.ToUpperInvariant()) {
        throw "$Label SHA-256 mismatch. Expected $ExpectedSha256, got $actual ($Path)"
    }
}

function Copy-FileWithParent {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$Destination
    )

    $parent = Split-Path -Parent $Destination
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    Copy-Item -LiteralPath $Source -Destination $Destination -Force
}

function Get-OfficialArchive {
    param(
        [Parameter(Mandatory = $true)][string]$Destination,
        [Parameter(Mandatory = $true)][string]$Url
    )

    $lastError = $null
    for ($attempt = 1; $attempt -le 3; $attempt++) {
        try {
            if (Test-Path -LiteralPath $Destination) {
                Remove-Item -LiteralPath $Destination -Force
            }
            Write-Host "Downloading pinned UE4SS asset (attempt $attempt/3): $Url"
            Invoke-WebRequest -UseBasicParsing -Headers @{ 'User-Agent' = 'CrabSyncV2-release-packager' } -Uri $Url -OutFile $Destination
            return
        } catch {
            $lastError = $_
            if (Test-Path -LiteralPath $Destination) {
                Remove-Item -LiteralPath $Destination -Force
            }
            if ($attempt -lt 3) {
                Start-Sleep -Seconds 2
            }
        }
    }
    throw "Unable to download the pinned UE4SS asset after 3 attempts: $($lastError.Exception.Message)"
}

function Copy-SanitizedMod {
    param(
        [Parameter(Mandatory = $true)][string]$SourceRoot,
        [Parameter(Mandatory = $true)][string]$DestinationRoot
    )

    $sourceFull = [System.IO.Path]::GetFullPath($SourceRoot).TrimEnd('\', '/')
    if (-not (Test-Path -LiteralPath $sourceFull -PathType Container)) {
        throw "CrabSyncV2 source directory not found: $sourceFull"
    }

    $files = Get-ChildItem -LiteralPath $sourceFull -File -Recurse -Force
    foreach ($file in $files) {
        if (($file.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "Refusing to package reparse-point file: $($file.FullName)"
        }

        $relative = $file.FullName.Substring($sourceFull.Length).TrimStart('\', '/')
        $portable = $relative.Replace('\', '/')
        $name = $file.Name
        $isBackupDirectoryMarker = $portable -ieq 'Scripts/backups/README.txt'
        $excluded =
            (($portable -match '(^|/)(backups|logs|node_modules|\.git)(/|$)') -and -not $isBackupDirectoryMarker) -or
            $name -like 'push*.json' -or
            $name -like 'recv*.json' -or
            $name -like '*.log' -or
            $name -like '*.jsonl' -or
            $name -like '*.tmp' -or
            $name -like '*.bak' -or
            $name -ieq 'autolaunch.vbs'

        if ($excluded) {
            Write-Host "Skipping runtime/development artifact: $portable"
            continue
        }

        Copy-FileWithParent -Source $file.FullName -Destination (Join-Path $DestinationRoot $relative)
    }
}

function Remove-SafeTempWorkspace {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return
    }
    $full = [System.IO.Path]::GetFullPath($Path).TrimEnd('\', '/')
    $temp = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath()).TrimEnd('\', '/')
    $leaf = Split-Path -Leaf $full
    if (-not $full.StartsWith($temp + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase) -or
        -not $leaf.StartsWith('CrabSyncV2-release-', [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to recursively remove unexpected path: $full"
    }
    Remove-Item -LiteralPath $full -Recurse -Force
}

$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $repoRoot 'dist'
} else {
    $OutputDirectory = Resolve-FullPath -Path $OutputDirectory -BasePath $repoRoot
}

if ([string]::IsNullOrWhiteSpace($Version)) {
    $Version = if (-not [string]::IsNullOrWhiteSpace($env:GITHUB_REF_NAME)) {
        $env:GITHUB_REF_NAME
    } else {
        'experimental-local'
    }
}
$safeVersion = ($Version -replace '[^A-Za-z0-9._-]', '-').Trim('-')
if ([string]::IsNullOrWhiteSpace($safeVersion)) {
    throw "Version does not contain any filename-safe characters: $Version"
}

$sourceMod = Join-Path $repoRoot 'client\Mods\CrabSyncV2'
$sourceMain = Join-Path $sourceMod 'Scripts\main.lua'
$sourceConfig = Join-Path $sourceMod 'Scripts\config.txt'
$sourceEnabledMarker = Join-Path $sourceMod 'enabled.txt'
$sourceUE4SSSettings = Join-Path $repoRoot 'client\UE4SS-settings.ini'
$sourceImGuiSettings = Join-Path $repoRoot 'client\imgui.ini'
$modsTemplate = Join-Path $repoRoot 'packaging\CrabSyncV2-mods.txt'
$experimentalConfigExample = Join-Path $sourceMod 'Scripts\examples\experimental-full-p2p-sync.txt'
$installReadme = Join-Path $repoRoot 'README_INSTALL.txt'
$experimentalReadme = Join-Path $repoRoot 'README_EXPERIMENTAL_FULL_SYNC.txt'
$manualChecklist = Join-Path $repoRoot 'docs\CRABSYNCV2_MANUAL_TEST_CHECKLIST.md'
$implementationGuide = Join-Path $repoRoot 'docs\CRABSYNCV2_EXPERIMENTAL_P2P_IMPLEMENTATION.md'
$modLicense = Join-Path $repoRoot 'LICENSE'
$ue4ssLicense = Join-Path $repoRoot 'UE4SS-LICENSE.txt'
$ue4ssAttribution = Join-Path $repoRoot 'UE4SS-ATTRIBUTION.txt'
$verificationScript = Join-Path $repoRoot 'scripts\verify-crabsyncv2-release.ps1'

$requiredSources = @(
    $sourceMain,
    $sourceConfig,
    $sourceEnabledMarker,
    $sourceUE4SSSettings,
    $sourceImGuiSettings,
    $modsTemplate,
    $experimentalConfigExample,
    $installReadme,
    $experimentalReadme,
    $manualChecklist,
    $implementationGuide,
    $modLicense,
    $ue4ssLicense,
    $ue4ssAttribution,
    $verificationScript
)
foreach ($requiredSource in $requiredSources) {
    if (-not (Test-Path -LiteralPath $requiredSource -PathType Leaf)) {
        throw "Required release source file is missing: $requiredSource"
    }
}

$workspace = Join-Path ([System.IO.Path]::GetTempPath()) ("CrabSyncV2-release-" + [guid]::NewGuid().ToString('N'))
$stage = Join-Path $workspace 'stage'
$download = Join-Path $workspace $ue4ssAssetName
$extracted = Join-Path $workspace 'ue4ss'
$runtimeSource = $null
$runtimeSourceKind = $null
$outputZip = $null

New-Item -ItemType Directory -Path $stage -Force | Out-Null

try {
    $archive = $null
    if (-not [string]::IsNullOrWhiteSpace($UE4SSArchivePath)) {
        $archive = Resolve-FullPath -Path $UE4SSArchivePath -BasePath $repoRoot
        if (-not (Test-Path -LiteralPath $archive -PathType Leaf)) {
            throw "Explicit UE4SS archive not found: $archive"
        }
        $runtimeSourceKind = 'explicit-pinned-release-archive'
    } else {
        $defaultVendorArchive = Join-Path $repoRoot "vendor\ue4ss\v3.0.1\$ue4ssAssetName"
        if (Test-Path -LiteralPath $defaultVendorArchive -PathType Leaf) {
            $archive = $defaultVendorArchive
            $runtimeSourceKind = 'repository-vendor-pinned-release-archive'
        } elseif (-not $Offline) {
            try {
                Get-OfficialArchive -Destination $download -Url $ue4ssAssetUrl
                $archive = $download
                $runtimeSourceKind = 'downloaded-official-release-archive'
            } catch {
                Write-Warning $_.Exception.Message
                Write-Warning 'Falling back to a hash-verified expanded UE4SS vendor drop.'
            }
        }
    }

    if ($null -ne $archive) {
        Assert-FileHash -Path $archive -ExpectedSha256 $ue4ssAssetSha256 -Label "$ue4ssVersion release asset"
        New-Item -ItemType Directory -Path $extracted -Force | Out-Null
        Expand-Archive -LiteralPath $archive -DestinationPath $extracted -Force
        $runtimeSource = $extracted
    } else {
        if ([string]::IsNullOrWhiteSpace($UE4SSVendorRoot)) {
            $UE4SSVendorRoot = Join-Path $repoRoot 'client'
        } else {
            $UE4SSVendorRoot = Resolve-FullPath -Path $UE4SSVendorRoot -BasePath $repoRoot
        }
        if (-not (Test-Path -LiteralPath $UE4SSVendorRoot -PathType Container)) {
            $mode = if ($Offline) { 'Offline mode was requested and' } else { 'The official download failed and' }
            throw "$mode no expanded UE4SS vendor drop exists at: $UE4SSVendorRoot"
        }
        $runtimeSource = [System.IO.Path]::GetFullPath($UE4SSVendorRoot)
        $runtimeSourceKind = 'verified-expanded-vendor-drop'
    }

    foreach ($entry in $pinnedUE4SSFiles.GetEnumerator()) {
        $relative = [string]$entry.Key
        $source = Join-Path $runtimeSource $relative
        Assert-FileHash -Path $source -ExpectedSha256 ([string]$entry.Value) -Label "pinned UE4SS file $relative"
        Copy-FileWithParent -Source $source -Destination (Join-Path $stage $relative)
    }

    Copy-FileWithParent -Source $sourceUE4SSSettings -Destination (Join-Path $stage 'UE4SS-settings.ini')
    Copy-FileWithParent -Source $sourceImGuiSettings -Destination (Join-Path $stage 'imgui.ini')
    Copy-SanitizedMod -SourceRoot $sourceMod -DestinationRoot (Join-Path $stage 'Mods\CrabSyncV2')
    Copy-FileWithParent -Source $modsTemplate -Destination (Join-Path $stage 'Mods\mods.txt')

    Copy-FileWithParent -Source $installReadme -Destination (Join-Path $stage 'README_INSTALL.txt')
    Copy-FileWithParent -Source $experimentalReadme -Destination (Join-Path $stage 'README_EXPERIMENTAL_FULL_SYNC.txt')
    Copy-FileWithParent -Source $manualChecklist -Destination (Join-Path $stage 'CRABSYNCV2_MANUAL_TEST_CHECKLIST.md')
    Copy-FileWithParent -Source $implementationGuide -Destination (Join-Path $stage 'CRABSYNCV2_EXPERIMENTAL_P2P_IMPLEMENTATION.md')
    Copy-FileWithParent -Source $modLicense -Destination (Join-Path $stage 'LICENSE-CrabSyncV2.txt')
    Copy-FileWithParent -Source $ue4ssLicense -Destination (Join-Path $stage 'UE4SS-LICENSE.txt')
    Copy-FileWithParent -Source $ue4ssAttribution -Destination (Join-Path $stage 'UE4SS-ATTRIBUTION.txt')

    $manifestPath = Join-Path $stage 'RELEASE-MANIFEST.txt'
    $manifestLines = [System.Collections.Generic.List[string]]::new()
    $manifestLines.Add('# CrabSyncV2 release manifest v1')
    $manifestLines.Add("Package-Version: $Version")
    $manifestLines.Add("UE4SS-Version: $ue4ssVersion")
    $manifestLines.Add("UE4SS-Asset: $ue4ssAssetName")
    $manifestLines.Add("UE4SS-Asset-URL: $ue4ssAssetUrl")
    $manifestLines.Add("UE4SS-Asset-SHA256: $ue4ssAssetSha256")
    $manifestLines.Add("Runtime-Source: $runtimeSourceKind")
    $manifestLines.Add("Generated-UTC: $([DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ'))")
    $manifestLines.Add('# SHA256<TAB>Bytes<TAB>Path')

    $stageFull = [System.IO.Path]::GetFullPath($stage).TrimEnd('\', '/')
    $payloadFiles = Get-ChildItem -LiteralPath $stageFull -File -Recurse -Force | Sort-Object FullName
    foreach ($file in $payloadFiles) {
        $relative = $file.FullName.Substring($stageFull.Length).TrimStart('\', '/').Replace('\', '/')
        $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $file.FullName).Hash.ToUpperInvariant()
        $manifestLines.Add("$hash`t$($file.Length)`t$relative")
    }
    [System.IO.File]::WriteAllLines($manifestPath, $manifestLines, [System.Text.UTF8Encoding]::new($false))

    New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
    $outputZip = Join-Path $OutputDirectory "CrabSyncV2-$safeVersion-Win64.zip"
    if (Test-Path -LiteralPath $outputZip) {
        Remove-Item -LiteralPath $outputZip -Force
    }

    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::CreateFromDirectory(
        $stage,
        $outputZip,
        [System.IO.Compression.CompressionLevel]::Optimal,
        $false
    )

    try {
        & $verificationScript -ZipPath $outputZip
    } catch {
        if (Test-Path -LiteralPath $outputZip) {
            Remove-Item -LiteralPath $outputZip -Force
        }
        throw
    }

    $zipItem = Get-Item -LiteralPath $outputZip
    $zipHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $outputZip).Hash
    Write-Host "Created CrabSyncV2 release: $($zipItem.FullName)"
    Write-Host "Release ZIP size: $($zipItem.Length) bytes"
    Write-Host "Release ZIP SHA-256: $zipHash"
    Write-Host "UE4SS source: $runtimeSourceKind ($ue4ssVersion)"
    Write-Output $zipItem
} finally {
    if ($KeepStaging) {
        Write-Host "Kept staging workspace: $workspace"
    } else {
        Remove-SafeTempWorkspace -Path $workspace
    }
}
