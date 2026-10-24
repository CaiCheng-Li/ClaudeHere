// Exercises the menu handler without Explorer: which selections show the
// entry, and the link it would open.
// Build from an "x64 Native Tools Command Prompt":
//   cl /std:c++17 /EHsc /DUNICODE /D_UNICODE test.cpp shell32.lib ole32.lib shlwapi.lib runtimeobject.lib
// Usage:
//   test.exe <folder> <folder2> <file> <zip> <drive> <text-to-encode>
#include "../src/OpenInClaude.cpp"
#include <cstdio>
#include <vector>

static ComPtr<IShellItemArray> Selection(std::initializer_list<const wchar_t*> paths)
{
    std::vector<PIDLIST_ABSOLUTE> ids;
    for (auto p : paths) {
        PIDLIST_ABSOLUTE id = nullptr;
        if (FAILED(SHParseDisplayName(p, nullptr, &id, 0, nullptr)))
            wprintf(L"  could not parse %s\n", p);
        ids.push_back(id);
    }
    ComPtr<IShellItemArray> items;
    SHCreateShellItemArrayFromIDLists((UINT)ids.size(), (PCIDLIST_ABSOLUTE_ARRAY)ids.data(), &items);
    for (auto id : ids) CoTaskMemFree(id);
    return items;
}

static void Show(OpenInClaudeCommand* cmd, const wchar_t* label, IShellItemArray* items)
{
    EXPCMDSTATE state = ECS_DISABLED;
    cmd->GetState(items, TRUE, &state);
    wprintf(L"%-14s %s\n", label, state == ECS_ENABLED ? L"shown" : state == ECS_HIDDEN ? L"hidden" : L"other");
}

int wmain(int argc, wchar_t** argv)
{
    if (argc < 7) return 2;
    CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
    {
        auto cmd = Make<OpenInClaudeCommand>();
        PWSTR text = nullptr;
        cmd->GetTitle(nullptr, &text); wprintf(L"title          %s\n", text); CoTaskMemFree(text);
        cmd->GetIcon(nullptr, &text);  wprintf(L"icon           %s\n", text); CoTaskMemFree(text);

        Show(cmd.Get(), L"one folder", Selection({argv[1]}).Get());
        Show(cmd.Get(), L"two folders", Selection({argv[1], argv[2]}).Get());
        Show(cmd.Get(), L"file", Selection({argv[3]}).Get());
        Show(cmd.Get(), L"zip", Selection({argv[4]}).Get());
        Show(cmd.Get(), L"drive", Selection({argv[5]}).Get());
        Show(cmd.Get(), L"nothing", nullptr);

        std::wstring path;
        SingleFolderPath(Selection({argv[1]}).Get(), path);
        wprintf(L"folder path    %s\n", path.c_str());
        wprintf(L"encoded        %s\n", UrlEncode(argv[6]).c_str());
    }
    CoUninitialize();
    return 0;
}
