@echo off
setlocal enabledelayedexpansion
REM JavaScript 词法分析器构建脚本 (Windows)


@REM set "GCC=C:\Program Files (x86)\mingw64\bin\gcc.exe"
@REM set "RE2C=E:\Application\MSYS2\usr\bin\re2c.exe"
@REM set "BISON=E:\Application\MSYS2\usr\bin\bison.exe"
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
"%RE2C%" -o lexer.c lexer.re
if errorlevel 1 (
    echo ERROR: re2c failed!
    exit /b 1
)
echo       Generated lexer.c successfully.
echo.

echo [2/3] Compiling source files...
"%GCC%" -Wall -g -std=c99 -c main.c -o main.o
if errorlevel 1 (
    echo ERROR: Failed to compile main.c
    exit /b 1
)
"%GCC%" -Wall -g -std=c99 -c lexer.c -o lexer.o
if errorlevel 1 (
    echo ERROR: Failed to compile lexer.c
    exit /b 1
)
echo       Compiled successfully.
echo.

echo [3/3] Linking...
"%GCC%" -Wall -g -std=c99 -o %TARGET% main.o lexer.o
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
if not exist test\test_basic.js (
    echo ERROR: Test file test\test_basic.js not found!
    exit /b 1
)
%TARGET% test\test_basic.js
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
"%RE2C%" -o lexer.c lexer.re
if errorlevel 1 (
    echo ERROR: re2c failed!
    exit /b 1
)

echo [2/4] Generating parser.c / parser.h from parser.y...
"%BISON%" -d -o parser.c parser.y
if errorlevel 1 (
    echo ERROR: bison failed!
    exit /b 1
)

echo [3/4] Compiling sources...
"%GCC%" -Wall -g -std=c99 -c parser.c -o parser.o
if errorlevel 1 exit /b 1
"%GCC%" -Wall -g -std=c99 -c parser_main.c -o parser_main.o
if errorlevel 1 exit /b 1
"%GCC%" -Wall -g -std=c99 -c parser_lex_adapter.c -o parser_lex_adapter.o
if errorlevel 1 exit /b 1
"%GCC%" -Wall -g -std=c99 -c lexer.c -o lexer.o
if errorlevel 1 exit /b 1
"%GCC%" -Wall -g -std=c99 -c ast.c -o ast.o
if errorlevel 1 exit /b 1

echo [4/4] Linking js_parser.exe...
"%GCC%" -Wall -g -std=c99 -o js_parser.exe parser.o parser_main.o parser_lex_adapter.o lexer.o ast.o
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

echo.
echo ================================================
echo Running All Tests in test\ folder
echo ================================================
echo.

set TOTAL=0
set PASSED=0
set FAILED=0

REM 遍历 test 文件夹中的所有 .js 文件
for %%F in (test\*.js) do (
    set /a TOTAL+=1
    
    REM 检查是否是错误测试用例（文件名包含 test_error 或 temp）
    set EXPECT_FAIL=0
    echo %%F | findstr /i "test_error temp" >nul
    if not errorlevel 1 set EXPECT_FAIL=1
    
    echo Running parser test: %%F
    
    REM 执行测试并捕获退出码
    js_parser.exe %%F
    set RESULT=!errorlevel!
    
    REM 判断测试结果
    if !EXPECT_FAIL! equ 1 (
        REM 期望失败的测试
        if !RESULT! equ 0 (
            echo   [debug] result=!RESULT!, expect_fail=!EXPECT_FAIL!
            echo   Expected failure but parser succeeded.
            set /a FAILED+=1
        ) else (
            echo   [debug] result=!RESULT!, expect_fail=!EXPECT_FAIL!
            set /a PASSED+=1
        )
    ) else (
        REM 期望成功的测试
        if !RESULT! equ 0 (
            echo   [debug] result=!RESULT!, expect_fail=!EXPECT_FAIL!
            set /a PASSED+=1
        ) else (
            echo   [debug] result=!RESULT!, expect_fail=!EXPECT_FAIL!
            echo   Expected success but parser failed.
            set /a FAILED+=1
        )
    )
)

echo.
echo ================================================
echo Test Results Summary
echo ================================================
echo Total files:     %TOTAL%
echo Passed:          %PASSED%
echo Failed:          %FAILED%
echo ================================================
echo.

if %FAILED% gtr 0 (
    echo TEST SUITE FAILED - %FAILED% test^(s^) failed
    exit /b 1
) else (
    echo TEST SUITE PASSED - All %PASSED% test^(s^) passed
)

goto end

:end
