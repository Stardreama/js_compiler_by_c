@echo off
REM JavaScript 词法分析器构建脚本 (Windows)

set GCC=D:\mingw64\bin\gcc.exe
set RE2C=re2c
set BISON=bison
set TARGET=js_lexer.exe

echo ================================================
echo JavaScript Lexer - Build Script
echo ================================================
echo.

REM 检查参数
if "%1"=="clean" goto clean
if "%1"=="test" goto test
if "%1"=="help" goto help
if "%1"=="parser" goto parser
if "%1"=="test-parse" goto testparse

:build
echo [1/3] Generating lexer.c from lexer.re...
%RE2C% -o lexer.c lexer.re
if errorlevel 1 (
    echo ERROR: re2c failed!
    exit /b 1
)
echo       Generated lexer.c successfully.
echo.

echo [2/3] Compiling source files...
%GCC% -Wall -g -std=c99 -c main.c -o main.o
if errorlevel 1 (
    echo ERROR: Failed to compile main.c
    exit /b 1
)
%GCC% -Wall -g -std=c99 -c lexer.c -o lexer.o
if errorlevel 1 (
    echo ERROR: Failed to compile lexer.c
    exit /b 1
)
echo       Compiled successfully.
echo.

echo [3/3] Linking...
%GCC% -Wall -g -std=c99 -o %TARGET% main.o lexer.o
if errorlevel 1 (
    echo ERROR: Linking failed!
    exit /b 1
)
echo       Linked successfully.
echo.

echo ================================================
echo Build complete: %TARGET%
echo ================================================
echo.
echo Usage: %TARGET% ^<javascript_file^>
echo Example: %TARGET% tests\test_basic.js
echo.
goto end

:clean
echo Cleaning up...
if exist lexer.c del /Q lexer.c
if exist parser.c del /Q parser.c
if exist parser.h del /Q parser.h
if exist *.o del /Q *.o
if exist %TARGET% del /Q %TARGET%
if exist js_parser.exe del /Q js_parser.exe
echo Clean complete.
goto end

:test
call :build
if errorlevel 1 goto end

echo.
echo ================================================
echo Running Test
echo ================================================
echo.
if not exist tests\test_basic.js (
    echo ERROR: Test file tests\test_basic.js not found!
    exit /b 1
)
%TARGET% tests\test_basic.js
goto end

:help
echo Usage: build.bat [command]
echo.
echo Commands:
echo   (none)  - Build the lexer
echo   clean   - Remove generated files
echo   test    - Build and run tests
echo   parser  - Build the bison-based parser (js_parser.exe)
echo   test-parse - Build parser and run tests\test_basic.js
echo   help    - Show this help message
echo.
goto end

:parser
echo ================================================
echo JavaScript Parser - Build (Bison)
echo ================================================
echo.

echo [1/4] Generating lexer.c from lexer.re...
%RE2C% -o lexer.c lexer.re
if errorlevel 1 (
    echo ERROR: re2c failed!
    exit /b 1
)

echo [2/4] Generating parser.c / parser.h from parser.y...
%BISON% -d -o parser.c parser.y
if errorlevel 1 (
    echo ERROR: bison failed!
    exit /b 1
)

echo [3/4] Compiling sources...
%GCC% -Wall -g -std=c99 -c parser.c -o parser.o
if errorlevel 1 exit /b 1
%GCC% -Wall -g -std=c99 -c parser_main.c -o parser_main.o
if errorlevel 1 exit /b 1
%GCC% -Wall -g -std=c99 -c parser_lex_adapter.c -o parser_lex_adapter.o
if errorlevel 1 exit /b 1
%GCC% -Wall -g -std=c99 -c lexer.c -o lexer.o
if errorlevel 1 exit /b 1

echo [4/4] Linking js_parser.exe...
%GCC% -Wall -g -std=c99 -o js_parser.exe parser.o parser_main.o parser_lex_adapter.o lexer.o
if errorlevel 1 (
    echo ERROR: Linking failed!
    exit /b 1
)

echo Build complete: js_parser.exe
echo.
exit /b 0

:testparse
call :parser
if errorlevel 1 goto end
set TEST_FILES=tests\test_basic.js tests\test_simple.js tests\test_asi_basic.js tests\test_asi_return.js tests\test_asi_control.js
for %%F in (%TEST_FILES%) do (
    if not exist %%F (
        echo ERROR: Test file %%F not found!
        exit /b 1
    )
)
for %%F in (%TEST_FILES%) do (
    echo Running parser test: %%F
    js_parser.exe %%F
    if errorlevel 1 goto end
)
goto end

:end
