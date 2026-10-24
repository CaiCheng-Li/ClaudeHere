// A package has to name an app executable. This one does nothing and is
// hidden from the Start menu; the package exists for the menu handler.
#include <windows.h>

int WINAPI wWinMain(HINSTANCE, HINSTANCE, PWSTR, int)
{
    return 0;
}
