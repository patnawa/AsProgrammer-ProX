#include <stdio.h>
#include <Windows.h>
#include "log_en.h"
#include <share.h>

FILE* volatile LOG_FILE = NULL;
unsigned int volatile end_fast = 0;

DWORD WINAPI end_f(void* arg)
{
    unsigned int i = 0;

    system("cmd /c start tail -F buzzpirathlp.log");

    //system("cmd /c start powershell.exe \"Get-Content -Path buzzpirathlp.log -Wait\"");

    while (1) 
    {
        Sleep(1000);
        if (GetAsyncKeyState(VK_ESCAPE)) 
        {
            Sleep(1000);
            if (GetAsyncKeyState(VK_ESCAPE))
            {
                Sleep(1000);
                if (GetAsyncKeyState(VK_ESCAPE))
                {
                    end_fast = 1;
                    for (i = 0; i < 100; i++)
                    { 
                        fprintf(LOG_FILE, "\nENDING FAST....\n");
                        fflush(LOG_FILE);
                    }
                    Sleep(8000);
                }
            }
        }

        if (GetAsyncKeyState(VK_F1))
        {
            Sleep(1000);
            if (GetAsyncKeyState(VK_F1))
            {
                Sleep(1000);
                if (GetAsyncKeyState(VK_F1))
                {
                    Sleep(1000);
                    if (GetAsyncKeyState(VK_F1))
                    {
                        system("cmd /c start tail -F buzzpirathlp.log");
                        Sleep(8000);
                    }
                }
            }
        }
    }

    return 0;
}



BOOL APIENTRY DllMain( HMODULE hModule,
                       DWORD  ul_reason_for_call,
                       LPVOID lpReserved
                     )
{
    switch (ul_reason_for_call)
    {

    case DLL_PROCESS_ATTACH:
#ifdef LOG_FILE_EN
        if (NULL == LOG_FILE)
        { 
            LOG_FILE = _fsopen("buzzpirathlp.log", "wb", _SH_DENYWR);
            if (NULL != LOG_FILE)
            {
                setvbuf(LOG_FILE, NULL, _IONBF, 0);
            }
        }
#endif
        if (NULL == LOG_FILE)
        {
            LOG_FILE = stdout;
        }

        CreateThread(NULL, 0, end_f, NULL, 0, NULL);
        break;

    case DLL_THREAD_ATTACH:
        break;

    case DLL_THREAD_DETACH:
        break;
    
    case DLL_PROCESS_DETACH:
        break;
    
    }
    
    return TRUE;
}

