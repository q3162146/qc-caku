# 历史交接草稿（勿用）

> ⚠️ 本目录存放的是**历史性、临时交接草稿**（发 TTM 的粘贴块 / 封面 / 已废弃的接入方案）。
> **不要**把它们当作当前规范或当前接入方法。当前唯一权威仓库为 `github.com/q3162146/qc-caku`(main)。

## 当前有效的接入/交接（在这个目录外面）
- **直推（现行，首选）**：`../TTM-共用仓库直推接入说明-方案B凭据.md`
  → TTM 用 repo 级 fine-grained PAT + `credential.helper store` 直接 `git push github main`。
- **降级（零凭据，备用）**：`../TTM-零凭据patch交接.md`
  → TTM 用 `git format-patch` 发 patch，用户 `git am` 合入。

## 本目录里已废弃 / 仅历史记录的
- `TTM-共用仓库直推接入说明.md` —— 走加协作者（方案 A），TTM 无 GitHub 账号，**已废弃**。
- `TTM-共用仓库直推接入说明-SSH部署密钥.md` —— TTM 环境无 `~/.ssh`，**已废弃**。
- 其余 `TTM-S6*封面*.md`、`TTM-*粘贴块.md`、`TTM-一页式交接.md`、`TTM-R*交付*.md` 等，均为**当时发给 TTM 的草稿/过程记录**，不是当前结论。

## 结论请以
- `docs/memory-index.md`（项目记忆索引，含各轮真机验证结论与决策）
- 以及上面「当前有效的接入/交接」两份为准。
