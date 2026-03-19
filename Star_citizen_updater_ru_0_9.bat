@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul 2>&1

:: =========================================================
:: Star Citizen - Русская локализация
:: Обновление по тегам GitHub:
::   LIVE -> tag вида X.Y.Z-vNN
::   PTU  -> tag вида X.Y.Z-vNN-ptu
:: Содержимое архива проверяется только после скачивания.
:: Если архив не подходит, можно попробовать следующий тег.
:: =========================================================

:: -----------------------------
:: Настройки
:: -----------------------------
set "SCRIPT_DIR=%~dp0"
set "GITHUB_AUTOR=n1ghter"
set "GITHUB_REPO=StarCitizenRu"
set "TEMP_DIR=%TEMP%\sc_ru_updater"
set "CONFIG_FILE=%SCRIPT_DIR%sc_ru_config.cfg"

:: -----------------------------
:: Конфигурация
:: -----------------------------
set "LAUNCHER_PATH="
set "LIVE_REPO="
set "LIVE_VERSION="
set "LIVE_PATH="
set "PTU_REPO="
set "PTU_VERSION="
set "PTU_PATH="

:: -----------------------------
:: Локальный статус
:: -----------------------------
set "LIVE_FOUND=false"
set "PTU_FOUND=false"

set "LIVE_BUILD_TYPE=не найден"
set "PTU_BUILD_TYPE=не найден"

set "LIVE_VERSION_DIGITS=не найдена"
set "PTU_VERSION_DIGITS=не найдена"

set "LIVE_TYPE_MISMATCH=false"
set "PTU_TYPE_MISMATCH=false"

set "LIVE_STATUS=нет данных"
set "PTU_STATUS=нет данных"

set "INSTALL_LIVE_NEEDED=false"
set "INSTALL_PTU_NEEDED=false"
set "CURRENT_INSTALL="

:: -----------------------------
:: GitHub статус и кандидаты
:: -----------------------------
set "GITHUB_OK=false"

set "LIVE_CAND_COUNT=0"
set "PTU_CAND_COUNT=0"

set "LIVE_CURRENT_INDEX=1"
set "PTU_CURRENT_INDEX=1"

set "LATEST_LIVE_VERSION=не найдена"
set "LATEST_LIVE_TAG="
set "LATEST_PTU_VERSION=не найдена"
set "LATEST_PTU_TAG="

set "LAST_REJECTED_LIVE_TAG="
set "LAST_REJECTED_PTU_TAG="

if not exist "%TEMP_DIR%" mkdir "%TEMP_DIR%" >nul 2>&1

:: -----------------------------
:: Автообнаружение рядом со скриптом
:: -----------------------------
if exist "%SCRIPT_DIR%RSI Launcher.exe" (
    set "LAUNCHER_PATH=%SCRIPT_DIR%"
    set "LAUNCHER_AUTO_DETECTED=1"
)

if exist "%SCRIPT_DIR%StarCitizen_Launcher.exe" (
    if exist "%SCRIPT_DIR%Bin64\StarCitizen.exe" (
        set "LIVE_PATH=%SCRIPT_DIR%"
        set "LIVE_AUTO_DETECTED=1"
    )
)

cls
call :DrawHeader

call :LoadOrSetupConfig

if "!LAUNCHER_PATH!"=="" (
    echo.
    echo Путь к RSI Launcher не настроен.
    echo.
    :SelectLauncherAfterLoad
    call :SelectFolder "Выберите папку с RSI Launcher.exe" LAUNCHER_PATH

    if not "!LAUNCHER_PATH!"=="" (
        if not exist "!LAUNCHER_PATH!\RSI Launcher.exe" (
            echo ✗ RSI Launcher.exe не найден в выбранной папке
            echo.
            set /p "RETRY=Выбрать другую папку? (Y/N): "
            if /i "!RETRY!"=="Y" goto :SelectLauncherAfterLoad
            set "LAUNCHER_PATH="
        ) else (
            echo ✓ RSI Launcher найден: !LAUNCHER_PATH!
            call :SaveConfig
        )
    ) else (
        echo Папка не выбрана
        set /p "RETRY=Попробовать ещё раз? (Y/N): "
        if /i "!RETRY!"=="Y" goto :SelectLauncherAfterLoad
    )
)

if defined LAUNCHER_AUTO_DETECTED (
    call :SaveConfig
    set "LAUNCHER_AUTO_DETECTED="
)

if defined LIVE_AUTO_DETECTED (
    call :SaveConfig
    set "LIVE_AUTO_DETECTED="
)

set "PATHS_LOADED=1"

:RestartDiagnostics
cls
call :DrawHeader
call :DrawPaths

:: =========================================================
:: [1/4] Проверка установленных версий
:: =========================================================
echo [1/4] Проверка установленных версий...
call :ShowProgress "Сканирование папок..." 35

set "LIVE_FOUND=false"
set "PTU_FOUND=false"

set "LIVE_VERSION=не найдена"
set "PTU_VERSION=не найдена"

set "LIVE_BUILD_TYPE=не найден"
set "PTU_BUILD_TYPE=не найден"

set "LIVE_VERSION_DIGITS=не найдена"
set "PTU_VERSION_DIGITS=не найдена"

set "LIVE_TYPE_MISMATCH=false"
set "PTU_TYPE_MISMATCH=false"

if not "!LIVE_PATH!"=="" (
    set "LIVE_FOUND=true"
    set "LIVE_VERSION_FILE=!LIVE_PATH!\data\Localization\korean_(south_korea)\global.ini"
    if exist "!LIVE_VERSION_FILE!" (
        call :GetVersionFromFile "!LIVE_VERSION_FILE!" LIVE_VERSION
        call :GetBuildTypeFromFile "!LIVE_VERSION_FILE!" LIVE_BUILD_TYPE
        call :ExtractVersionDigits "!LIVE_VERSION!" LIVE_VERSION_DIGITS
        if /i not "!LIVE_BUILD_TYPE!"=="LIVE" set "LIVE_TYPE_MISMATCH=true"
    )
)

if not "!PTU_PATH!"=="" (
    set "PTU_FOUND=true"
    set "PTU_VERSION_FILE=!PTU_PATH!\data\Localization\korean_(south_korea)\global.ini"
    if exist "!PTU_VERSION_FILE!" (
        call :GetVersionFromFile "!PTU_VERSION_FILE!" PTU_VERSION
        call :GetBuildTypeFromFile "!PTU_VERSION_FILE!" PTU_BUILD_TYPE
        call :ExtractVersionDigits "!PTU_VERSION!" PTU_VERSION_DIGITS
        if /i not "!PTU_BUILD_TYPE!"=="PTU" set "PTU_TYPE_MISMATCH=true"
    )
)

call :ShowProgress "Локальные версии определены" 100
echo.

if "!LIVE_FOUND!"=="false" if "!PTU_FOUND!"=="false" (
    echo ОШИБКА: Не настроена ни одна папка игры ^(LIVE/PTU^)
    echo.
    echo Запустите настройку путей заново.
    pause
    exit /b 1
)

:: =========================================================
:: [2/4] Проверка релизов на GitHub по тегам
:: =========================================================
echo [2/4] Проверка обновлений на GitHub...
call :ShowProgress "Подключение к GitHub..." 40

call :GetGithubVersionsByTags

if "!GITHUB_OK!"=="false" (
    echo ⚠️ Не удалось получить данные о релизах GitHub
    echo.
) else (
    call :ShowProgress "Версии определены" 100
    if not "!LATEST_LIVE_VERSION!"=="не найдена" (
        echo ✓ LIVE по тегу: !LATEST_LIVE_VERSION! ^(тег: !LATEST_LIVE_TAG!^)
    ) else (
        echo ⚠️ LIVE-тег среди последних релизов не найден
    )
    if not "!LATEST_PTU_VERSION!"=="не найдена" (
        echo ✓ PTU по тегу:  !LATEST_PTU_VERSION! ^(тег: !LATEST_PTU_TAG!^)
    ) else (
        echo ⚠️ PTU-тег среди последних релизов не найден
    )
    echo.
)

:: =========================================================
:: [3/4] Расчёт статусов
:: Тип сборки важнее номера версии
:: =========================================================
if "!LIVE_FOUND!"=="false" (
    set "LIVE_STATUS=папка не настроена"
) else if "!LIVE_VERSION!"=="не найдена" (
    if not "!LATEST_LIVE_VERSION!"=="не найдена" (
        set "LIVE_STATUS=не установлена"
    ) else (
        set "LIVE_STATUS=нет данных GitHub"
    )
) else if "!LIVE_TYPE_MISMATCH!"=="true" (
    set "LIVE_STATUS=неверный тип"
) else if "!LATEST_LIVE_VERSION!"=="не найдена" (
    set "LIVE_STATUS=нет данных GitHub"
) else if "!LIVE_VERSION_DIGITS!"=="!LATEST_LIVE_VERSION!" (
    set "LIVE_STATUS=актуальна"
) else (
    set "LIVE_STATUS=устарела"
)

:: PTU
if "!PTU_FOUND!"=="false" (
    set "PTU_STATUS=папка не настроена"
) else if "!PTU_VERSION!"=="не найдена" (
    if not "!LATEST_PTU_VERSION!"=="не найдена" (
        set "PTU_STATUS=не установлена"
    ) else (
        set "PTU_STATUS=нет данных GitHub"
    )
) else if "!PTU_TYPE_MISMATCH!"=="true" (
    set "PTU_STATUS=неверный тип"
) else if "!LATEST_PTU_VERSION!"=="не найдена" (
    set "PTU_STATUS=нет данных GitHub"
) else if "!PTU_VERSION_DIGITS!"=="!LATEST_PTU_VERSION!" (
    set "PTU_STATUS=актуальна"
) else (
    set "PTU_STATUS=устарела"
)

set "STATUS_TABLE_READY=1"
call :RedrawScreen

:: =========================================================
:: [4/4] Автоматическая установка нужных версий
:: =========================================================
set "INSTALL_LIVE_NEEDED=false"
set "INSTALL_PTU_NEEDED=false"

if "!LIVE_FOUND!"=="true" (
    if "!LIVE_VERSION!"=="не найдена" set "INSTALL_LIVE_NEEDED=true"
    if "!LIVE_TYPE_MISMATCH!"=="true" set "INSTALL_LIVE_NEEDED=true"
    if "!LIVE_TYPE_MISMATCH!"=="false" (
        if not "!LATEST_LIVE_VERSION!"=="не найдена" (
            if not "!LIVE_VERSION_DIGITS!"=="!LATEST_LIVE_VERSION!" set "INSTALL_LIVE_NEEDED=true"
        )
    )
)

if "!PTU_FOUND!"=="true" (
    if "!PTU_VERSION!"=="не найдена" set "INSTALL_PTU_NEEDED=true"
    if "!PTU_TYPE_MISMATCH!"=="true" set "INSTALL_PTU_NEEDED=true"
    if "!PTU_TYPE_MISMATCH!"=="false" (
        if not "!LATEST_PTU_VERSION!"=="не найдена" (
            if not "!PTU_VERSION_DIGITS!"=="!LATEST_PTU_VERSION!" set "INSTALL_PTU_NEEDED=true"
        )
    )
)

if "!INSTALL_LIVE_NEEDED!"=="false" if "!INSTALL_PTU_NEEDED!"=="false" (
    echo [4/4] Все версии актуальны!
    echo.
    echo ✓ Обновление не требуется
    echo Запуск лаунчера через 3 секунды...
    timeout /t 3 /nobreak >nul
    goto :LaunchGame
)

echo [4/4] Запуск автоматической установки...
echo.

if "!INSTALL_LIVE_NEEDED!"=="true" (
    set "CURRENT_INSTALL=LIVE"
    goto :PrepareSelectedArchive
)

if "!INSTALL_PTU_NEEDED!"=="true" (
    set "CURRENT_INSTALL=PTU"
    goto :PrepareSelectedArchive
)

goto :LaunchGame

:PrepareSelectedArchive
set "SELECTED_VERSION=!CURRENT_INSTALL!"

if "!SELECTED_VERSION!"=="LIVE" (
    call set "TARGET_VERSION=%%LIVE_CAND_VER_!LIVE_CURRENT_INDEX!%%"
    call set "TARGET_TAG=%%LIVE_CAND_TAG_!LIVE_CURRENT_INDEX!%%"
    set "SELECTED_PATH=!LIVE_PATH!"
) else (
    call set "TARGET_VERSION=%%PTU_CAND_VER_!PTU_CURRENT_INDEX!%%"
    call set "TARGET_TAG=%%PTU_CAND_TAG_!PTU_CURRENT_INDEX!%%"
    set "SELECTED_PATH=!PTU_PATH!"
)

if "!TARGET_TAG!"=="" (
    echo.
    echo ОШИБКА: Не удалось определить подходящий тег для !SELECTED_VERSION!.
    pause
    goto :RestartDiagnostics
)

echo.
echo Подготовка архива !SELECTED_VERSION! версии !TARGET_VERSION!...
call :ShowProgress "Скачивание архива..." 25

call :DownloadAndExtractArchive "!TARGET_TAG!"
if errorlevel 1 (
    echo ОШИБКА: Не удалось скачать или распаковать архив релиза.
    pause
    goto :RestartDiagnostics
)

if "!EXTRACTED_ROOT!"=="" (
    echo ОШИБКА: Не удалось определить распакованную папку архива.
    pause
    goto :RestartDiagnostics
)

set "ARCHIVE_GLOBAL_INI=!EXTRACTED_ROOT!\data\Localization\korean_(south_korea)\global.ini"
if not exist "!ARCHIVE_GLOBAL_INI!" (
    echo ОШИБКА: Файл global.ini не найден в распакованном архиве.
    pause
    goto :RestartDiagnostics
)

call :ShowProgress "Проверка содержимого архива..." 50

set "ARCHIVE_BUILD_TYPE=не найден"
set "ARCHIVE_VERSION=не найдена"
set "ARCHIVE_VERSION_DIGITS=не найдена"

call :GetBuildTypeFromFile "!ARCHIVE_GLOBAL_INI!" ARCHIVE_BUILD_TYPE
call :GetVersionFromFile "!ARCHIVE_GLOBAL_INI!" ARCHIVE_VERSION
call :ExtractVersionDigits "!ARCHIVE_VERSION!" ARCHIVE_VERSION_DIGITS

if "!ARCHIVE_BUILD_TYPE!"=="не найден" (
    echo ОШИБКА: Не удалось определить тип сборки в архиве.
    pause
    goto :RestartDiagnostics
)

if /i not "!ARCHIVE_BUILD_TYPE!"=="!SELECTED_VERSION!" (
    echo.
    echo ⚠️ ВНИМАНИЕ: В архиве находится сборка типа !ARCHIVE_BUILD_TYPE!
    echo    Выбранная папка: !SELECTED_VERSION!
    echo    Установка отменена.
    echo.
    if /i "!SELECTED_VERSION!"=="LIVE" (
        set "LAST_REJECTED_LIVE_TAG=!TARGET_TAG!"
    ) else (
        set "LAST_REJECTED_PTU_TAG=!TARGET_TAG!"
    )
    call :OfferNextCandidate "!SELECTED_VERSION!"
    if errorlevel 4 goto :ContinueAutoInstall
    if errorlevel 2 goto :ContinueAutoInstall
    if errorlevel 0 goto :PrepareSelectedArchive
)

if not "!ARCHIVE_VERSION_DIGITS!"=="!TARGET_VERSION!" (
    echo.
    echo ⚠️ ВНИМАНИЕ: Версия в архиве не совпадает с ожидаемой по тегу.
    echo    Ожидалась: !TARGET_VERSION!
    echo    В архиве:  !ARCHIVE_VERSION_DIGITS!
    echo    Установка отменена.
    echo.
    if /i "!SELECTED_VERSION!"=="LIVE" (
        set "LAST_REJECTED_LIVE_TAG=!TARGET_TAG!"
    ) else (
        set "LAST_REJECTED_PTU_TAG=!TARGET_TAG!"
    )
    call :OfferNextCandidate "!SELECTED_VERSION!"
    if errorlevel 4 goto :ContinueAutoInstall
    if errorlevel 2 goto :ContinueAutoInstall
    if errorlevel 0 goto :PrepareSelectedArchive
)

echo ✓ Архив подтверждён: !ARCHIVE_BUILD_TYPE! !ARCHIVE_VERSION_DIGITS!
echo.

set "SOURCE_DATA=!EXTRACTED_ROOT!\data"
if not exist "!SOURCE_DATA!" (
    echo ОШИБКА: В архиве отсутствует папка data
    pause
    goto :RestartDiagnostics
)

call :ShowProgress "Копирование файлов..." 75
xcopy "!SOURCE_DATA!\*" "!SELECTED_PATH!\data\" /E /Y /I /Q >nul 2>&1
if errorlevel 1 (
    echo ОШИБКА: Не удалось скопировать файлы локализации.
    pause
    goto :RestartDiagnostics
)

call :ShowProgress "Настройка user.cfg..." 90

if "!SELECTED_VERSION!"=="LIVE" (
    set "USER_CFG_PATH=!LIVE_PATH!\user.cfg"
) else (
    set "USER_CFG_PATH=!PTU_PATH!\user.cfg"
)

call :BackupUserCfg "!USER_CFG_PATH!"
set "backup_result=!errorlevel!"

if "!backup_result!"=="0" (
    call :UpdateUserCfg "!USER_CFG_PATH!"
) else if "!backup_result!"=="2" (
    call :CreateUserCfg "!USER_CFG_PATH!"
) else (
    echo ⚠️ Не удалось создать резервную копию user.cfg. Настройка user.cfg пропущена.
)

call :RefreshVersionStatus
call :RecalculateStatuses

if "!SELECTED_VERSION!"=="LIVE" (
    set "LIVE_REPO=https://github.com/%GITHUB_AUTOR%/%GITHUB_REPO%"
)
if "!SELECTED_VERSION!"=="PTU" (
    set "PTU_REPO=https://github.com/%GITHUB_AUTOR%/%GITHUB_REPO%"
)

::После успешной установки сбрасываем отклонённые теги
set "LAST_REJECTED_LIVE_TAG="
set "LAST_REJECTED_PTU_TAG="

call :SaveConfig
call :RecalculateStatuses

call :CompleteProgress "Завершение..."
call :RedrawScreen
echo ✓ Локализация !SELECTED_VERSION! успешно установлена / обновлена до версии !ARCHIVE_VERSION_DIGITS!
echo.
goto :ContinueAutoInstall

:: =========================================================
:: Запуск лаунчера
:: =========================================================
:LaunchGame
echo.
echo Запуск RSI Launcher...

if not "!LAUNCHER_PATH!"=="" (
    if exist "!LAUNCHER_PATH!\RSI Launcher.exe" (
        echo ✓ Запускаю лаунчер из: !LAUNCHER_PATH!
        powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '!LAUNCHER_PATH!\RSI Launcher.exe'" >nul 2>&1
        exit /b 0
    )
)

if exist "%SCRIPT_DIR%RSI Launcher.exe" (
    echo ✓ Запускаю лаунчер из текущей папки...
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%SCRIPT_DIR%RSI Launcher.exe'" >nul 2>&1
    exit /b 0
)

echo ОШИБКА: RSI Launcher.exe не найден
echo Настройте путь к лаунчеру в конфигурации
pause
exit /b 1

:: =========================================================
:: ФУНКЦИИ
:: =========================================================

:DrawHeader
echo.
echo ════════════════════════════════════════
echo    Star Citizen - Русская локализация
echo ════════════════════════════════════════
echo.
goto :eof

:DrawPaths
if defined PATHS_LOADED (
    echo Настроенные пути:
    if not "!LAUNCHER_PATH!"=="" echo   Лаунчер: !LAUNCHER_PATH!
    if not "!LIVE_PATH!"=="" echo   LIVE:    !LIVE_PATH!
    if not "!PTU_PATH!"=="" echo   PTU:     !PTU_PATH!
    echo.
)
goto :eof

:DrawStatusTable
if defined STATUS_TABLE_READY (
    echo [3/4] Статус локализации:
    echo.
    echo  +------------------------------------------------------------------------------+
    echo  ^| Ветка ^| Установлена            ^| GitHub по тегу       ^| Статус               ^|
    echo  +------------------------------------------------------------------------------+
    call :PrintStatusRow "LIVE" "!LIVE_VERSION!" "!LATEST_LIVE_VERSION!" "!LIVE_STATUS!"
    call :PrintStatusRow "PTU " "!PTU_VERSION!" "!LATEST_PTU_VERSION!" "!PTU_STATUS!"
    echo  +------------------------------------------------------------------------------+
    echo.
)
goto :eof

:PrintStatusRow
call :MakeCell "%~1" 5  C1
call :MakeCell "%~2" 22 C2
call :MakeCell "%~3" 20 C3
call :MakeCell "%~4" 20 C4
echo  ^| !C1! ^| !C2! ^| !C3! ^| !C4! ^|
goto :eof

:MakeCell
setlocal EnableDelayedExpansion
set "text=%~1"
if not defined text set "text=-"
set "text=!text!                                                            "
set "text=!text:~0,%~2!"
endlocal & set "%~3=%text%"
goto :eof

:RedrawScreen
cls
call :DrawHeader
call :DrawPaths
if defined STATUS_TABLE_READY call :DrawStatusTable
goto :eof

:ShowProgress
set "message=%~1"
set "percent=%~2"

set "bar="
set /a "filled=%percent%/5"
set /a "empty=20-filled"

for /l %%i in (1,1,%filled%) do set "bar=!bar!█"
for /l %%i in (1,1,%empty%) do set "bar=!bar!░"

cls
call :DrawHeader
call :DrawPaths
if defined STATUS_TABLE_READY call :DrawStatusTable

echo !message! [!bar!] !percent!%%
goto :eof

:CompleteProgress
set "message=%~1"

cls
call :DrawHeader
call :DrawPaths
if defined STATUS_TABLE_READY call :DrawStatusTable

echo !message! [████████████████████] 100%%
echo.
goto :eof

:ValidateGameFolder
set "game_path=%~1"
set "game_type=%~2"
set "is_valid=0"

if "%game_path%"=="" exit /b 1

echo.
echo Проверяю папку !game_type!...

if not exist "!game_path!\" (
    echo ✗ Папка не существует: !game_path!
    set "is_valid=1"
    goto :ValidateGameFolderEnd
)

if not exist "!game_path!\Bin64\" (
    echo ✗ Отсутствует обязательная папка: Bin64
    set "is_valid=1"
    goto :ValidateGameFolderEnd
)

if not exist "!game_path!\StarCitizen_Launcher.exe" (
    echo ✗ Отсутствует обязательный файл: StarCitizen_Launcher.exe
    set "is_valid=1"
    goto :ValidateGameFolderEnd
)

if not exist "!game_path!\data\Localization\korean_(south_korea)\global.ini" (
    echo ⚠ Файл локализации пока не найден ^(это допустимо для новой установки^)
)

echo ✓ Найден StarCitizen_Launcher.exe
echo ✓ Найдена папка Bin64

:ValidateGameFolderEnd
if !is_valid! equ 0 (
    echo ✓ Папка !game_type! прошла проверку
) else (
    echo ✗ Папка !game_type! не прошла проверку
)
exit /b !is_valid!

:LoadOrSetupConfig
if exist "%CONFIG_FILE%" (
    echo Загружаю сохранённую конфигурацию...
    for /f "usebackq tokens=1,* delims==" %%a in ("%CONFIG_FILE%") do (
        if "%%a"=="LAUNCHER_PATH" set "LAUNCHER_PATH=%%b"
        if "%%a"=="LIVE_REPO" set "LIVE_REPO=%%b"
        if "%%a"=="LIVE_VERSION" set "LIVE_VERSION=%%b"
        if "%%a"=="LIVE_PATH" set "LIVE_PATH=%%b"
        if "%%a"=="PTU_REPO" set "PTU_REPO=%%b"
        if "%%a"=="PTU_VERSION" set "PTU_VERSION=%%b"
        if "%%a"=="PTU_PATH" set "PTU_PATH=%%b"
    )

    echo Настроенные пути:
    if not "!LAUNCHER_PATH!"=="" echo   Лаунчер: !LAUNCHER_PATH!
    if not "!LIVE_PATH!"=="" echo   LIVE: !LIVE_PATH!
    if not "!PTU_PATH!"=="" echo   PTU:  !PTU_PATH!
    echo.

    if not "!LIVE_PATH!"=="" (
        call :ValidateGameFolder "!LIVE_PATH!" "LIVE"
        if errorlevel 1 (
            echo ⚠ Папка LIVE недоступна по сохранённому пути
            set "LIVE_PATH="
        )
    )

    if not "!PTU_PATH!"=="" (
        call :ValidateGameFolder "!PTU_PATH!" "PTU"
        if errorlevel 1 (
            echo ⚠ Папка PTU недоступна по сохранённому пути
            set "PTU_PATH="
        )
    )

    if not "!LAUNCHER_PATH!"=="" (
        if not exist "!LAUNCHER_PATH!\RSI Launcher.exe" (
            echo ⚠ Лаунчер не найден по указанному пути
            set "LAUNCHER_PATH="
        )
    )

    if not "!LIVE_PATH!"=="" goto :eof
    if not "!PTU_PATH!"=="" goto :eof

    echo.
    echo Необходимо настроить пути заново.
) else (
    echo Конфигурационный файл не найден.
    echo Запуск первоначальной настройки...
)

:SetupConfig
cls
echo.
echo ════════════════════════════════════════
echo    Первоначальная настройка путей
echo ════════════════════════════════════════
echo.

echo [1/4] Настройка пути к RSI Launcher
echo.

if not "!LAUNCHER_PATH!"=="" (
    if not defined LAUNCHER_AUTO_DETECTED (
        echo ✓ Текущий путь к лаунчеру: !LAUNCHER_PATH!
        set /p "RECONFIGURE_LAUNCHER=Переустановить путь к лаунчеру? (Y/N): "
        if /i not "!RECONFIGURE_LAUNCHER!"=="Y" goto :SkipLauncherSetup
    ) else (
        goto :SkipLauncherSetup
    )
)

:SelectLauncherFolder
call :SelectFolder "Выберите папку с RSI Launcher.exe" LAUNCHER_PATH
if not "!LAUNCHER_PATH!"=="" (
    if not exist "!LAUNCHER_PATH!\RSI Launcher.exe" (
        echo ✗ RSI Launcher.exe не найден в выбранной папке
        set /p "RETRY=Выбрать другую папку? (Y/N): "
        if /i "!RETRY!"=="Y" goto :SelectLauncherFolder
        set "LAUNCHER_PATH="
    ) else (
        echo ✓ RSI Launcher найден: !LAUNCHER_PATH!
    )
) else (
    echo Папка не выбрана
)

:SkipLauncherSetup

echo.
echo [2/4] Поиск установленных версий игры
echo Автоматический поиск установленных версий...
call :FindStandardPaths

echo.
echo [3/4] Настройка папки LIVE

if defined LIVE_AUTO_DETECTED (
    echo ✓ Папка LIVE автоматически обнаружена: !LIVE_PATH!
    set "LIVE_AUTO_DETECTED="
    goto :SkipLiveSetup
)

if "!LIVE_FOUND!"=="true" (
    echo ✓ Найдена потенциальная папка LIVE: !LIVE_PATH!
    call :ValidateGameFolder "!LIVE_PATH!" "LIVE"
    if not errorlevel 1 (
        set /p "USE_FOUND=Использовать этот путь? (Y/N): "
        if /i not "!USE_FOUND!"=="Y" (
            set "LIVE_FOUND=false"
            set "LIVE_PATH="
        )
    ) else (
        set "LIVE_FOUND=false"
        set "LIVE_PATH="
    )
)

if "!LIVE_FOUND!"=="false" (
    :SelectLiveFolder
    call :SelectFolder "Выберите папку LIVE игры" LIVE_PATH
    if not "!LIVE_PATH!"=="" (
        call :ValidateGameFolder "!LIVE_PATH!" "LIVE"
        if errorlevel 1 (
            set /p "RETRY=Выбрать другую папку? (Y/N): "
            if /i "!RETRY!"=="Y" goto :SelectLiveFolder
            set "LIVE_PATH="
        )
    )
)

:SkipLiveSetup

echo.
echo [4/4] Настройка PTU (опционально)

if "!PTU_FOUND!"=="true" (
    echo ✓ Найдена потенциальная папка PTU: !PTU_PATH!
    call :ValidateGameFolder "!PTU_PATH!" "PTU"
    if not errorlevel 1 (
        set /p "USE_FOUND=Использовать этот путь? (Y/N): "
        if /i not "!USE_FOUND!"=="Y" (
            set "PTU_FOUND=false"
            set "PTU_PATH="
        )
    ) else (
        set "PTU_FOUND=false"
        set "PTU_PATH="
    )
)

if "!PTU_FOUND!"=="false" (
    set /p "ASK_PTU=Настроить папку PTU? (Y/N): "
    if /i "!ASK_PTU!"=="Y" (
        :SelectPTUFolder
        call :SelectFolder "Выберите папку PTU игры" PTU_PATH
        if not "!PTU_PATH!"=="" (
            call :ValidateGameFolder "!PTU_PATH!" "PTU"
            if errorlevel 1 (
                set /p "RETRY=Выбрать другую папку? (Y/N): "
                if /i "!RETRY!"=="Y" goto :SelectPTUFolder
                set "PTU_PATH="
            )
        )
    )
)

if "!LIVE_PATH!"=="" if "!PTU_PATH!"=="" (
    echo ОШИБКА: Не настроено ни одной папки игры
    pause
    exit /b 1
)

call :SaveConfig
echo.
echo ✓ Конфигурация сохранена: %CONFIG_FILE%
timeout /t 2 /nobreak >nul
goto :eof

:SaveConfig
(
    echo //Конфигурационный файл скрипта русификации StarCitizen
    echo LAUNCHER_PATH=!LAUNCHER_PATH!
    echo LIVE_REPO=!LIVE_REPO!
    echo LIVE_VERSION=!LIVE_VERSION!
    echo LIVE_PATH=!LIVE_PATH!
    echo PTU_REPO=!PTU_REPO!
    echo PTU_VERSION=!PTU_VERSION!
    echo PTU_PATH=!PTU_PATH!
) > "%CONFIG_FILE%"
goto :eof

:FindStandardPaths
set "LIVE_FOUND=false"
set "PTU_FOUND=false"

set DISKS=A B C D E F G H I J K L M N O P Q R S T U V W X Y Z

for %%D in (!DISKS!) do (
    set "test_path1=%%D:\Roberts Space Industries\StarCitizen\LIVE"
    set "test_path2=%%D:\Program Files\Roberts Space Industries\StarCitizen\LIVE"
    set "test_path3=%%D:\Program Files (x86)\Roberts Space Industries\StarCitizen\LIVE"
    set "test_path4=%%D:\Games\StarCitizen\LIVE"
    set "test_path5=%%D:\StarCitizen\LIVE"

    for %%P in ("!test_path1!" "!test_path2!" "!test_path3!" "!test_path4!" "!test_path5!") do (
        if exist "%%~P\StarCitizen_Launcher.exe" (
            if "!LIVE_FOUND!"=="false" (
                set "LIVE_PATH=%%~P"
                set "LIVE_FOUND=true"
            )
        )
    )
)

for %%D in (!DISKS!) do (
    set "test_path1=%%D:\Roberts Space Industries\StarCitizen\PTU"
    set "test_path2=%%D:\Program Files\Roberts Space Industries\StarCitizen\PTU"
    set "test_path3=%%D:\Program Files (x86)\Roberts Space Industries\StarCitizen\PTU"
    set "test_path4=%%D:\Games\StarCitizen\PTU"
    set "test_path5=%%D:\StarCitizen\PTU"

    for %%P in ("!test_path1!" "!test_path2!" "!test_path3!" "!test_path4!" "!test_path5!") do (
        if exist "%%~P\StarCitizen_Launcher.exe" (
            if "!PTU_FOUND!"=="false" (
                set "PTU_PATH=%%~P"
                set "PTU_FOUND=true"
            )
        )
    )
)
goto :eof

:SelectFolder
set "description=%~1"
set "varname=%~2"
set "SELECTED_PATH="

echo.
echo %description%
echo.

set "psScript=Add-Type -AssemblyName System.Windows.Forms; $dlg = New-Object System.Windows.Forms.FolderBrowserDialog; $dlg.Description = '%description%'; $dlg.RootFolder = 'MyComputer'; $dlg.ShowNewFolderButton = $false; if($dlg.ShowDialog() -eq 'OK'){ $dlg.SelectedPath }"
for /f "delims=" %%F in ('powershell -NoProfile -ExecutionPolicy Bypass -Command "!psScript!"') do set "SELECTED_PATH=%%F"

if "!SELECTED_PATH!"=="" (
    set "!varname!="
    exit /b 1
) else (
    echo Выбрана папка: !SELECTED_PATH!
    set "!varname!=!SELECTED_PATH!"
    exit /b 0
)

:GetVersionFromFile
set "file_path=%~1"
set "return_var=%~2"
set "version=не найдена"

if not exist "%file_path%" (
    set "%return_var%=не найдена"
    goto :eof
)

for /f "usebackq delims=" %%b in (`powershell -NoProfile -ExecutionPolicy Bypass -Command "try { $content = Get-Content -LiteralPath '%file_path%' -Encoding UTF8 -Raw; if($content -match 'Установленная версия:\s+((?:LIVE|PTU)\s+[\d\.]+\s+v\d+)'){ $matches[1] } else { 'не найдена' } } catch { 'не найдена' }"`) do (
    set "version=%%b"
)

set "%return_var%=%version%"
goto :eof

:GetBuildTypeFromFile
set "file_path=%~1"
set "return_var=%~2"
set "build_type=не найден"

if not exist "%file_path%" (
    set "%return_var%=не найден"
    goto :eof
)

for /f "usebackq delims=" %%b in (`powershell -NoProfile -ExecutionPolicy Bypass -Command "try { $content = Get-Content -LiteralPath '%file_path%' -Encoding UTF8 -Raw; if($content -match 'Установленная версия:\s+(LIVE|PTU)\s+[\d\.]+\s+v\d+'){ $matches[1] } else { 'не найден' } } catch { 'не найден' }"`) do (
    set "build_type=%%b"
)

set "%return_var%=%build_type%"
goto :eof

:ExtractVersionDigits
set "full_version=%~1"
set "return_var=%~2"
set "version_digits=не найдена"

for /f "tokens=2,3" %%a in ("%full_version%") do (
    set "version_digits=%%a %%b"
)

set "%return_var%=!version_digits!"
goto :eof

:BackupUserCfg
set "user_cfg_path=%~1"

if exist "%user_cfg_path%" (
    copy "%user_cfg_path%" "%user_cfg_path%.bak" >nul 2>&1
    if errorlevel 1 (
        exit /b 1
    ) else (
        exit /b 0
    )
) else (
    exit /b 2
)

:UpdateUserCfg
set "user_cfg_path=%~1"
set "backup_path=%user_cfg_path%.bak"
set "new_path=%user_cfg_path%.new"

(
    echo g_language=korean_(south_korea)
    echo g_languageAudio=english
) > "%new_path%"

for /f "usebackq delims=" %%a in ("%backup_path%") do (
    set "line=%%a"
    set "skip_line=false"

    echo !line! | findstr /i /b "g_language=" >nul
    if !errorlevel! equ 0 set "skip_line=true"

    echo !line! | findstr /i /b "g_languageAudio=" >nul
    if !errorlevel! equ 0 set "skip_line=true"

    if "!skip_line!"=="false" >> "%new_path%" echo !line!
)

move /y "%new_path%" "%user_cfg_path%" >nul 2>&1
if errorlevel 1 (
    copy /y "%backup_path%" "%user_cfg_path%" >nul 2>&1
    exit /b 1
) else (
    exit /b 0
)

:CreateUserCfg
set "user_cfg_path=%~1"
(
    echo g_language=korean_(south_korea)
    echo g_languageAudio=english
) > "%user_cfg_path%"

if exist "%user_cfg_path%" (
    exit /b 0
) else (
    exit /b 1
)

:RefreshVersionStatus
if not "!LIVE_PATH!"=="" (
    set "LIVE_VERSION_FILE=!LIVE_PATH!\data\Localization\korean_(south_korea)\global.ini"
    if exist "!LIVE_VERSION_FILE!" (
        call :GetVersionFromFile "!LIVE_VERSION_FILE!" LIVE_VERSION
        call :GetBuildTypeFromFile "!LIVE_VERSION_FILE!" LIVE_BUILD_TYPE
        call :ExtractVersionDigits "!LIVE_VERSION!" LIVE_VERSION_DIGITS
        set "LIVE_FOUND=true"
        set "LIVE_TYPE_MISMATCH=false"
        if /i not "!LIVE_BUILD_TYPE!"=="LIVE" set "LIVE_TYPE_MISMATCH=true"
    ) else (
        set "LIVE_VERSION=не найдена"
        set "LIVE_BUILD_TYPE=не найден"
        set "LIVE_VERSION_DIGITS=не найдена"
        set "LIVE_FOUND=true"
        set "LIVE_TYPE_MISMATCH=false"
    )
)

if not "!PTU_PATH!"=="" (
    set "PTU_VERSION_FILE=!PTU_PATH!\data\Localization\korean_(south_korea)\global.ini"
    if exist "!PTU_VERSION_FILE!" (
        call :GetVersionFromFile "!PTU_VERSION_FILE!" PTU_VERSION
        call :GetBuildTypeFromFile "!PTU_VERSION_FILE!" PTU_BUILD_TYPE
        call :ExtractVersionDigits "!PTU_VERSION!" PTU_VERSION_DIGITS
        set "PTU_FOUND=true"
        set "PTU_TYPE_MISMATCH=false"
        if /i not "!PTU_BUILD_TYPE!"=="PTU" set "PTU_TYPE_MISMATCH=true"
    ) else (
        set "PTU_VERSION=не найдена"
        set "PTU_BUILD_TYPE=не найден"
        set "PTU_VERSION_DIGITS=не найдена"
        set "PTU_FOUND=true"
        set "PTU_TYPE_MISMATCH=false"
    )
)
goto :eof

:RecalculateStatuses
if "!LIVE_FOUND!"=="false" (
    set "LIVE_STATUS=папка не настроена"
) else if "!LIVE_VERSION!"=="не найдена" (
    if not "!LATEST_LIVE_VERSION!"=="не найдена" (
        set "LIVE_STATUS=не установлена"
    ) else (
        set "LIVE_STATUS=нет данных GitHub"
    )
) else if "!LIVE_TYPE_MISMATCH!"=="true" (
    set "LIVE_STATUS=неверный тип"
) else if "!LATEST_LIVE_VERSION!"=="не найдена" (
    set "LIVE_STATUS=нет данных GitHub"
) else if "!LIVE_VERSION_DIGITS!"=="!LATEST_LIVE_VERSION!" (
    set "LIVE_STATUS=актуальна"
) else (
    set "LIVE_STATUS=устарела"
)

if "!PTU_FOUND!"=="false" (
    set "PTU_STATUS=папка не настроена"
) else if "!PTU_VERSION!"=="не найдена" (
    if not "!LATEST_PTU_VERSION!"=="не найдена" (
        set "PTU_STATUS=не установлена"
    ) else (
        set "PTU_STATUS=нет данных GitHub"
    )
) else if "!PTU_TYPE_MISMATCH!"=="true" (
    set "PTU_STATUS=неверный тип"
) else if "!LATEST_PTU_VERSION!"=="не найдена" (
    set "PTU_STATUS=нет данных GitHub"
) else if "!PTU_VERSION_DIGITS!"=="!LATEST_PTU_VERSION!" (
    set "PTU_STATUS=актуальна"
) else (
    set "PTU_STATUS=устарела"
)
goto :eof

:GetGithubVersionsByTags
set "GITHUB_OK=false"

for /l %%N in (1,1,50) do (
    set "LIVE_CAND_VER_%%N="
    set "LIVE_CAND_TAG_%%N="
    set "PTU_CAND_VER_%%N="
    set "PTU_CAND_TAG_%%N="
)

set "LIVE_CAND_COUNT=0"
set "PTU_CAND_COUNT=0"
set "LIVE_CURRENT_INDEX=1"
set "PTU_CURRENT_INDEX=1"

for /f "usebackq tokens=1,2,3 delims=|" %%a in (`
powershell -NoProfile -ExecutionPolicy Bypass -Command "$o='%GITHUB_AUTOR%';$r='%GITHUB_REPO%';$wc=New-Object Net.WebClient;$wc.Headers.Add('User-Agent','SC-RU-Updater');try{$relsJson=$wc.DownloadString(('https://api.github.com/repos/{0}/{1}/releases?per_page=50' -f $o,$r));$rels=$relsJson|ConvertFrom-Json;foreach($rel in $rels){$tag=$rel.tag_name;if($tag -match '^(\d+\.\d+\.\d+)-(v\d+)$'){Write-Output ('LIVE|'+$matches[1]+' '+$matches[2]+'|'+$tag)}elseif($tag -match '^(\d+\.\d+\.\d+)-(v\d+)-ptu$'){Write-Output ('PTU|'+$matches[1]+' '+$matches[2]+'|'+$tag)}}}catch{}"
`) do (
    if "%%a"=="LIVE" (
        set /a LIVE_CAND_COUNT+=1
        set "LIVE_CAND_VER_!LIVE_CAND_COUNT!=%%b"
        set "LIVE_CAND_TAG_!LIVE_CAND_COUNT!=%%c"
    )
    if "%%a"=="PTU" (
        set /a PTU_CAND_COUNT+=1
        set "PTU_CAND_VER_!PTU_CAND_COUNT!=%%b"
        set "PTU_CAND_TAG_!PTU_CAND_COUNT!=%%c"
    )
)

call :SetCurrentGithubVersions

if !LIVE_CAND_COUNT! gtr 0 set "GITHUB_OK=true"
if !PTU_CAND_COUNT! gtr 0 set "GITHUB_OK=true"
goto :eof

:SetCurrentGithubVersions
set "LATEST_LIVE_VERSION=не найдена"
set "LATEST_LIVE_TAG="
set "LATEST_PTU_VERSION=не найдена"
set "LATEST_PTU_TAG="

if !LIVE_CAND_COUNT! geq !LIVE_CURRENT_INDEX! (
    call set "LATEST_LIVE_VERSION=%%LIVE_CAND_VER_!LIVE_CURRENT_INDEX!%%"
    call set "LATEST_LIVE_TAG=%%LIVE_CAND_TAG_!LIVE_CURRENT_INDEX!%%"
)

if !PTU_CAND_COUNT! geq !PTU_CURRENT_INDEX! (
    call set "LATEST_PTU_VERSION=%%PTU_CAND_VER_!PTU_CURRENT_INDEX!%%"
    call set "LATEST_PTU_TAG=%%PTU_CAND_TAG_!PTU_CURRENT_INDEX!%%"
)
goto :eof

:OfferNextCandidate
set "branch=%~1"
set "NEXT_VERSION="
set "NEXT_TAG="
set "FOUND=false"
set "ALREADY_INSTALLED=false"

if /i "%branch%"=="LIVE" (
    for /l %%I in (!LIVE_CURRENT_INDEX!,1,!LIVE_CAND_COUNT!) do (
        if "!FOUND!"=="false" if "!ALREADY_INSTALLED!"=="false" (
            if not "%%I"=="!LIVE_CURRENT_INDEX!" (
                call set "CAND_VERSION=%%LIVE_CAND_VER_%%I%%"
                call set "CAND_TAG=%%LIVE_CAND_TAG_%%I%%"

                set "SKIP=false"

                if defined LAST_REJECTED_LIVE_TAG (
                    if /i "!CAND_TAG!"=="!LAST_REJECTED_LIVE_TAG!" set "SKIP=true"
                )

                if /i "!LIVE_BUILD_TYPE!"=="LIVE" (
                    if "!LIVE_VERSION_DIGITS!"=="!CAND_VERSION!" (
                        set "ALREADY_INSTALLED=true"
                    )
                )

                if "!ALREADY_INSTALLED!"=="false" if "!SKIP!"=="false" (
                    set "NEXT_VERSION=!CAND_VERSION!"
                    set "NEXT_TAG=!CAND_TAG!"
                    set "NEXT_INDEX=%%I"
                    set "FOUND=true"
                )
            )
        )
    )

    if "!ALREADY_INSTALLED!"=="true" (
        echo Подходящая LIVE версия уже установлена: !LIVE_VERSION!
        echo Дальнейшие действия не требуются.
        exit /b 4
    )

    if "!FOUND!"=="false" (
        echo Других LIVE-кандидатов по списку тегов больше нет.
        exit /b 2
    )

    echo Автоматически пробую следующий LIVE тег: !NEXT_TAG! ^(!NEXT_VERSION!^)
    set /a LIVE_CURRENT_INDEX=!NEXT_INDEX!
    call :SetCurrentGithubVersions
    exit /b 0
)

if /i "%branch%"=="PTU" (
    for /l %%I in (!PTU_CURRENT_INDEX!,1,!PTU_CAND_COUNT!) do (
        if "!FOUND!"=="false" if "!ALREADY_INSTALLED!"=="false" (
            if not "%%I"=="!PTU_CURRENT_INDEX!" (
                call set "CAND_VERSION=%%PTU_CAND_VER_%%I%%"
                call set "CAND_TAG=%%PTU_CAND_TAG_%%I%%"

                set "SKIP=false"

                if defined LAST_REJECTED_PTU_TAG (
                    if /i "!CAND_TAG!"=="!LAST_REJECTED_PTU_TAG!" set "SKIP=true"
                )

                if /i "!PTU_BUILD_TYPE!"=="PTU" (
                    if "!PTU_VERSION_DIGITS!"=="!CAND_VERSION!" (
                        set "ALREADY_INSTALLED=true"
                    )
                )

                if "!ALREADY_INSTALLED!"=="false" if "!SKIP!"=="false" (
                    set "NEXT_VERSION=!CAND_VERSION!"
                    set "NEXT_TAG=!CAND_TAG!"
                    set "NEXT_INDEX=%%I"
                    set "FOUND=true"
                )
            )
        )
    )

    if "!ALREADY_INSTALLED!"=="true" (
        echo Подходящая PTU версия уже установлена: !PTU_VERSION!
        echo Дальнейшие действия не требуются.
        exit /b 4
    )

    if "!FOUND!"=="false" (
        echo Других PTU-кандидатов по списку тегов больше нет.
        exit /b 2
    )

    echo Автоматически пробую следующий PTU тег: !NEXT_TAG! ^(!NEXT_VERSION!^)
    set /a PTU_CURRENT_INDEX=!NEXT_INDEX!
    call :SetCurrentGithubVersions
    exit /b 0
)

exit /b 2

:ContinueAutoInstall
if "!CURRENT_INSTALL!"=="LIVE" (
    set "INSTALL_LIVE_NEEDED=false"
    if "!INSTALL_PTU_NEEDED!"=="true" (
        set "CURRENT_INSTALL=PTU"
        goto :PrepareSelectedArchive
    )
)

if "!CURRENT_INSTALL!"=="PTU" (
    set "INSTALL_PTU_NEEDED=false"
)

call :RedrawScreen
echo Все необходимые действия завершены.
echo Запуск лаунчера через 3 секунды...
timeout /t 3 /nobreak >nul
goto :LaunchGame

:DownloadAndExtractArchive
set "req_tag=%~1"
set "EXTRACTED_ROOT="
if "%req_tag%"=="" exit /b 1

set "WORK_DIR=%TEMP_DIR%\work"
set "ZIP_FILE=%WORK_DIR%\release.zip"
set "EXTRACT_DIR=%WORK_DIR%\extracted"

if exist "%WORK_DIR%" rmdir /s /q "%WORK_DIR%" >nul 2>&1
mkdir "%WORK_DIR%" >nul 2>&1

set "DOWNLOAD_URL=https://github.com/%GITHUB_AUTOR%/%GITHUB_REPO%/archive/refs/tags/%req_tag%.zip"

powershell -NoProfile -ExecutionPolicy Bypass -Command "try { Invoke-WebRequest -Headers @{ 'User-Agent'='SC-RU-Updater' } -Uri '%DOWNLOAD_URL%' -OutFile '%ZIP_FILE%' -UseBasicParsing; exit 0 } catch { exit 1 }" >nul 2>&1
if errorlevel 1 exit /b 1

call :ShowProgress "Распаковка архива..." 40
powershell -NoProfile -ExecutionPolicy Bypass -Command "try { Expand-Archive -Path '%ZIP_FILE%' -DestinationPath '%EXTRACT_DIR%' -Force; exit 0 } catch { exit 1 }" >nul 2>&1
if errorlevel 1 exit /b 1

for /d %%D in ("%EXTRACT_DIR%\StarCitizenRu-*") do (
    if exist "%%~fD\data\Localization\korean_(south_korea)\global.ini" (
        set "EXTRACTED_ROOT=%%~fD"
    )
)

if "!EXTRACTED_ROOT!"=="" exit /b 1
exit /b 0