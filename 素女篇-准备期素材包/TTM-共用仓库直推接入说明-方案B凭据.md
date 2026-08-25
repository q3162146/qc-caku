# 发 TTM：共用仓库直推（HTTPS + 仓库级 PAT）—— 已确认可存凭据

> 用法：整段复制发给 TTM。已确认 TTM 环境 `credential.helper = store`，可持久化凭据。
> 让 TTM 用「单仓库写权限 的 fine-grained PAT」直接 push 到 `qc-caku` main，两边共用，免 zip。
> ⚠️ **PAT 值只由用户侧直接交给 TTM 环境（不经对话）**；这里只给存储与推送方法。

══════════════════════════════════════════════════════
【S6 之后 —— 请直推共用仓库（HTTPS + repo 级 PAT）】

背景：你无独立 GitHub 账号（无法被加成协作者），但你的环境可存 git 凭据（`credential.helper=store` 已确认）。用「单仓库写权限 的 fine-grained PAT」即可直推权威仓 `qc-caku` main。

## 第 1 步：拿到 PAT
用户已生成 **fine-grained PAT**（仅 `qc-caku`，`Repository permissions → Contents: Read and write`）。PAT 值由用户**直接**交给你环境（不经过对话）。你只需把它写入 git 凭据，见第 2 步。

## 第 2 步：配置 remote + 落凭据（非交互，直接写文件）
```bash
git remote add github https://github.com/q3162146/qc-caku.git
# 或已有则：git remote set-url github https://github.com/q3162146/qc-caku.git

git config --global credential.helper store
# 把下面这一行写入 ~/.git-credentials（一行，含你的 PAT；USERNAME 用 q3162146）：
#   https://q3162146:<你的PAT>@github.com
```
> 你环境非交互，无法等待输入提示，所以**直接把凭据写进 `~/.git-credentials`** 最稳。写完后可验证：`git config --global --get credential.helper` 应返回 `store`。

## 第 3 步：每次改完，推到 main
```bash
git add <你改动的文件>          # 只加业务代码
git commit -m "feat: ..."       # conventional commits + 中文说明
git push github main
```

## 约定（两边共同）
- **唯一权威仓** = `https://github.com/q3162146/qc-caku`（main）；**不要**推到 TapTap Maker 平台仓，避免两份历史分叉。
- 只提交 `scripts/` 业务代码 + 必要 docs；**别混入**录屏/截图/Spike 实验文档。
- 推送前 `git status`，别带上 `.tmp/.scratch/.adb-tools/logs/s1_test` 等垃圾。
- **PAT 不进对话**；只在你环境的 `~/.git-credentials`。若担心明文，可在你环境改用更有权限控制的凭据通道（如 macOS Keychain / Windows Credential Manager / 环境变量 + 自写 helper），但 `store` 已够用。

## 我（用户侧）拿到后
`git fetch github && git rebase github/main` → 有冲突我处理 → 改完再 push。两边同一条 `main`。

══════════════════════════════════════════════════════
