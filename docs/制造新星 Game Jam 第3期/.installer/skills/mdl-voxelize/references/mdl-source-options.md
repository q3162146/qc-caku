# 获取 MDL 输入

当用户还没有本地 `.mdl` 和贴图路径时，读取本参考。

## 搜索已有资产

如果 UrhoX SCE MCP 工具可用，使用 `search_game_resource` 工具。源码位置：

```text
C:\Workspace\TapMaker\sce-tools\packages\mcp-sce-urhox\src\tools\search-3d-resource.ts
```

当用户需要已有 prefab、道具、角色、场景物体或动画时使用它。返回结果通常包含 prefab UUID 和 prefab XML。Prefab XML 里可能有类似引用：

```text
Model;Models/Enemy.mdl
Material;Materials/Enemy.xml
```

要进行体素化，必须确保目标资产树里存在引用到的 `.mdl`、材质文件、diffuse 贴图以及相关 `.meta` 文件。

## Tripo 模型生成

如果没有合适的现有资产，使用 Tripo MCP 工具。源码位置：

```text
C:\Workspace\TapMaker\sce-tools\packages\mcp-sce-urhox\src\tools\tripo3d-model.ts
```

相关工具名：

- `create_3d_model_task`：创建 text-to-model、image-to-model 或 multiview-to-model 任务。
- `query_3d_model_task`：当初始结果要求后续查询时，用 task_id 轮询任务。

重要流程：

- `text_to_model` 和 `image_to_model` 是两阶段流程。第一阶段返回预览图路径；用户明确确认这些视图前，不要提交第二阶段。
- `multiview_to_model` 可以直接提交开发者提供的多视图图片。
- `rig=true` 只适用于姿态合适的双足人形角色。
- 成功结果可能包含本地 workspace model path 或 CDN model URL。如果结果还不是 `.mdl`，需要先导入/转换成 UrhoX 运行时资产，再使用本 skill。

## 直接 UUID 解析输入

launcher 可以按 UUID 解析本地资产，并继续使用 `config.json`、默认输出目录和生产参数：

```bash
cd <tapmaker_project>
sh <skill>/scripts/run_voxelize.sh \
  --prefab-uuid <uuid> \
  --asset-root assets
```

普通生产流程优先使用 launcher，因为 launcher 会补齐所有生产参数。只有当输入是 UUID，并且完整本地资产树已经存在时，才使用 UUID 解析模式。默认从当前项目根解析 `assets`；不要为了常规调用额外传项目根参数。
