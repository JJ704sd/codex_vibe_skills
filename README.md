# codex_vibe_skills

面向日常代码工作的精简 Codex Skills 集合。这里不包装普通读代码、实现或运行测试能力，只保留满足以下条件的工作流：触发边界独立、出错代价高、跨项目复用、能提供非默认程序知识，并且有可观察的完成证据。

## Skills

| Skill | 何时使用 | 核心证据 |
| --- | --- | --- |
| `grilling` | 计划、设计或关键决策仍有只能由当前用户判断的缺口 | 依赖感知的决策图与逐轮确认 |
| `codebase-design` | 局部模块的接口、seam、依赖方向或信任边界未定 | 调用者契约、替代方案与验证 seam |
| `tdd` | 已知行为或已验证回归需要 test-first 实现 | 因目标行为缺失而失败的 red，以及后续 green |
| `refactoring-safely` | 内部结构要变，调用者可见行为必须保持 | 绿色基线、保持不变量和分步证据 |
| `evolving-contracts` | API、数据、配置或依赖版本需要跨混合状态迁移 | 兼容矩阵、阶段 gate 与恢复路径 |
| `diagnosing-bugs` | 根因未知、行为偶发或性能回退需要实证诊断 | 可重复反馈回路、可证伪假设和单变量实验 |
| `review-code-against-spec` | 固定 diff 需要按仓库规范和原始 spec 验收 | Standards 与 Spec 两个独立审查轴 |
| `resolving-merge-conflicts` | Git 已报告 merge/rebase 冲突 | 双方意图、逐路径暂存与冲突后验证 |

[核心设计规范](docs/coding-core-skills-spec.md)定义了选择原则、边界和验收案例。

## 设计约束

- 名称与 description 负责低成本发现，必须同时说明正向触发和主要排除边界。
- `SKILL.md` 只保留改变决策的通用流程；特定场景细节放在按需加载的 `references/`。
- 可重复、易写错的机械操作才进入 `scripts/`，并必须有行为测试。
- 每个资源都必须从入口可达，且 skill 不能依赖自身目录之外的文件。
- 普通实现继续使用 Codex 默认能力；不新增元路由、通用编排或“万能工程” skill。
- 讨论、设计、诊断和绿色测试不自动授权 commit、push、PR、merge、部署或生产变更。

## 验证

在 Windows PowerShell 中运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/Test-CoreSkills.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/Test-CoreSkills.Validator.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/Test-WindowsGitHubAuthContext.Validator.ps1
```

第一项检查结构、元数据、链接、资源可达性、核心语义不变量、UTF-8、PowerShell 语法和 CI 安全约束；第二项用负向 fixture 验证校验器确实能拒绝坏输入；第三项验证 Windows GitHub 上下文探针的仓库前置检查与脱敏行为。GitHub Actions 会在 push、pull request 和手动触发时以只读仓库权限运行三项检查。

系统 `skill-creator` 的 `quick_validate.py` 也应对 8 个目录逐一通过。Windows 中文区域设置下使用 `python -X utf8`，避免系统 ANSI 编码误读 UTF-8 文件。

## 安装

复制所需的完整 skill 目录到 Codex 用户 skills 目录。不要只复制 `SKILL.md`；`agents/` 以及存在的 `references/`、`scripts/` 或 `assets/` 都属于 skill 的自包含契约。

## 来源与许可

本集合从 `quality_tests_skills` 的工程技能中选择性改写，并按更小的通用代码工作边界重新设计。遵循仓库根目录的 MIT License。
