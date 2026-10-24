# Adds "Open in Claude" to the Explorer right-click menu. Per-user, no admin
# needed, except trusting the package certificate once (the script says how).
#   .\install.ps1                   desktop app entry only
#   .\install.ps1 -IncludeTerminal  also add a Claude Code CLI (terminal) entry
param([switch]$IncludeTerminal)

$ErrorActionPreference = 'Stop'

# Started from inside a packaged app (the Claude desktop app included), Windows
# redirects registry and %LOCALAPPDATA% writes into that app's private copy,
# where Explorer never sees them. Spot that and re-run outside it through WMI.
$probe = "open-in-claude-probe-$([guid]::NewGuid())"
New-Item -ItemType File -Path (Join-Path $env:LOCALAPPDATA $probe) | Out-Null
$sandboxed = [bool](Get-ChildItem "$env:LOCALAPPDATA\Packages\*\LocalCache\Local\$probe" -ErrorAction SilentlyContinue)
Remove-Item -LiteralPath (Join-Path $env:LOCALAPPDATA $probe)
if ($sandboxed) {
    $log = Join-Path $env:TEMP "open-in-claude-$([guid]::NewGuid()).log"
    $self = "& '$($PSCommandPath -replace "'", "''")'" + $(if ($IncludeTerminal) { ' -IncludeTerminal' })
    $p = Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{
        CommandLine = "powershell.exe -NoProfile -ExecutionPolicy Bypass -Command `"$self *> '$log'`""
    }
    while (Get-Process -Id $p.ProcessId -ErrorAction SilentlyContinue) { Start-Sleep -Milliseconds 300 }
    Get-Content -LiteralPath $log
    Remove-Item -LiteralPath $log
    return
}

$dest = Join-Path $env:LOCALAPPDATA 'OpenInClaude'
New-Item -ItemType Directory -Force -Path $dest | Out-Null
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'open-in-claude.ps1') -Destination $dest -Force
$launcher = Join-Path $dest 'open-in-claude.ps1'

# Use the Claude app's icon. The Store-style install sits in a versioned folder
# that changes with every update, so keep our own copy instead of pointing at it.
$icon = Join-Path $dest 'claude.ico'
$pkg = Get-AppxPackage -Name 'Claude' | Where-Object PackageFamilyName -eq 'Claude_pzs8sxrjxfjjc' | Select-Object -First 1
$exe = if ($pkg) { Join-Path $pkg.InstallLocation 'app\claude.exe' } else { Join-Path $env:LOCALAPPDATA 'AnthropicClaude\claude.exe' }
if (-not (Test-Path -LiteralPath $exe)) {
    Write-Warning 'Claude desktop app not found. The menu entry needs it to open folders.'
}
else {
    Add-Type -AssemblyName System.Drawing
    $bmp = [System.Drawing.Icon]::ExtractAssociatedIcon($exe).ToBitmap()
    $size = $bmp.Width
    $maskBytes = [math]::Ceiling($size / 32) * 4 * $size
    # Icon.Save() drops to 16 colours, so write a 32-bit .ico by hand.
    $w = New-Object IO.BinaryWriter([IO.File]::Create($icon))
    try {
        $w.Write([uint16]0); $w.Write([uint16]1); $w.Write([uint16]1)                 # ICONDIR
        $w.Write([byte]$size); $w.Write([byte]$size); $w.Write([uint16]0)             # ICONDIRENTRY
        $w.Write([uint16]1); $w.Write([uint16]32)
        $w.Write([uint32](40 + $size * $size * 4 + $maskBytes)); $w.Write([uint32]22)
        $w.Write([uint32]40); $w.Write([int32]$size); $w.Write([int32]($size * 2))    # BITMAPINFOHEADER
        $w.Write([uint16]1); $w.Write([uint16]32); $w.Write([byte[]]::new(24))
        for ($y = $size - 1; $y -ge 0; $y--) {                                        # BGRA, bottom-up
            for ($x = 0; $x -lt $size; $x++) {
                $c = $bmp.GetPixel($x, $y)
                $w.Write([byte]$c.B); $w.Write([byte]$c.G); $w.Write([byte]$c.R); $w.Write([byte]$c.A)
            }
        }
        $w.Write([byte[]]::new($maskBytes))                                           # AND mask (unused)
    }
    finally { $w.Close() }
}

function Set-MenuEntry([string]$Name, [string]$Label, [string]$Mode) {
    # conhost --headless keeps a console window from flashing up.
    $command = "conhost.exe --headless powershell.exe -NoProfile -ExecutionPolicy Bypass " +
               "-File `"$launcher`" -Mode $Mode `"%V`""
    foreach ($parent in 'Directory\shell', 'Directory\Background\shell', 'Drive\shell') {
        $key = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey("Software\Classes\$parent\$Name")
        $key.SetValue('', $Label)
        if (Test-Path -LiteralPath $icon) { $key.SetValue('Icon', $icon) }
        $cmdKey = $key.CreateSubKey('command')
        $cmdKey.SetValue('', $command)
        $cmdKey.Close()
        $key.Close()
    }
}

Set-MenuEntry 'OpenInClaude' 'Open in Claude' 'App'
if ($IncludeTerminal) {
    Set-MenuEntry 'OpenInClaudeTerminal' 'Open in Claude Code (terminal)' 'Terminal'
}

Write-Output "Classic menu entry installed (under Show more options)."

# Windows 11 short menu: a signed package, from your own build of
# context-menu\build.ps1 if there is one, otherwise the prebuilt one in package\.
# Windows only installs it once its certificate is trusted, which takes an admin.
$pkgDir = Join-Path $PSScriptRoot 'context-menu\build'
if (-not (Test-Path -LiteralPath (Join-Path $pkgDir 'OpenInClaude.msix'))) { $pkgDir = Join-Path $PSScriptRoot 'package' }
$msix = Join-Path $pkgDir 'OpenInClaude.msix'
$cer = Join-Path $pkgDir 'OpenInClaude.cer'
if (Test-Path -LiteralPath $msix) {
    Copy-Item -LiteralPath $cer -Destination $dest -Force
    $thumb = (New-Object Security.Cryptography.X509Certificates.X509Certificate2($cer)).Thumbprint
    if (Test-Path "Cert:\LocalMachine\TrustedPeople\$thumb") {
        Add-AppxPackage -Path $msix -ForceUpdateFromAnyVersion
        # The package's entry shows under Show more options too, so drop the
        # classic one for folders to avoid listing it twice.
        [Microsoft.Win32.Registry]::CurrentUser.DeleteSubKeyTree('Software\Classes\Directory\shell\OpenInClaude', $false)
        Write-Output "Windows 11 menu entry installed (folders only)."
    }
    else {
        Write-Output "Windows 11 menu entry needs its certificate trusted first. In an admin PowerShell run:"
        Write-Output "  Import-Certificate -FilePath `"$dest\OpenInClaude.cer`" -CertStoreLocation Cert:\LocalMachine\TrustedPeople"
        Write-Output "then run install.ps1 again."
    }
}
