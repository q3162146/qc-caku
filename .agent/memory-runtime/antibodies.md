# 跨项目抗体清单

> 从历史项目中积累的通用踩坑经验，跟随 skill 旅行到新项目。
> POST-3 同步时，仅写入标记为 [跨项目] 的避雷条目。

## 通用抗体

- [AB-001] [UrhoX运行时] `cache:Exists` 只检查资源缓存；读取项目普通文件应使用 `fileSystem:FileExists` 与 `File(path, FILE_READ)`（素女篇 v0.1.0）。
- [AB-002] [UrhoX场景] 场景切换的白模节点必须挂到可移除的 `SceneRoot`，否则旧碰撞体和触发器会残留（素女篇 v0.1.0）。
- [AB-003] [验证] 无图形沙箱可能报告 shader cache、音频设备和默认字体错误；应单独核对 Lua runtime error、场景统计和截图（素女篇 v0.1.0）。
- [AB-004] [跨项目] [UrhoX UI] 持久 HUD（菜单/章节卡/存档）创建后，对话层禁止 `UI.SetRoot`；`SetRoot` 会整棵替换根节点。叠加层用 `AddChild`。视频会话恢复 HUD 时 `destroyOld` 必须为 false（素女篇 v0.3.5）。
- [AB-005] [跨项目] [UrhoX 天空盒] `UrhoXCLI convert-panorama` 产出老式 DDS（无 sRGB 标志），引擎按线性解读 → 直接当 Skybox 用过曝发白。修法：源图先做 sRGB→线性预补偿（PIL `point(lut)`）再转 DDS；运行时不要再 `SetSRGB`（双重解码变暗）。水平镜像拼接（img+flip）可消除全景接缝；接缝默认落 u=0/0.5，把 Skybox 节点绕 Y 转 90° 甩出水平 FOV（素女篇 D 阶段）。
- [AB-006] [跨项目] [Lua] Lua 模式 `%w` 不含下划线！匹配 `gu_nei_taolin` 这类带下划线参数要用 `[%w_]`，否则只截到 `gu`（素女篇 D 阶段截图参数解析）。
- [AB-007] [跨项目] [UrhoX UI] `backgroundImage` 在某些装配链路下不显示（children 属性传入/挂树前后 SetStyle 均试过无效）；稳妥三法：① 直接 child 挂 root + `AddChild` 后 `SetStyle`（章节卡 sceneBg_ 模式）；② 显式 `width/height="100%"` 子 Panel + 挂树后设图（art_ 模式）；③ 最稳：UI 层不设背景直接透出 3D 场景（Skybox 远景）。验证 UI 截图前先确认离屏环境**无中文字体**（NotoSansSC/MiSans 缺失 → 文本不渲染，按钮成纯色块），别误判布局。

- [AB-008] [跨项目] [UrhoX UI] 长文本回顾面板应挂持久 HUD Root，用 `UI.Modal` + `UI.ScrollView` 一次创建并通过 `Open/Close` 管理；不要用 `UI.SetRoot` 替换已有菜单/章节卡/对话层。离屏验证缺少 NotoSansSC/MiSans 时，不能仅凭纯色按钮截图判断中文文本是否正常。

- [AB-009] [跨项目] [UrhoX 存档] `FileSystem:CreateDir()` 返回 false 可能表示目录已存在，不能直接当作创建失败；保存前先用 `DirExists()`，仅在创建后目录仍不存在时失败，再打开相对存档路径。

- [AB-010] [跨项目] [UrhoX UI] 三选头像若要求位于底板右下，必须将 portrait 作为 `StoryPanel.Wrap()` 返回的 shell 子节点，再用 shell 内的百分比 `right/bottom` 定位；不要把 portrait 与 shell 作为全屏 panel 的同级子节点，否则百分比会相对屏幕定位。

## 同步记录

最近一次同步：2026-09-03 桃素洛无幽·素女篇
