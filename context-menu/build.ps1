# Builds build\OpenInClaude.msix (the Windows 11 menu entry) and the public
# certificate it's signed with. Needs Visual Studio Build Tools (C++ workload)
# and the Windows SDK.
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$out = Join-Path $root 'build'
$layout = Join-Path $out 'layout'

if (Test-Path $out) { Remove-Item $out -Recurse -Force }
New-Item -ItemType Directory -Path "$layout\Assets" -Force | Out-Null

$vs = & "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe" -latest -products * `
    -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if (-not $vs) { throw 'Visual Studio Build Tools with the C++ workload not found' }
& "$root\compile.cmd" (Join-Path $vs 'VC\Auxiliary\Build\vcvars64.bat') $out
if ($LASTEXITCODE) { throw 'Compile failed' }
Remove-Item "$layout\*.lib", "$layout\*.exp"

# The package needs logos, though with no Start menu entry they only show in
# Settings > Apps. A plain grey folder; the menu itself uses the Claude app's icon.
Add-Type -AssemblyName System.Drawing
foreach ($logo in @{ Name = 'StoreLogo.png'; Size = 50 }, @{ Name = 'Square150x150Logo.png'; Size = 150 }, @{ Name = 'Square44x44Logo.png'; Size = 44 }) {
    $u = $logo.Size / 16.0
    $bmp = New-Object System.Drawing.Bitmap($logo.Size, $logo.Size)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 138, 143, 152))
    $g.FillRectangle($brush, [float](1 * $u), [float](3 * $u), [float](6 * $u), [float](2 * $u))
    $g.FillRectangle($brush, [float](1 * $u), [float](4.5 * $u), [float](14 * $u), [float](9 * $u))
    $g.Dispose()
    $bmp.Save("$layout\Assets\$($logo.Name)", [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
}

Copy-Item "$root\src\AppxManifest.xml" $layout

$sdk = Get-ChildItem "${env:ProgramFiles(x86)}\Windows Kits\10\bin\10.*" -Directory |
    Where-Object { Test-Path "$($_.FullName)\x64\makeappx.exe" } |
    Sort-Object { [version]$_.Name } -Descending | Select-Object -First 1
if (-not $sdk) { throw 'Windows SDK (makeappx.exe) not found' }
$msix = Join-Path $out 'OpenInClaude.msix'
& "$($sdk.FullName)\x64\makeappx.exe" pack /d $layout /p $msix /o | Out-Null
if ($LASTEXITCODE) { throw 'makeappx failed' }

# One-off certificate: sign, keep the public half, then delete the private key
# so it can't sign anything else. Rebuilding makes a new one.
$cert = New-SelfSignedCertificate -Type Custom -Subject 'CN=OpenInClaudeLocal' -KeyUsage DigitalSignature `
    -FriendlyName 'Open in Claude (local build)' -CertStoreLocation Cert:\CurrentUser\My `
    -TextExtension @('2.5.29.37={text}1.3.6.1.5.5.7.3.3', '2.5.29.19={text}') -NotAfter (Get-Date).AddYears(10)
try {
    & "$($sdk.FullName)\x64\signtool.exe" sign /q /fd SHA256 /sha1 $cert.Thumbprint /s My $msix
    if ($LASTEXITCODE) { throw 'signtool failed' }
    Export-Certificate -Cert $cert -FilePath (Join-Path $out 'OpenInClaude.cer') | Out-Null
}
finally {
    Remove-Item "Cert:\CurrentUser\My\$($cert.Thumbprint)" -DeleteKey
}

Write-Output "Built $msix"
