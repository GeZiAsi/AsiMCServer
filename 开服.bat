@echo off
setlocal enabledelayedexpansion

:: ============================================
:: Minecraft 服务器启动脚本 By格兹亚西
:: 版本：v15.2 最后更新：2024/03/25
:: ============================================

:: ---------- 初始化环境设置 ----------
chcp 936 >nul
mode con cols=80 lines=25
title 服务器管理器初始化...

:: ---------- 全局配置 ----------
set "restart_count=0"
set "debug_mode=0"
set "config_file=服务器配置.txt"
set "log_file=运行日志.log"
set "java_path="
set "core_file="

:: ---------- 路径标准化处理 ----------
set "script_dir=%~dp0"
cd /d "%script_dir%" 2>nul || exit /b

:: ---------- 日志系统初始化 ----------
if not exist "%log_file%" (
    echo 时间戳 [状态] 事件详情 > "%log_file%"
)

:: ---------- 主程序入口 ----------
if "%1"=="restart" goto server_start
if "%1"=="debug" set "debug_mode=1"

call :check_first_run
call :load_config

:: ---------- 主菜单系统 ----------
:main_menu
cls
echo.
echo [Minecraft 服务器管理器 v15.2 By格兹亚西]
echo 1. 启动服务器
echo 2. 编辑配置
echo 3. 查看日志
echo Q. 退出系统
echo.
:menu_input
set "choice="
set /p "choice=请选择操作："
goto menu_%choice%

:: ---------- 功能模块分支 ----------
:menu_1
call :server_precheck
goto main_menu

:menu_2
call :edit_config
goto main_menu

:menu_3
call :view_log
goto main_menu

:menu_Q
exit /b 0

:: ---------- 服务器预检系统 ----------
:server_precheck
call :log "INFO" "开始服务器预检流程"

:: Java环境检测
call :find_java || (
    call :log "ERROR" "Java环境检测失败"
    call :show_error "未找到有效的Java运行时"
    goto main_menu
)

:: 核心文件检测
set "core_file="
for /r "%script_dir%" %%i in (*.jar) do (
    if /i "%%~xi"==".jar" (
        set "core_file=%%~nxi"
        call :log "INFO" "发现核心文件：%%i"
        goto core_found
    )
)
:core_found
if not defined core_file (
    call :log "ERROR" "未找到核心文件"
    call :missing_core_menu
)

:: 端口检测
call :check_port || (
    call :log "ERROR" "端口%server_port%被占用"
    call :show_error "端口 %server_port% 已被其他程序使用"
    goto main_menu
)
goto server_start

:: ---------- 核心文件缺失菜单 ----------
:missing_core_menu
cls
echo.
echo [错误] 未找到服务端核心文件
echo 1. 下载官方核心
echo 2. 下载PaperMC
echo 3. 镜像站下载
echo 4. 手动指定文件
echo B. 返回主菜单
echo.
:missing_core_input
set "choice="
set /p "choice=请选择操作："
goto missing_core_%choice%

:: ---------- 镜像站子菜单 ----------
:missing_core_3
cls
echo.
echo [镜像站选择 By格兹亚西]
echo 1. 极星镜像站（推荐国内）
echo 2. FastMirror镜像站
echo B. 返回上级菜单
echo.
:mirror_input
set "choice="
set /p "choice=请选择镜像站："
if "%choice%"=="1" (
    start "" "https://mirror.polars.cc/#/minecraft/core"
    goto download_help
) else if "%choice%"=="2" (
    start "" "https://www.fastmirror.net/#/home"
    goto download_help
)
if /i "%choice%"=="B" goto missing_core_menu
goto mirror_input

:: ---------- 下载帮助提示 ----------
:download_help
cls
echo.
echo 请将下载的服务器核心文件（.jar）放入以下目录：
echo %script_dir%
echo 按任意键返回主菜单...
pause >nul
goto main_menu

:: ---------- 配置文件管理系统 ----------
:create_config
(
    echo # ===========================================
    echo # Minecraft 服务器配置文件 By格兹亚西
    echo # 生成时间：%date% %time%
    echo # ===========================================
    echo # 服务器显示名称（支持特殊字符）
    echo server_name=我的世界服务器
    
    echo # 自动检测核心（1=开启 0=关闭）
    echo auto_detect=1
    
    echo # 核心文件名（示例：paper-1.20.4.jar）
    echo core_file=server.jar
    
    echo # 内存设置（G=GB，建议4G-8G）
    echo max_memory=4G
    echo min_memory=2G
    
    echo # 服务器端口（默认25565）
    echo server_port=25565
    
    echo # Java路径（auto=自动检测）
    echo java_path=auto
    
    echo # 自动重启设置（单位：秒）
    echo restart_delay=60
    
    echo # 最大重启次数（防崩溃循环）
    echo max_restarts=5
) > "%config_file%"
exit /b

:update_config
(
    echo # 最后更新时间：%date% %time%
    type "%config_file%" | findstr /v /c:"# 最后更新时间"
) > "%config_file%.tmp"
move /y "%config_file%.tmp" "%config_file%" >nul
exit /b

:load_config
for /f "usebackq tokens=1* delims==" %%a in ("%config_file%") do (
    set "param=%%a"
    set "value=%%b"
    set "!param!=!value!"
)
exit /b

:: ---------- 其他核心功能 ----------
:check_first_run
if not exist "%config_file%" (
    call :create_config
    call :log "INFO" "初始化配置文件"
)
exit /b

:find_java
where java >nul 2>&1 && (
    for /f "delims=" %%j in ('where java') do (
        set "java_path=%%j"
        call :log "INFO" "Java路径：%%j"
        exit /b 0
    )
)
exit /b 1

:check_port
powershell -Command "$port = %server_port%; $result = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue; if ($result) { exit 1 } else { exit 0 }"
if %errorlevel% equ 1 (
    exit /b 1
) else (
    exit /b 0
)

:log
>> "%log_file%" echo %date% %time% [%~1] %~2
exit /b

:: ---------- 服务器启动流程 ----------
:server_start
call :log "INFO" "正在启动服务器（第%restart_count%次尝试）"

:: 动态生成窗口标题
title [%server_name%] 端口:%server_port% 内存:%max_memory%/%min_memory% By格兹亚西

if not exist "server.properties" (
    (
        echo # 自动生成的服务端配置 By格兹亚西
        echo server-port=%server_port%
        echo max-players=20
        echo online-mode=true
        echo motd=由格兹亚西脚本创建的服务器
    ) > "server.properties"
)

if not exist "eula.txt" (
    (
        echo eula=true
        echo # 接受时间：%date% %time%
    ) > "eula.txt"
)

set "java_cmd="%java_path%" -Xmx%max_memory% -Xms%min_memory% -jar "%core_file%" nogui"

if %debug_mode% equ 1 (
    cmd /k "%java_cmd%"
) else (
    cmd /c "%java_cmd%"
)

:: 自动重启逻辑
set /a "restart_count+=1"
if %restart_count% lss %max_restarts% (
    call :log "INFO" "计划%restart_delay%秒后重启"
    timeout /t %restart_delay% >nul
    start "" /b "%~f0" restart %restart_count%
)
exit /b

:: ---------- 辅助功能模块 ----------
:edit_config
notepad "%config_file%"
call :load_config
exit /b

:view_log
if exist "%log_file%" (
    notepad "%log_file%"
) else (
    echo 暂无日志记录
)
pause
exit /b

:show_error
cls
echo.
echo [系统错误] %~1
echo.
echo 技术支持：格兹亚西
echo 建议操作：
echo 1. 检查相关配置
echo 2. 查看帮助文档
echo 3. 返回主菜单
echo.
:error_input
set "choice="
set /p "choice=请选择操作："
goto error_%choice%

:error_1
call :edit_config
goto main_menu

:error_2
start "" "https://github.com/geziya/script-help"
goto main_menu

:error_3
goto main_menu
