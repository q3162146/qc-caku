@echo off
chcp 65001 >nul
title 制造新星 GameJam 工作区备份
echo ============================================================
echo   制造新星 Game Jam 第3期 - 工作区备份
echo   默认复制到 E:\制造新星GameJam备份-20260814
echo   （如需备份到 U 盘/网盘，可拖放目标文件夹到本窗口后回车，
echo     或修改下面 DST 变量）
echo ============================================================
echo.

set SRC=E:\nong\制造新星 Game Jam 第3期
set DST=E:\制造新星GameJam备份-20260814
if not "%~1"=="" set DST=%~1

echo 源: %SRC%
echo 目标: %DST%
echo.
robocopy "%SRC%" "%DST%" /E /R:1 /W:1 /NFL /NDL
echo.
if %ERRORLEVEL% LEQ 7 (
    echo [OK] 备份完成：%DST%
) else (
    echo [警告] 备份过程中有错误，请检查目标路径是否可写。
)
echo.
pause
