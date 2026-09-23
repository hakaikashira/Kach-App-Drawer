# ============================================================
# Floating Glass App Drawer
# DiscoverApps.ps1
#
# Discovers Windows applications from:
#   - Start Menu shortcuts
#   - Desktop shortcuts
#   - Installed programs
#   - Windows AppsFolder / StartApps
#
# Generates PNG icons for:
#   - Normal EXE applications
#   - Windows AppID applications
#
# Writes:
#   @Resources\Data\Apps.inc
#   @Resources\Icons\app_N.png
# ============================================================

$ErrorActionPreference = 'SilentlyContinue'

# ------------------------------------------------------------
# Paths
# ------------------------------------------------------------

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$skinRoot   = Split-Path -Parent $scriptRoot

$dataDir  = Join-Path -Path $scriptRoot -ChildPath 'Data'
$iconDir  = Join-Path -Path $scriptRoot -ChildPath 'Icons'
$appsFile = Join-Path -Path $dataDir   -ChildPath 'Apps.inc'

New-Item -ItemType Directory -Force -Path $dataDir | Out-Null
New-Item -ItemType Directory -Force -Path $iconDir | Out-Null

# ------------------------------------------------------------
# Load System.Drawing
# ------------------------------------------------------------

Add-Type -AssemblyName System.Drawing

# ------------------------------------------------------------
# Native Windows Shell icon extraction
# ------------------------------------------------------------

$iconClass = @'
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;

public static class RainmeterShellIcon
{
    [StructLayout(LayoutKind.Sequential)]
    struct SIZE
    {
        public int cx;
        public int cy;

        public SIZE(int x, int y)
        {
            cx = x;
            cy = y;
        }
    }

    [Flags]
    enum SIIGBF
    {
        SIIGBF_RESIZETOFIT = 0x00,
        SIIGBF_BIGGERSIZEOK = 0x01,
        SIIGBF_MEMORYONLY = 0x02,
        SIIGBF_ICONONLY = 0x04,
        SIIGBF_THUMBNAILONLY = 0x08,
        SIIGBF_INCACHEONLY = 0x10,
        SIIGBF_CROPTOSQUARE = 0x20,
        SIIGBF_WIDETHUMBNAILS = 0x40,
        SIIGBF_ICONBACKGROUND = 0x80,
        SIIGBF_SCALEUP = 0x100
    }

    [ComImport]
    [Guid("BCC18B79-BA16-442F-80C4-8A59C30C463B")]
    [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IShellItemImageFactory
    {
        void GetImage(
            SIZE size,
            SIIGBF flags,
            out IntPtr phbm
        );
    }

    [DllImport(
        "shell32.dll",
        CharSet = CharSet.Unicode,
        PreserveSig = false
    )]
    static extern void SHCreateItemFromParsingName(
        string pszPath,
        IntPtr pbc,
        ref Guid riid,
        [MarshalAs(UnmanagedType.Interface)]
        out IShellItemImageFactory ppv
    );

    [DllImport("gdi32.dll")]
    static extern bool DeleteObject(IntPtr hObject);

    public static bool SaveIcon(
        string path,
        string output,
        int size
    )
    {
        try
        {
            Guid guid =
                new Guid("BCC18B79-BA16-442F-80C4-8A59C30C463B");

            IShellItemImageFactory factory;

            SHCreateItemFromParsingName(
                path,
                IntPtr.Zero,
                ref guid,
                out factory
            );

            IntPtr hBitmap;

            factory.GetImage(
                new SIZE(size, size),
                SIIGBF.SIIGBF_RESIZETOFIT |
                SIIGBF.SIIGBF_ICONONLY |
                SIIGBF.SIIGBF_SCALEUP,
                out hBitmap
            );

            if (hBitmap == IntPtr.Zero)
                return false;

            using (Bitmap bitmap =
                Bitmap.FromHbitmap(hBitmap))
            {
                bitmap.Save(
                    output,
                    ImageFormat.Png
                );
            }

            DeleteObject(hBitmap);

            return true;
        }
        catch
        {
            return false;
        }
    }
}
'@

try {
    Add-Type -TypeDefinition $iconClass -ReferencedAssemblies @(
        'System.Drawing'
    )
}
catch {
    # Type may already exist during repeated execution.
}

# ------------------------------------------------------------
# Helpers
# ------------------------------------------------------------

function Clean-Text {
    param(
        [string]$Value
    )

    if ($null -eq $Value) {
        return ''
    }

    return $Value.Replace("`r", '').Replace("`n", '').Trim()
}

function Get-SafeName {
    param(
        [string]$Value
    )

    $value = Clean-Text $Value

    if ([string]::IsNullOrWhiteSpace($value)) {
        return 'Unknown'
    }

    return $value
}

function Test-BadAppName {
    param(
        [string]$Name
    )

    $n = $Name.ToLowerInvariant()

    $badWords = @(
        'uninstall',
        'uninstaller',
        'setup',
        'installer',
        'install',
        'repair',
        'modify',
        'update',
        'updater',
        'updating',
        'redistributable',
        'runtime',
        'helper',
        'crash',
        'reporter',
        'maintenance',
        'driver',
        'service',
        'bootstrap',
        'launcher service'
    )

    foreach ($word in $badWords) {
        if ($n -like "*$word*") {
            return $true
        }
    }

    return $false
}

function Test-BadPath {
    param(
        [string]$Path
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $true
    }

    $p = $Path.ToLowerInvariant()

    $badParts = @(
        '\uninstall',
        '\installer',
        '\installers',
        '\setup',
        '\updates',
        '\updater',
        '\update\',
        '\maintenance',
        '\redist',
        '\redistributable',
        '\vcredist'
    )

    foreach ($part in $badParts) {
        if ($p.Contains($part)) {
            return $true
        }
    }

    return $false
}

function Get-DisplayNameFromExe {
    param(
        [string]$Path
    )

    try {
        if (-not (Test-Path -LiteralPath $Path)) {
            return $null
        }

        $info = [System.Diagnostics.FileVersionInfo]::GetVersionInfo(
            $Path
        )

        if (-not [string]::IsNullOrWhiteSpace($info.ProductName)) {
            return Clean-Text $info.ProductName
        }

        if (-not [string]::IsNullOrWhiteSpace($info.FileDescription)) {
            return Clean-Text $info.FileDescription
        }
    }
    catch {
    }

    return $null
}

# ------------------------------------------------------------
# Icon generation
# ------------------------------------------------------------

$script:IconsGenerated = 0

function Save-ExeIcon {
    param(
        [string]$ExePath,
        [string]$OutputPath
    )

    try {
        if (-not (Test-Path -LiteralPath $ExePath)) {
            return $false
        }

        $icon = [System.Drawing.Icon]::ExtractAssociatedIcon(
            $ExePath
        )

        if ($null -eq $icon) {
            return $false
        }

        try {
            $bitmap = $icon.ToBitmap()

            try {
                $bitmap.Save(
                    $OutputPath,
                    [System.Drawing.Imaging.ImageFormat]::Png
                )
            }
            finally {
                $bitmap.Dispose()
            }
        }
        finally {
            $icon.Dispose()
        }

        if (Test-Path -LiteralPath $OutputPath) {
            $script:IconsGenerated++
            return $true
        }
    }
    catch {
    }

    return $false
}

function Save-ShellIcon {
    param(
        [string]$ShellPath,
        [string]$OutputPath
    )

    try {
        $success = [RainmeterShellIcon]::SaveIcon(
            $ShellPath,
            $OutputPath,
            96
        )

        if ($success -and
            (Test-Path -LiteralPath $OutputPath)) {

            $script:IconsGenerated++
            return $true
        }
    }
    catch {
    }

    return $false
}

# ------------------------------------------------------------
# Application collection
# ------------------------------------------------------------

$apps = New-Object System.Collections.Generic.List[object]

function Add-ExeApp {
    param(
        [string]$Name,
        [string]$Path,
        [int]$Desktop
    )

    $Name = Get-SafeName $Name
    $Path = Clean-Text $Path

    if ([string]::IsNullOrWhiteSpace($Name)) {
        return
    }

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return
    }

    if (-not (Test-Path -LiteralPath $Path)) {
        return
    }

    if (Test-BadAppName $Name) {
        return
    }

    if (Test-BadPath $Path) {
        return
    }

    if (-not $Path.ToLowerInvariant().EndsWith('.exe')) {
        return
    }

    $existing = $apps |
        Where-Object {
            $_.Type -eq 'Exe' -and
            $_.Path -ieq $Path
        } |
        Select-Object -First 1

    if ($null -ne $existing) {

        if ($Desktop -eq 1) {
            $existing.Desktop = 1
        }

        return
    }

    $apps.Add(
        [PSCustomObject]@{
            Name    = $Name
            Path    = $Path
            Type    = 'Exe'
            Desktop = $Desktop
            Source  = 'Exe'
        }
    )
}

function Add-AppIDApp {
    param(
        [string]$Name,
        [string]$AppID,
        [int]$Desktop
    )

    $Name = Get-SafeName $Name
    $AppID = Clean-Text $AppID

    if ([string]::IsNullOrWhiteSpace($Name)) {
        return
    }

    if ([string]::IsNullOrWhiteSpace($AppID)) {
        return
    }

    if (Test-BadAppName $Name) {
        return
    }

    $existing = $apps |
        Where-Object {
            $_.Type -eq 'AppID' -and
            $_.Path -ieq $AppID
        } |
        Select-Object -First 1

    if ($null -ne $existing) {

        if ($Desktop -eq 1) {
            $existing.Desktop = 1
        }

        return
    }

    $apps.Add(
        [PSCustomObject]@{
            Name    = $Name
            Path    = $AppID
            Type    = 'AppID'
            Desktop = $Desktop
            Source  = 'AppsFolder'
        }
    )
}

# ------------------------------------------------------------
# Start Menu + Desktop shortcuts
# ------------------------------------------------------------

$shortcutPaths = @()

$shortcutPaths += Join-Path `
    -Path $env:APPDATA `
    -ChildPath 'Microsoft\Windows\Start Menu\Programs'

$shortcutPaths += Join-Path `
    -Path $env:ProgramData `
    -ChildPath 'Microsoft\Windows\Start Menu\Programs'

$shortcutPaths += Join-Path `
    -Path $env:USERPROFILE `
    -ChildPath 'Desktop'

$shortcutPaths += Join-Path `
    -Path $env:PUBLIC `
    -ChildPath 'Desktop'

$wsh = New-Object -ComObject WScript.Shell

foreach ($root in $shortcutPaths) {

    if (-not (Test-Path -LiteralPath $root)) {
        continue
    }

    $links = Get-ChildItem `
        -LiteralPath $root `
        -Filter '*.lnk' `
        -File `
        -Recurse

    foreach ($link in $links) {

        try {
            $shortcut = $wsh.CreateShortcut(
                $link.FullName
            )

            $target = Clean-Text $shortcut.TargetPath

            if ([string]::IsNullOrWhiteSpace($target)) {
                continue
            }

            if (-not $target.ToLowerInvariant().EndsWith('.exe')) {
                continue
            }

            $isDesktop = 0

            if (
                $link.FullName.StartsWith(
                    (Join-Path $env:USERPROFILE 'Desktop'),
                    [System.StringComparison]::OrdinalIgnoreCase
                )
            ) {
                $isDesktop = 1
            }

            if (
                $link.FullName.StartsWith(
                    (Join-Path $env:PUBLIC 'Desktop'),
                    [System.StringComparison]::OrdinalIgnoreCase
                )
            ) {
                $isDesktop = 1
            }

            $displayName = [System.IO.Path]::GetFileNameWithoutExtension(
                $link.Name
            )

            $displayName = Clean-Text $displayName

            $productName = Get-DisplayNameFromExe $target

            if (-not [string]::IsNullOrWhiteSpace($productName)) {
                $displayName = $productName
            }

            Add-ExeApp `
                -Name $displayName `
                -Path $target `
                -Desktop $isDesktop
        }
        catch {
        }
    }
}

# ------------------------------------------------------------
# Registry installed applications
# ------------------------------------------------------------

$uninstallRoots = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
)

foreach ($root in $uninstallRoots) {

    try {
        $entries = Get-ItemProperty $root

        foreach ($entry in $entries) {

            $displayName = Clean-Text $entry.DisplayName

            if ([string]::IsNullOrWhiteSpace($displayName)) {
                continue
            }

            if (Test-BadAppName $displayName) {
                continue
            }

            $installLocation = Clean-Text $entry.InstallLocation

            if ([string]::IsNullOrWhiteSpace($installLocation)) {
                continue
            }

            if (-not (Test-Path -LiteralPath $installLocation)) {
                continue
            }

            $exeFiles = Get-ChildItem `
                -LiteralPath $installLocation `
                -Filter '*.exe' `
                -File `
                -ErrorAction SilentlyContinue

            foreach ($exe in $exeFiles) {

                if (Test-BadAppName $exe.BaseName) {
                    continue
                }

                if (Test-BadPath $exe.FullName) {
                    continue
                }

                Add-ExeApp `
                    -Name $displayName `
                    -Path $exe.FullName `
                    -Desktop 0

                break
            }
        }
    }
    catch {
    }
}

# ------------------------------------------------------------
# Windows AppsFolder / StartApps
# ------------------------------------------------------------

try {

    $startApps = Get-StartApps

    foreach ($startApp in $startApps) {

        $name = Clean-Text $startApp.Name
        $appid = Clean-Text $startApp.AppID

        if ([string]::IsNullOrWhiteSpace($name)) {
            continue
        }

        if ([string]::IsNullOrWhiteSpace($appid)) {
            continue
        }

        if (Test-BadAppName $name) {
            continue
        }

        # StartApps can sometimes expose a real executable path.
        if ($appid.ToLowerInvariant().EndsWith('.exe') -and
            (Test-Path -LiteralPath $appid)) {

            Add-ExeApp `
                -Name $name `
                -Path $appid `
                -Desktop 0

            continue
        }

        # Otherwise this is an AppsFolder AppID.
        Add-AppIDApp `
            -Name $name `
            -AppID $appid `
            -Desktop 0
    }
}
catch {
}

# ------------------------------------------------------------
# Explicit AppsFolder COM enumeration
# ------------------------------------------------------------

try {

    $shell = New-Object -ComObject Shell.Application

    $appsFolder = $shell.NameSpace(
        'shell:::{4234d49b-0245-4df3-b780-3893943456e1}'
    )

    if ($null -ne $appsFolder) {

        foreach ($item in $appsFolder.Items()) {

            try {

                $name = Clean-Text $item.Name
                $path = Clean-Text $item.Path

                if ([string]::IsNullOrWhiteSpace($name)) {
                    continue
                }

                if ([string]::IsNullOrWhiteSpace($path)) {
                    continue
                }

                if (Test-BadAppName $name) {
                    continue
                }

                if ($path.ToLowerInvariant().EndsWith('.exe')) {

                    Add-ExeApp `
                        -Name $name `
                        -Path $path `
                        -Desktop 0

                }
                else {

                    Add-AppIDApp `
                        -Name $name `
                        -AppID $path `
                        -Desktop 0
                }
            }
            catch {
            }
        }
    }
}
catch {
}

# ------------------------------------------------------------
# Remove duplicates by display name
#
# Prefer EXE over AppID when the same application is found
# through both discovery methods.
# ------------------------------------------------------------

$grouped = $apps |
    Group-Object {
        $_.Name.ToLowerInvariant()
    }

$finalApps = New-Object System.Collections.Generic.List[object]

foreach ($group in $grouped) {

    $groupItems = @($group.Group)

    $exe = $groupItems |
        Where-Object { $_.Type -eq 'Exe' } |
        Select-Object -First 1

    if ($null -ne $exe) {

        $finalApps.Add($exe)

        continue
    }

    $appid = $groupItems |
        Where-Object { $_.Type -eq 'AppID' } |
        Select-Object -First 1

    if ($null -ne $appid) {
        $finalApps.Add($appid)
    }
}

# ------------------------------------------------------------
# Sort applications
# ------------------------------------------------------------

$finalApps = @(
    $finalApps |
    Sort-Object Name
)

# ------------------------------------------------------------
# Limit the result
# ------------------------------------------------------------

$maxApps = 158

if ($finalApps.Count -gt $maxApps) {

    $finalApps = @(
        $finalApps |
        Select-Object -First $maxApps
    )
}

# ------------------------------------------------------------
# Generate icons + build Apps.inc
# ------------------------------------------------------------

$lines = New-Object System.Collections.Generic.List[string]

$lines.Add(
    '[Apps]'
)

$lines.Add(
    "TotalApps=$($finalApps.Count)"
)

$lines.Add('')

$index = 1

foreach ($app in $finalApps) {

    $name = Clean-Text $app.Name
    $path = Clean-Text $app.Path
    $type = Clean-Text $app.Type

    $iconFile = "app_$index.png"
    $iconFullPath = Join-Path `
        -Path $iconDir `
        -ChildPath $iconFile

    # Remove old icon for this slot.
    if (Test-Path -LiteralPath $iconFullPath) {
        Remove-Item `
            -LiteralPath $iconFullPath `
            -Force `
            -ErrorAction SilentlyContinue
    }

    $iconGenerated = $false

    if ($type -eq 'Exe') {

        $iconGenerated = Save-ExeIcon `
            -ExePath $path `
            -OutputPath $iconFullPath
    }
    elseif ($type -eq 'AppID') {

        # Primary AppsFolder path.
        $shellPath = "shell:AppsFolder\$path"

        $iconGenerated = Save-ShellIcon `
            -ShellPath $shellPath `
            -OutputPath $iconFullPath

        # Second attempt through the actual AppsFolder namespace.
        if (-not $iconGenerated) {

            $shellPath =
                "shell:::{4234d49b-0245-4df3-b780-3893943456e1}\$path"

            $iconGenerated = Save-ShellIcon `
                -ShellPath $shellPath `
                -OutputPath $iconFullPath
        }
    }

    if ($iconGenerated) {
        $iconReference = "#@#Icons\$iconFile"
    }
    else {
        $iconReference = '#@#Icons\placeholder.png'
    }

    $escapedName = $name.Replace('=', '-')
    $escapedPath = $path.Replace('=', '-')

    $lines.Add(
        "App${index}Name=$escapedName"
    )

    $lines.Add(
        "App${index}Path=$escapedPath"
    )

    $lines.Add(
        "App${index}Type=$type"
    )

    $lines.Add(
        "App${index}Icon=$iconReference"
    )

    $lines.Add(
        "App${index}Desktop=$($app.Desktop)"
    )

    $lines.Add('')

    $index++
}

# ------------------------------------------------------------
# Write Apps.inc
# ------------------------------------------------------------

try {

    $lines |
        Set-Content `
            -LiteralPath $appsFile `
            -Encoding UTF8

}
catch {

    Write-Host ''
    Write-Host 'ERROR: Could not write Apps.inc'
    Write-Host $_.Exception.Message
    exit 1
}

# ------------------------------------------------------------
# Final output
# ------------------------------------------------------------

Write-Host ''
Write-Host '=============================================='
Write-Host ' Floating Glass App Drawer'
Write-Host '=============================================='
Write-Host ''
Write-Host "Applications discovered: $($finalApps.Count)"
Write-Host "Icons generated:         $script:IconsGenerated"
Write-Host ''
Write-Host "Apps file:"
Write-Host $appsFile
Write-Host ''
Write-Host 'Discovery complete.'
Write-Host ''