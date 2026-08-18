# 8/19 建项目提醒（由 Windows 计划任务触发）
# 触发时间：2026-08-19 09:00
# 作用：弹窗提醒 + 打开 TapTap 制造活动页

Add-Type -AssemblyName PresentationFramework
[System.Windows.MessageBox]::Show(
    "8月19日（周三）09:00：请在 TapTap 制造新建参赛项目并绑定本期 Game Jam 活动！`n`n操作顺序见《上下文交接.md》第五节。",
    "制造新星 Game Jam 提醒",
    'OK',
    'Information'
) | Out-Null

Start-Process 'https://www.taptap.cn/moment/816645514320676469'
