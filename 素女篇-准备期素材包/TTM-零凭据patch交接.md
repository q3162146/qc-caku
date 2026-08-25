# 发 TTM：零凭据交接（git format-patch，改用 patch 合入）

> 用法：整段复制发给 TTM。若 TTM 环境无法向 GitHub 认证（无账号/无 SSH/无法存 token），
> 就用这个「零凭据」方案：TTM 把改动导出成 patch 文件发你，你在 qc-caku 上 `git am` 合入。
> 全程不需要任何 GitHub 凭据，也不需要 SSH。

══════════════════════════════════════════════════════
【S6 之后 —— 请用 git patch 交接（零凭据，避免 zip/手动合并）】

背景：你当下环境无法向 GitHub 认证（无账号、无 SSH、无 token），推不了共用仓库。这条最稳：你只导出「改动补丁」，我这边合入 qc-caku，两边仍是「q3162146/qc-caku(权威) + 本地应用」一条历史，不产生第二份副本。

## 你要做的（每次改完）
1. 确认你的提交号：`git log --oneline -5`
2. 把「s6 相关」的提交导出为 patch 文件：
   ```bash
   git format-patch -1 <最新提交号>                 # 单个提交
   # 或导出最近一段： git format-patch <起点>..<终点>
   git diff <起点>..<终点> > s6-change.diff          # 或直接 diff
   ```
3. **只发 patch/diff 文本**（或 .patch/.diff 文件），**不发**：录屏/截图/Spike 文档/`.tmp`/`.scratch` 等。
4. 如有新增文件（如 `scripts/media/MediaPlayer.lua`），`git format-patch` 会自动带进来；补丁里会含 `new file mode`。

## 我（用户侧）拿到后
```bash
git am 0001-*.patch        # 或 git apply s6-change.diff
# 若 patch 因上下文漂移失败，我本地手调后提交
```
然后 `git push github main` 回推 qc-caku。

## 何时/多久走一次
- 每次 TTM 完成一段改动 → 导出一个 patch → 发我 → 我 `git am` + push。量小、无认证、无分叉。
- 若哪天 TTM 环境能配好 PAT（能持久化 token），再升级为「直推共用仓库」，这条 patch 交接可停用。

══════════════════════════════════════════════════════
