# Removes the menu entries and files that install.ps1 added.

# Same sandbox check as install.ps1: inside a packaged app our deletes would
# only touch that app's private copy, so re-run outside it through WMI.
$probe = "open-in-claude-probe-$([guid]::NewGuid())"
New-Item -ItemType File -Path (Join-Path $env:LOCALAPPDATA $probe) | Out-Null
$sandboxed = [bool](Get-ChildItem "$env:LOCALAPPDATA\Packages\*\LocalCache\Local\$probe" -ErrorAction SilentlyContinue)
Remove-Item -LiteralPath (Join-Path $env:LOCALAPPDATA $probe)
if ($sandboxed) {
    $log = Join-Path $env:TEMP "open-in-claude-$([guid]::NewGuid()).log"
    $p = Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{
        CommandLine = "powershell.exe -NoProfile -ExecutionPolicy Bypass -Command `"& '$($PSCommandPath -replace "'", "''")' *> '$log'`""
    }
    while (Get-Process -Id $p.ProcessId -ErrorAction SilentlyContinue) { Start-Sleep -Milliseconds 300 }
    Get-Content -LiteralPath $log
    Remove-Item -LiteralPath $log
    return
}

foreach ($name in 'OpenInClaude', 'OpenInClaudeTerminal') {
    foreach ($parent in 'Directory\shell', 'Directory\Background\shell', 'Drive\shell') {
        [Microsoft.Win32.Registry]::CurrentUser.DeleteSubKeyTree("Software\Classes\$parent\$name", $false)
    }
}
Get-AppxPackage -Name 'OpenInClaude.ContextMenu' | Remove-AppxPackage
Remove-Item -LiteralPath (Join-Path $env:LOCALAPPDATA 'OpenInClaude') -Recurse -Force -ErrorAction SilentlyContinue
Write-Output "Removed."
if (Get-ChildItem Cert:\LocalMachine\TrustedPeople | Where-Object Subject -eq 'CN=OpenInClaudeLocal') {
    Write-Output "The package certificate is still trusted. To remove it, in an admin PowerShell run:"
    Write-Output "  Get-ChildItem Cert:\LocalMachine\TrustedPeople | Where-Object Subject -eq 'CN=OpenInClaudeLocal' | Remove-Item"
}
