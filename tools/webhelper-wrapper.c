/*
 * webhelper-wrapper.c - part of Sili (GPLv3)
 *
 * Steam's UI is a Chromium (CEF) browser, steamwebhelper.exe. Chromium draws
 * from a separate GPU process into a window owned by the browser process.
 * Wine's macOS driver cannot show cross-process drawing, so the Steam window
 * stays black. This wrapper sits in place of steamwebhelper.exe and starts the
 * real helper (steamwebhelper_real.exe) with flags that keep all drawing in
 * one process.
 */
#include <windows.h>
#include <wchar.h>

static const wchar_t *EXTRA = L" --disable-gpu --disable-gpu-compositing --in-process-gpu --single-process";

/* Skip argv[0] (quoted or not) in the raw command line. */
static const wchar_t *skip_program(const wchar_t *cmd) {
    if (*cmd == L'"') {
        cmd++;
        while (*cmd && *cmd != L'"') cmd++;
        if (*cmd == L'"') cmd++;
    } else {
        while (*cmd && *cmd != L' ' && *cmd != L'\t') cmd++;
    }
    return cmd;
}

int WINAPI wWinMain(HINSTANCE inst, HINSTANCE prev, LPWSTR unused, int show) {
    (void)inst; (void)prev; (void)unused; (void)show;
    wchar_t real[MAX_PATH];
    DWORD len = GetModuleFileNameW(NULL, real, MAX_PATH);
    if (len == 0 || len >= MAX_PATH - 16) return 1;
    wchar_t *dot = wcsrchr(real, L'.');
    if (!dot) return 1;
    wcscpy(dot, L"_real.exe");

    const wchar_t *args = skip_program(GetCommandLineW());
    size_t size = wcslen(real) + wcslen(args) + wcslen(EXTRA) + 8;
    wchar_t *cmd = HeapAlloc(GetProcessHeap(), 0, size * sizeof(wchar_t));
    if (!cmd) return 1;
    /* Only the browser (no --type=) gets the single-process flags; child processes pass through. */
    const wchar_t *extra = wcsstr(args, L"--type=") ? L"" : EXTRA;
    wsprintfW(cmd, L"\"%s\"%s%s", real, args, extra);

    STARTUPINFOW si = { sizeof(si) };
    PROCESS_INFORMATION pi;
    if (!CreateProcessW(real, cmd, NULL, NULL, TRUE, 0, NULL, NULL, &si, &pi)) return 1;
    WaitForSingleObject(pi.hProcess, INFINITE);
    DWORD code = 0;
    GetExitCodeProcess(pi.hProcess, &code);
    CloseHandle(pi.hThread);
    CloseHandle(pi.hProcess);
    return (int)code;
}
