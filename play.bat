@echo off
chcp 65001 >nul 2>&1
setlocal EnableExtensions EnableDelayedExpansion
title LEGIONFORGE 7.3.5.26124 (2026-10-18) - Запуск

rem ============================================================
rem  LEGIONFORGE 7.3.5.26124 - Запуск (сборка 2026-10-18)
rem  Порядок: MySQL -> bnetserver (1119) -> worldserver
rem  (8085/8086) -> WoW-64.exe. Exe клиента не изменяется.
rem ============================================================

set "ROOT=%~dp0"
set "ROOT=%ROOT:~0,-1%"
set "SERVER_DIR=%ROOT%\server"
set "TOOLS_DIR=%ROOT%\tools"

echo.
echo  =========================================================
echo   LEGIONFORGE 7.3.5.26124 (2026-10-18) - Запуск
echo  =========================================================
echo.

rem ---- MySQL ----
netstat -ano -p tcp | findstr /r /c:":3306 .*LISTENING" >nul 2>&1
if not errorlevel 1 goto :MYSQL_OK
echo  [*] Поднимаю MySQL из портативной установки...
if exist "%TOOLS_DIR%\mysql\server\bin\mysqld.exe" powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\scripts\bootstrap_tools.ps1" -Root "%ROOT%" -MySQL -StartMySQL >nul 2>&1
netstat -ano -p tcp | findstr /r /c:":3306 .*LISTENING" >nul 2>&1
if not errorlevel 1 goto :MYSQL_OK
echo  [ОШИБКА] MySQL не слушает порт 3306. Запустите сначала setup.bat.
goto :FAIL
:MYSQL_OK
echo  [OK] MySQL работает.

rem ---- bnetserver ----
netstat -ano -p tcp | findstr /r /c:":1119 .*LISTENING" >nul 2>&1
if not errorlevel 1 goto :BNET_OK
echo  [*] Запускаю bnetserver...
start "LEGIONFORGE bnetserver" /min /D "%SERVER_DIR%" bnetserver.exe
for /l %%I in (1,1,30) do (
    timeout /t 2 /nobreak >nul
    netstat -ano -p tcp | findstr /r /c:":1119 .*LISTENING" >nul 2>&1
    if not errorlevel 1 goto :BNET_OK
)
echo  [ОШИБКА] bnetserver не поднял порт 1119 за 60 секунд. Смотрите окно bnetserver.
goto :FAIL
:BNET_OK
echo  [OK] bnetserver слушает порт 1119.

rem ---- worldserver ----
netstat -ano -p tcp | findstr /r /c:":8085 .*LISTENING" >nul 2>&1
if not errorlevel 1 goto :WORLD_OK
echo  [*] Запускаю worldserver (первый запуск дольше - загрузка данных)...
start "LEGIONFORGE worldserver" /min /D "%SERVER_DIR%" worldserver.exe
for /l %%I in (1,1,90) do (
    timeout /t 3 /nobreak >nul
    netstat -ano -p tcp | findstr /r /c:":8086 .*LISTENING" >nul 2>&1
    if not errorlevel 1 goto :WORLD_OK
)
echo  [ОШИБКА] worldserver не поднял порт 8086 за 4,5 минуты.
echo      Смотрите лог worldserver в server\logs - там причина.
goto :FAIL
:WORLD_OK
echo  [OK] worldserver готов: порты 8085 и 8086 слушаются.

rem ---- клиент ----
set "CLIENT_EXE="
if exist "%ROOT%\client_path.txt" set /p CLIENT_EXE=<"%ROOT%\client_path.txt"
if defined CLIENT_EXE if exist "!CLIENT_EXE!" goto :CLIENT_FOUND
set "CLIENT_EXE="
for %%D in ("D:\Games" "C:\Games" "D:\Wow" "C:\Wow" "D:\Legion" "D:\") do (
    if exist "%%~D\WoW-64.exe" set "CLIENT_EXE=%%~D\WoW-64.exe"
    if exist "%%~D\Wow-64.exe" set "CLIENT_EXE=%%~D\Wow-64.exe"
)
if defined CLIENT_EXE goto :CLIENT_FOUND
echo.
echo  Клиент не найден автоматически. Введите полный путь к WoW-64.exe
echo  (например: D:\WoW\WoW-64.exe) - путь сохранится на следующий раз.
set /p "CLIENT_EXE=  Путь: "
if not defined CLIENT_EXE goto :NO_CLIENT
:CLIENT_FOUND
if not exist "!CLIENT_EXE!" goto :NO_CLIENT
> "%ROOT%\client_path.txt" echo !CLIENT_EXE!
for %%I in ("!CLIENT_EXE!") do set "CLIENT_DIR=%%~dpI"
set "CLIENT_DIR=!CLIENT_DIR:~0,-1!"
echo  [OK] Клиент: !CLIENT_EXE!

rem ---- portal: проверка адреса в WTF, exe не трогаем ----
if exist "!CLIENT_DIR!\WTF\UWow.wtf" (
    findstr /c:"SET portal \"127.0.0.1\"" "!CLIENT_DIR!\WTF\UWow.wtf" >nul 2>&1
    if errorlevel 1 echo  [!] В WTF\UWow.wtf portal не равен 127.0.0.1 - проверьте файл клиента.
)
echo  [*] Запускаю клиент: !CLIENT_EXE!
start "" /D "!CLIENT_DIR!" "!CLIENT_EXE!"
echo.
echo  =========================================================
echo   Сервер запущен. Хорошей игры!
echo   Если вход в мир не проходит - нужны последние 100 строк
echo   лога server\logs\Server.log (или Logs\Server.log у вас
echo   в сервере) и окно worldserver.
echo  =========================================================
echo.
pause
exit /b 0

:NO_CLIENT
echo  [ОШИБКА] Клиент не указан. Задайте путь к WoW-64.exe при повторном запуске.
:FAIL
echo.
pause
exit /b 1
