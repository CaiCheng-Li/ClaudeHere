@echo off
rem Usage: compile.cmd <vcvars64.bat> <build dir>   (called by build.ps1)
call "%~1" >nul || exit /b 1
set FLAGS=/nologo /std:c++17 /O2 /MT /EHsc /W4 /DUNICODE /D_UNICODE
cd /d "%~2" || exit /b 1
cl %FLAGS% /LD "%~dp0src\OpenInClaude.cpp" /link /DEF:"%~dp0src\OpenInClaude.def" /OUT:layout\OpenInClaude.dll shell32.lib ole32.lib shlwapi.lib runtimeobject.lib || exit /b 1
cl %FLAGS% "%~dp0src\Stub.cpp" /link /SUBSYSTEM:WINDOWS /OUT:layout\OpenInClaudeStub.exe || exit /b 1
