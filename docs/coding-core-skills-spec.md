# Codex 通用代码核心 Skills 规范

状态：第三轮精简，已实施并验证
日期：2026-08-12
参考源：`D:\quality_tests_skills` 与现有工作区

## 1. 目标

维护一组跨语言、跨仓库、低重叠的代码工作 skill。只覆盖 Codex 默认能力在高风险节点容易失稳的流程，不包装普通读代码、实现、解释或运行测试。

核心集合共 8 个：

| Skill | 守住的决策点 | 不可替代的证据或顺序 |
| --- | --- | --- |
| `grilling` | 重要决策尚未闭合 | 只问不可发现的判断，按依赖前沿分轮收敛 |
| `codebase-design` | 接口、依赖或安全边界未定 | 先确定调用者契约、信任边界与验证 seam |
| `tdd` | 已知行为需要 test-first 实现 | 必须留下因目标行为缺失而失败的 red 证据 |
| `refactoring-safely` | 结构要变、外部行为不应变 | 先固定不变量和绿色基线，再小步证明保持行为 |
| `evolving-contracts` | 契约、数据或外部依赖版本变化 | 权威版本证据、混合态验证和有界迁移 |
| `diagnosing-bugs` | 根因未知或性能指标需改善 | 可重复反馈回路、可证伪假设、profile 与单变量实验 |
| `review-code-against-spec` | 固定 diff 待验收 | Standards 与 Spec 两个独立审查轴 |
| `resolving-merge-conflicts` | merge/rebase 已出现冲突 | 重建双方意图、逐路径暂存并保护无关改动 |

## 2. 第一性原理筛选

一个 skill 必须同时满足：独立触发、高错误成本、跨项目复用、提供非默认程序知识、有明确完成证据和停止条件、上下文最小、授权安全。

合并依据：

- 威胁建模并入 `codebase-design`：二者都在设计落定前推导接口不变量和测试 seam，安全内容按需读取。
- 性能优化并入 `diagnosing-bugs`：二者都依赖可重复基线、profile、可证伪假设和单变量实验；区别只在是否已知 workload 与目标。
- 依赖升级并入 `evolving-contracts`：依赖版本也是外部契约，核心都是版本证据、兼容矩阵、有界迁移和混合状态验证。

仍保持分离：

- `tdd` 要先红，`refactoring-safely` 要保持绿，证据逻辑相反。
- `review-code-against-spec` 默认不修改代码，不能并入实现流程。
- `resolving-merge-conflicts` 有独立 Git 状态和高破坏风险。
- `grilling` 处理用户持有的未决判断，`codebase-design` 处理可从证据推导的技术设计。

## 3. 不纳入

普通实现、元路由、通用 research、写 spec、拆 ticket、triage、handoff、全仓架构扫描、原型、发布门禁、测试总管、可观测性/文档/CI 通用包装均不设独立 skill。它们属于默认能力、组织流程或仅应作为具体任务的证据手段。

## 4. 边界与交接

```text
决策未闭合 ──> grilling ──> 共享理解

接口/依赖/安全边界未定 ──> codebase-design ──> 普通实现 / tdd
新行为且 test-first ──> tdd
结构变化且行为不变 ──> refactoring-safely
公共形式、数据或依赖版本变化 ──> evolving-contracts ──> tdd slices

根因未知 ──> diagnosing-bugs ──> 已验证原因且获准修复 ──> tdd / 普通实现
已有 workload 与性能目标 ──> diagnosing-bugs 的性能分支

固定 diff 待验收 ──> review-code-against-spec
merge/rebase 冲突中 ──> resolving-merge-conflicts
```

硬边界：

- `grilling` 不询问可从仓库或工具发现的事实，也不隐式开始实现。
- `codebase-design` 只设计已选模块；安全模型中的未批准风险不是 Spec 要求。
- `tdd` 只处理已知行为或已验证回归；纯重构不能伪造 red。
- `refactoring-safely` 不接受未批准的行为变化，也不撤回既有用户改动。
- `evolving-contracts` 不把部署顺序当兼容证明，不把应用回滚当数据回滚，也不把 manifest 约束当最终解析图。
- `diagnosing-bugs` 默认止于验证原因；性能实验必须有代表性基线，生产负载需单独授权。
- `review-code-against-spec` 默认只报 findings。
- `resolving-merge-conflicts` 仅在 Git 已报告冲突时使用，只暂存已解决路径。

## 5. 内容与元数据约束

- `SKILL.md` frontmatter 仅含 `name` 和 `description`；description 写清触发与排除边界；正文不超过本地 100 行预算。
- `agents/openai.yaml` 包含带引号的 `display_name`、25–64 字符 `short_description` 和显式提及 `$skill-name` 的 `default_prompt`。
- 细节只在能降低主入口上下文时放入一层 `references/`，且必须由 `SKILL.md` 直接链接。
- 不创建辅助 README、变更日志、安装说明或未引用资源。

## 6. 验收案例

| 请求 | 预期 |
| --- | --- |
| “逐轮挑战这个缓存设计里的未决选择” | `grilling` |
| “设计支付接口，并分析租户越权路径” | `codebase-design` |
| “行为已确定，用 TDD 实现” | `tdd` |
| “内部重命名，公开行为必须不变” | `refactoring-safely` |
| “公共字段改名，旧客户端还要运行两版” | `evolving-contracts` |
| “按官方指南升级框架两个 major” | `evolving-contracts` |
| “偶发超时，根因不清楚” | `diagnosing-bugs` 的诊断分支 |
| “已复现查询从 p95 800ms 优化到 300ms” | `diagnosing-bugs` 的性能分支 |
| “慢接口尚未复现或建立基线” | 仍先进入诊断分支 |
| “按 AGENTS.md 和原始 spec 审查 diff” | `review-code-against-spec` |
| “rebase 卡在冲突，保留双方意图并继续” | `resolving-merge-conflicts` |
| “实现这个明确的小改动” | 不触发 skill，使用默认能力 |

## 7. 完成标准

- 工作区恰有上述 8 个 skill，目录、frontmatter、元数据和 README 同步。
- 相对链接、孤立资源、模板标记和未安装 skill 调用为 0。
- 仓库验证器与系统 `quick_validate.py` 全部通过。
- 高重叠边界有正例、反例或交接案例；复杂合并点做代表性前向检查。

## 8. 本轮实施

从 11 项压缩到 8 项：删除 `threat-modeling`、`optimizing-performance`、`upgrading-dependencies` 独立入口，关键规则分别下沉到 `codebase-design`、`diagnosing-bugs`、`evolving-contracts` 的按需 reference。没有删除关键安全、测量或兼容约束，也没有增加元路由层。

最终验证结果：仓库验证器与系统 `quick_validate.py` 均为 8/8 通过，`git diff --check` 通过；设计/安全、故障/性能、契约/依赖三组合并点的独立前向检查均能正确选择分支、保留授权边界并产出所需证据。
