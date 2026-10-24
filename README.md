# ClaudeHere

Right-click a folder in Windows Explorer, pick "Open in Claude", and the Claude desktop app starts a new Claude Code session with that folder already selected.

This is an unofficial tool, not made by or affiliated with Anthropic.

## What it adds

- Windows 11 menu: "Open in Claude" when you right-click exactly one folder. It stays hidden for files, zip files, drives, multiple selections and empty space.
- Classic menu (Show more options, or Shift+right-click): "Open in Claude" on the empty space inside a folder and on drives.
- Optional: "Open in Claude Code (terminal)" in the classic menu, which starts the `claude` CLI in Windows Terminal in that folder.

## Requirements

- Windows 11. Tested on build 26300.
- The Claude desktop app with Claude Code. Tested with version 3.6556.2.
- For the terminal entry only: the Claude Code CLI on your PATH, and Windows Terminal.

## Install

1. Get the files with `git clone https://github.com/CaiCheng-Li/ClaudeHere`, or use Code > Download ZIP on GitHub and extract it.

2. Open PowerShell in that folder and run:

   ```powershell
   powershell -ExecutionPolicy Bypass -File .\install.ps1
   ```

   Windows doesn't run downloaded PowerShell scripts by default. `-ExecutionPolicy Bypass` applies to this one run and leaves your system setting alone. The classic menu entries work as soon as this finishes.

3. The Windows 11 menu only shows entries that come from an installed app package, and Windows only installs a package if it trusts the certificate the package was signed with. The first run of `install.ps1` prints the command for that. Open PowerShell as administrator and run it once:

   ```powershell
   Import-Certificate -FilePath "$env:LOCALAPPDATA\OpenInClaude\OpenInClaude.cer" -CertStoreLocation Cert:\LocalMachine\TrustedPeople
   ```

4. Run `install.ps1` again from a normal PowerShell window (not admin). This time it installs the package.

If the entry doesn't show up in the Windows 11 menu, sign out and back in, or restart "Windows Explorer" from Task Manager.

For the terminal entry, add `-IncludeTerminal` when you run the installer.

### About the certificate

`package\OpenInClaude.msix` is signed with a self-signed certificate that `context-menu\build.ps1` creates. The script deletes the certificate's private key right after signing, so nothing else can be signed with it. You can read the script to see that, but you can't verify it for a package someone else built. If you'd rather not trust it, build the package yourself as described below. Your build gets its own certificate, and `install.ps1` uses your build over the prebuilt one.

## Build the package yourself

You need Visual Studio Build Tools with the "Desktop development with C++" workload, and the Windows SDK.

```powershell
powershell -ExecutionPolicy Bypass -File .\context-menu\build.ps1
```

That writes `context-menu\build\OpenInClaude.msix` and `OpenInClaude.cer`. Then run `install.ps1`; it prints the trust command for your new certificate, and installs the package once you've run it.

## Uninstall

```powershell
powershell -ExecutionPolicy Bypass -File .\uninstall.ps1
```

This removes the package, the menu entries and `%LOCALAPPDATA%\OpenInClaude`. If the certificate is still trusted, it prints the admin command that removes it.

## How it works

The Claude desktop app opens Claude Code in a given folder through the link `claude://code/new?folder=<path>`. Both menu entries build that link.

- `install.ps1` copies `open-in-claude.ps1` and the Claude app's icon to `%LOCALAPPDATA%\OpenInClaude`, then adds the classic menu entries under `HKCU\Software\Classes`. Those entries start the script through `conhost --headless`, so no console window appears.
- `open-in-claude.ps1` percent-encodes the folder path before opening the link. Without that, a folder name containing `&`, `#` or `%` gets cut short.
- `context-menu\` is the Windows 11 entry: a small C++ `IExplorerCommand` handler in an MSIX package. It shows only when the selection is one file-system folder that isn't a zip file or a drive root, and it takes its icon from the installed Claude app.
- Started from inside a packaged app, such as a terminal opened by the Claude desktop app, a script's registry and `%LOCALAPPDATA%` writes get redirected into that app's private storage, where Explorer never looks. `install.ps1` and `uninstall.ps1` check for this and re-run themselves outside it through WMI.
- `context-menu\test\test.cpp` checks the handler's selection rules and URL encoding without going through Explorer.

## License

MIT. See [LICENSE](LICENSE).
