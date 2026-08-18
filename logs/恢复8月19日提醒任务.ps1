# 恢复 8/19 建项目提醒（装系统后运行，需管理员权限）
# 用法：右键"以管理员身份运行"，或 PowerShell 中执行
# 说明：重建提醒脚本 + 计划任务 ZZ_GameJam_0819_Reminder（2026-08-19 09:00 一次性）

$ErrorActionPreference = "Stop"
Write-Host "=== 恢复 8/19 建项目提醒任务 ==="

# 1) 恢复提醒脚本（UTF-8 带 BOM，避免中文乱码）
$scriptPath = Join-Path $env:LOCALAPPDATA "Temp\GameJam0819Reminder.ps1"
$content = @'
# 8/19 建项目提醒（由 Windows 计划任务触发）
# 触发时间：2026-08-19 09:00
Add-Type -AssemblyName PresentationFramework
[System.Windows.MessageBox]::Show("8月19日（周三）09:00：请在 TapTap 制造新建参赛项目并绑定本期 Game Jam 活动！`n`n操作顺序见《上下文交接.md》第五节。", "制造新星 Game Jam 提醒", 'OK', 'Information') | Out-Null
Start-Process 'https://www.taptap.cn/moment/816645514320676469'
'@
[System.IO.File]::WriteAllText($scriptPath, $content, (New-Object System.Text.UTF8Encoding($true)))
Write-Host "提醒脚本已写入: $scriptPath"

# 2) 注册计划任务（一次性，8/19 09:00，允许电池 + 错过补跑）
$action   = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`""
$trigger  = New-ScheduledTaskTrigger -Once -At "2026-08-19T09:00:00"
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
Register-ScheduledTask -TaskName "ZZ_GameJam_0819_Reminder" -Action $action -Trigger $trigger -Settings $settings -Description "8/19 09:00 提醒建项目并绑定活动" -Force
Write-Host "计划任务 ZZ_GameJam_0819_Reminder 已注册。"

# 3) 验证
Write-Host "`n=== 验证 ==="
schtasks /Query /TN "ZZ_GameJam_0819_Reminder" /FO LIST

Write-Host "`n完成。若 8/19 已过则无需提醒；8/19 建项目始终是最高优先级日程项。"
