# codex_vibe_skills

面向日常代码工作的精简 Codex Skills 集合。该集合只保留高错误成本、跨项目复用且具有明确触发边界的流程，不包装 Codex 已具备的普通实现能力。

## Skills

| Skill | 用途 |
| --- | --- |
| `grilling` | 在实现前逐轮压力测试尚未闭合的计划、设计和关键决策 |
| `codebase-design` | 设计模块接口、依赖方向与安全敏感信任边界 |
| `tdd` | 对已知行为或已验证修复执行 red-green-refactor |
| `refactoring-safely` | 用明确不变量、绿色基线和小步验证证明重构不改变行为 |
| `evolving-contracts` | 安全演进 API、数据、schema、依赖和运行时版本 |
| `diagnosing-bugs` | 诊断未知根因并优化已有基线的性能瓶颈 |
| `review-code-against-spec` | 从仓库规范与原始 spec 两个独立轴审查固定 diff |
| `resolving-merge-conflicts` | 基于双方意图安全处理进行中的 merge/rebase 冲突 |

## 设计与验证

- [设计规范](docs/coding-core-skills-spec.md)
- Windows 校验：

  ```powershell
  powershell -NoProfile -ExecutionPolicy Bypass -File scripts/Test-CoreSkills.ps1
  ```

每个技能包含最小 `SKILL.md`、桌面端 UI 元数据 `agents/openai.yaml`，以及仅在需要时加载的 `references/`。

## 安装

将需要的完整技能目录复制到 Codex 的用户 skills 目录。不要只复制 `SKILL.md`；`agents/` 和 `references/` 属于技能的一部分。

Codex 通常会自动发现技能变更；若桌面端技能选择器未刷新，请重启 Codex。

## 来源与许可

本集合从 `quality_tests_skills` 的工程技能中选择性改写，并按更小的通用代码工作边界重新设计；新增技能则从开发闭环中的高风险空白独立推导。遵循仓库根目录的 MIT License。
