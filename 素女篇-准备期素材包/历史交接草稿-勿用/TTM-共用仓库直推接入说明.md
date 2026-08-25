# 发 TTM：改用共用仓库直推（不再打 zip）

> 用法：整段复制发给 TTM。让 TTM 直接把代码 push 到权威仓库 `qc-caku`，两边共用一份，从此免 zip / 免手动合并。

══════════════════════════════════════════════════════
【S6 之后 —— 请直接推共用仓库（单仓直同步）】

背景（一句话）：目前代码靠「打 zip → 传 → 本地手动合并 → 回推」往返两次，太慢。现把权威仓 `qc-caku` 作为**唯一共用仓库**，你改完直接 push，我这边 fetch/rebase 即有，两边不再分叉。

## 你要做的
1. **确认你的 GitHub 账号**已作为 `q3162146/qc-caku` 的协作者（Write 权限）被加入。
2. 在你机器上配置 remote（已配过可跳过）：
   ```bash
   git remote add github https://github.com/q3162146/qc-caku.git
   # 或已有则：git remote set-url github https://github.com/q3162146/qc-caku.git
   ```
3. **每次改完**，推回 `main`：
   ```bash
   git add <你改动的文件>          # 只加业务代码，别加 .tmp/.scratch/截图/录屏/Spike 文档
   git commit -m "feat: ..."       # conventional commits：feat/fix/chore + 中文说明
   git push github main
   ```
4. 若你环境无凭据：用**你被加成协作者的那个 GitHub 账号**登录（或为它配一个 repo 范围 `Contents: Read and write` 的 PAT，只放你环境自己的 credential store，**不要发到对话里**）。

## 约定（两边共同遵守）
- **唯一权威仓** = `https://github.com/q3162146/qc-caku`（分支 `main`）；**不要**把权威内容推到 TapTap Maker 平台仓（`maker.taptap.cn`），避免两份历史再次分叉。
- 改动只提交 `scripts/` 业务代码 + 必要的 docs；**别混入**录屏/截图/Spike 实验文档。
- 提交说明用 `feat/fix/chore` + 中文一句话。
- 推送前先 `git status`，确认没带上 `.tmp/.scratch/.adb-tools/logs/s1_test` 等垃圾。

## 我（用户侧）拿到后
`git fetch github && git rebase github/main` → 有冲突我处理 → 改完再 push。两边从此都是同一条 `main`。

══════════════════════════════════════════════════════
