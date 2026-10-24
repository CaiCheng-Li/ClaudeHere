# Opens a folder in Claude. Called from the Explorer right-click menu.
#   -Mode App       new Claude Code session in the desktop app (default)
#   -Mode Terminal  Claude Code CLI in Windows Terminal
param(
    [Parameter(Mandatory)][string]$Folder,
    [ValidateSet('App', 'Terminal')][string]$Mode = 'App'
)

# Explorer passes a drive root as "C:\"; the trailing backslash escapes the
# closing quote, so it arrives as C:" and needs putting back together.
$Folder = $Folder.Trim().TrimEnd('"')
if ($Folder -match '^[A-Za-z]:$') { $Folder += '\' }
if (-not (Test-Path -LiteralPath $Folder -PathType Container)) { exit 1 }

if ($Mode -eq 'App') {
    # Same link the desktop app's own `ccd` command builds. The path must be
    # encoded or names containing & # % get cut short.
    Start-Process ('claude://code/new?folder=' + [uri]::EscapeDataString($Folder))
}
elseif (Get-Command wt.exe -ErrorAction SilentlyContinue) {
    Start-Process wt.exe -ArgumentList '-d', '.', 'cmd', '/k', 'claude' -WorkingDirectory $Folder
}
else {
    Start-Process cmd.exe -ArgumentList '/k', 'claude' -WorkingDirectory $Folder
}
