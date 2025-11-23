@echo off
setlocal

rem Get the absolute path of the script directory
set "ROOT_DIR=%~dp0"

rem Convert backslashes to forward slashes
set "ROOT_DIR_FWD=%ROOT_DIR:\=/%"

rem Extract drive letter and convert to cygdrive format
set "DRIVE_LETTER=%ROOT_DIR_FWD:~0,1%"
set "PATH_REST=%ROOT_DIR_FWD:~2%"
set "MSYS_ROOT=/cygdrive/%DRIVE_LETTER%%PATH_REST%"

rem Define paths using MSYS format
set "MINGW_BIN_CYG=%MSYS_ROOT%bin/mingw64/bin"
set "MSYS_USER_BIN_CYG=%MSYS_ROOT%bin/bin_usr"

rem Define paths using Windows format
set "MINGW_BIN_WIN=%~dp0bin\mingw64\bin"
set "MSYS_USER_BIN_WIN=%~dp0bin\bin_usr"

rem Prepend BOTH formats to PATH.
set "PATH=%MINGW_BIN_CYG%;%MSYS_USER_BIN_CYG%;%MINGW_BIN_WIN%;%MSYS_USER_BIN_WIN%;%PATH%"

rem echo Debug: PATH is %PATH%
rem "%MSYS_USER_BIN_WIN%\sh.exe" -c "echo Sh PATH is $PATH"

"%MSYS_USER_BIN_WIN%\make.exe" SHELL="%MSYS_USER_BIN_CYG%/sh.exe" %*
endlocal
