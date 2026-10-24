// "Open in Claude" for the Windows 11 Explorer context menu.
// Shown only when exactly one file-system folder is selected; opens it as a
// new Claude Code session in the desktop app via claude://code/new?folder=...

#include <windows.h>
#include <appmodel.h>
#include <shlobj_core.h>
#include <shobjidl_core.h>
#include <shellapi.h>
#include <shlwapi.h>
#include <wrl/implements.h>
#include <wrl/module.h>
#include <string>
#include <vector>

using namespace Microsoft::WRL;

// Finds the installed Claude desktop app so the menu can use its icon. The
// Store/MSIX install lives in a versioned folder, so look it up each time.
static std::wstring ClaudeExe()
{
    const wchar_t* family = L"Claude_pzs8sxrjxfjjc";
    UINT32 count = 0, bufferLen = 0;
    if (GetPackagesByPackageFamily(family, &count, nullptr, &bufferLen, nullptr) == ERROR_INSUFFICIENT_BUFFER && count > 0) {
        std::vector<PWSTR> names(count);
        std::vector<wchar_t> buffer(bufferLen);
        if (GetPackagesByPackageFamily(family, &count, names.data(), &bufferLen, buffer.data()) == ERROR_SUCCESS) {
            UINT32 pathLen = 0;
            GetPackagePathByFullName(names[0], &pathLen, nullptr);
            std::wstring path(pathLen, L'\0');
            if (pathLen && GetPackagePathByFullName(names[0], &pathLen, path.data()) == ERROR_SUCCESS) {
                path.resize(wcslen(path.c_str()));
                return path + L"\\app\\claude.exe";
            }
        }
    }

    // Older per-user installer.
    wchar_t exe[MAX_PATH];
    if (ExpandEnvironmentStringsW(L"%LOCALAPPDATA%\\AnthropicClaude\\claude.exe", exe, MAX_PATH) &&
        GetFileAttributesW(exe) != INVALID_FILE_ATTRIBUTES)
        return exe;
    return L"";
}

// Returns the selected folder's path, or false unless the selection is exactly
// one real folder: not a drive root, and not a zip (zips report as folders too,
// hence the SFGAO_STREAM check).
static bool SingleFolderPath(IShellItemArray* items, std::wstring& path)
{
    DWORD count = 0;
    if (!items || FAILED(items->GetCount(&count)) || count != 1)
        return false;

    ComPtr<IShellItem> item;
    if (FAILED(items->GetItemAt(0, &item)))
        return false;

    const SFGAOF want = SFGAO_FOLDER | SFGAO_FILESYSTEM | SFGAO_STREAM;
    SFGAOF attrs = 0;
    item->GetAttributes(want, &attrs);
    if ((attrs & want) != (SFGAO_FOLDER | SFGAO_FILESYSTEM))
        return false;

    PWSTR raw = nullptr;
    if (FAILED(item->GetDisplayName(SIGDN_FILESYSPATH, &raw)))
        return false;
    path = raw;
    CoTaskMemFree(raw);
    return !PathIsRootW(path.c_str());
}

// Percent-encodes everything except unreserved characters, like encodeURIComponent.
static std::wstring UrlEncode(const std::wstring& text)
{
    int len = WideCharToMultiByte(CP_UTF8, 0, text.c_str(), (int)text.size(), nullptr, 0, nullptr, nullptr);
    std::string utf8(len, '\0');
    WideCharToMultiByte(CP_UTF8, 0, text.c_str(), (int)text.size(), utf8.data(), len, nullptr, nullptr);

    static const wchar_t hex[] = L"0123456789ABCDEF";
    std::wstring out;
    for (unsigned char c : utf8) {
        bool plain = (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') ||
                     c == '-' || c == '_' || c == '.' || c == '~';
        if (plain) {
            out += (wchar_t)c;
        } else {
            out += L'%';
            out += hex[c >> 4];
            out += hex[c & 15];
        }
    }
    return out;
}

class __declspec(uuid("369924F8-98E9-4166-9264-655497203D80")) OpenInClaudeCommand final
    : public RuntimeClass<RuntimeClassFlags<ClassicCom>, IExplorerCommand>
{
public:
    IFACEMETHODIMP GetTitle(IShellItemArray*, LPWSTR* name) override
    {
        return SHStrDupW(L"Open in Claude", name);
    }

    IFACEMETHODIMP GetIcon(IShellItemArray*, LPWSTR* icon) override
    {
        *icon = nullptr;
        std::wstring exe = ClaudeExe();
        if (exe.empty())
            return E_NOTIMPL;
        return SHStrDupW((exe + L",0").c_str(), icon);
    }

    IFACEMETHODIMP GetToolTip(IShellItemArray*, LPWSTR* tip) override
    {
        *tip = nullptr;
        return E_NOTIMPL;
    }

    IFACEMETHODIMP GetCanonicalName(GUID* guid) override
    {
        *guid = __uuidof(OpenInClaudeCommand);
        return S_OK;
    }

    IFACEMETHODIMP GetState(IShellItemArray* items, BOOL, EXPCMDSTATE* state) override
    {
        std::wstring path;
        *state = SingleFolderPath(items, path) ? ECS_ENABLED : ECS_HIDDEN;
        return S_OK;
    }

    IFACEMETHODIMP Invoke(IShellItemArray* items, IBindCtx*) override
    {
        std::wstring path;
        if (!SingleFolderPath(items, path))
            return E_INVALIDARG;
        std::wstring url = L"claude://code/new?folder=" + UrlEncode(path);
        ShellExecuteW(nullptr, L"open", url.c_str(), nullptr, nullptr, SW_SHOWNORMAL);
        return S_OK;
    }

    IFACEMETHODIMP GetFlags(EXPCMDFLAGS* flags) override
    {
        *flags = ECF_DEFAULT;
        return S_OK;
    }

    IFACEMETHODIMP EnumSubCommands(IEnumExplorerCommand** commands) override
    {
        *commands = nullptr;
        return E_NOTIMPL;
    }
};

CoCreatableClass(OpenInClaudeCommand)

STDAPI DllCanUnloadNow()
{
    return Module<InProc>::GetModule().GetObjectCount() == 0 ? S_OK : S_FALSE;
}

STDAPI DllGetClassObject(REFCLSID clsid, REFIID iid, void** object)
{
    return Module<InProc>::GetModule().GetClassObject(clsid, iid, object);
}

BOOL APIENTRY DllMain(HMODULE module, DWORD reason, LPVOID)
{
    if (reason == DLL_PROCESS_ATTACH)
        DisableThreadLibraryCalls(module);
    return TRUE;
}
