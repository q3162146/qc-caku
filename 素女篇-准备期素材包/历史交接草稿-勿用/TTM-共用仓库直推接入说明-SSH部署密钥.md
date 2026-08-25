# 发 TTM：共用仓库直推（SSH 部署密钥）

> 用法：整段复制发给 TTM。让 TTM 用「仓库级 SSH 部署密钥」直接 push 到 `qc-caku`，两边共用 main，免 zip。
> ⚠️ 部署密钥只对单个仓库有效、可给写权限、无需 TTM 有 GitHub 账号。私钥始终留在 TTM 机器上，**不经对话**。

══════════════════════════════════════════════════════
【S6 之后 —— 请用 SSH 部署密钥直接推共用仓库】

背景：你无独立 GitHub 账号（无法被加成协作者），改用「单仓库 SSH 部署密钥 + 写权限」。你改完直接 push 到权威仓 `qc-caku` main，我这边 fetch/rebase 即同步，两边不分叉。

## 第 1 步：你生成 SSH 密钥对（在你自己机器上）
```bash
ssh-keygen -t ed25519 -C "ttm-qc-caku" -f ~/.ssh/qc_caku_push
# 公钥在 ~/.ssh/qc_caku_push.pub
```
**私钥留在你机器上，不要发给任何人（包括对话）**。把**公钥内容**（`qc_caku_push.pub` 的整行）发给用户侧，由用户把它加到 `qc-caku` 的 **Deploy keys**（勾选 **Allow write access**）。

## 第 2 步：配置 remote（SSH）
```bash
git remote add github git@github.com:q3162146/qc-caku.git
# 或已有则：git remote set-url github git@github.com:q3162146/qc-caku.git
# 让 SSH 用这把私钥：
ssh-add ~/.ssh/qc_caku_push   # 或用 ssh -i ~/.ssh/qc_caku_push 走 SSH_AUTH_SOCK
# 首次连接需接受 host key：ssh -T git@github.com （会显示 "Hi ... You've successfully authenticated"）
```

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
- **私钥/口令不进对话**，只在你机器上。

## 我（用户侧）拿到后
`git fetch github && git rebase github/main` → 有冲突我处理 → 改完再 push。两边同一条 `main`。

══════════════════════════════════════════════════════
