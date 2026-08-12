# Codex 通用代码核心 Skills 规范

状态：第四轮 Git/CI/CD 场景同步，已实施并验证
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

### 4.1 Git 与 CI/CD 场景映射

Git/CI/CD 不新增元路由 skill，而是沿现有证据逻辑分布。仅当仓库存在相关 workflow、required checks、制品或部署契约，且当前任务会读取、影响或改变它们时启用；否则保持原 skill 的基础证据链。

| 场景 | 归属 | 完成证据与授权边界 |
| --- | --- | --- |
| 发布策略、风险接受、上线时机未定 | `grilling` | 先读取分支、PR、required checks、环境和部署状态；只询问不可发现的业务判断 |
| 设计或重构发布流水线 | `codebase-design` | 触发器、最小权限、凭据/secret、fork 制品晋级、环境、并发、回滚与验证 seam |
| 已知行为的 test-first 实现 | `tdd` | 本地 red/green 与 CI job 映射；CI-only 失败不能替代第一条 red |
| 保持行为的内部重构 | `refactoring-safely` | required checks 与本地等价命令保持；门禁变更移交 `evolving-contracts` |
| action、runner、权限、缓存、制品或部署接口演进 | `evolving-contracts` | 固定版本与兼容矩阵、不可变 action revision、required-check 名称、混合态和恢复证据 |
| CI/CD 失败根因未知 | `diagnosing-bugs` | 固定 workflow/run/attempt/head SHA/event/job/runner；日志脱敏并做单变量实验 |
| 固定 diff 或 PR 待验收 | `review-code-against-spec` | workflow、脚本、权限、action SHA 和属于固定 head SHA 的检查结果进入 coverage map |
| merge/rebase 中 workflow 冲突 | `resolving-merge-conflicts` | 重建两侧触发器、权限、表达式、环境和 required-check 语义；解析后旧检查失效 |

共享不变量：读取状态和日志默认只读；commit、push、PR 创建、检查 rerun/cancel、merge、环境批准和 deploy 是独立副作用，不能互相推导授权。绿色 CI 只证明已执行的提交、事件和矩阵单元，不证明 Spec 完整、未执行环境安全或部署获批。

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
- `agents/openai.yaml` 仅含 `interface` 下带引号的 `display_name`、25–64 字符 `short_description` 和显式提及 `$skill-name` 的 `default_prompt`，不接受重复键或额外字段。
- 细节只在能降低主入口上下文时放入一层 `references/`，且必须由 `SKILL.md` 直接链接。
- README、规范和 skill 文档中的仓库内相对链接必须存在且不得逃逸仓库根目录。
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
| “设计允许 fork PR、产出制品并经批准部署的最小权限 Actions 流水线” | `codebase-design`；设计不隐含实施或部署授权 |
| “升级 runner 和 action，同时保持旧分支 required checks 可用” | `evolving-contracts`；验证新旧工作流混合态 |
| “同一提交只在 windows-latest 失败，原因未知” | `diagnosing-bugs`；固定 run/attempt/head SHA 后诊断 |
| “PR 检查全绿，核实 workflow 权限和验收条件是否完整” | `review-code-against-spec`；绿色结果仅作支持证据 |
| “workflow 冲突已解决，直接沿用冲突前的绿灯结果” | 拒绝；`resolving-merge-conflicts` 应把旧检查视为失效 |
| “实现这个明确的小改动” | 不触发 skill，使用默认能力 |

## 7. 完成标准

- 工作区恰有上述 8 个 skill，目录、frontmatter、元数据和 README 同步。
- 相对链接、孤立资源、模板标记和未安装 skill 调用为 0。
- 仓库验证器、校验器负向行为测试与系统 `quick_validate.py` 全部通过。
- GitHub Actions 在 push、pull request 和手动触发时以只读仓库权限运行两层仓库自检。
- 高重叠边界有正例、反例或交接案例；复杂合并点做代表性前向检查。

## 8. 本轮实施

从 11 项压缩到 8 项：删除 `threat-modeling`、`optimizing-performance`、`upgrading-dependencies` 独立入口，关键规则分别下沉到 `codebase-design`、`diagnosing-bugs`、`evolving-contracts` 的按需 reference。没有删除关键安全、测量或兼容约束，也没有增加元路由层。

第四轮把 Git 管理与 CI/CD 作为横切证据同步到全部 8 项：设计与契约 skill 管理流水线边界和兼容性，诊断与审查 skill 固定远端证据，TDD 与重构 skill 对齐本地验证和 required checks，冲突 skill 使旧检查失效，`grilling` 只收敛不可发现的发布判断。所有远端写操作继续保持独立授权。

最终验证结果：仓库验证器与系统 `quick_validate.py` 均为 8/8 通过，`git diff --check` 通过；设计/安全、故障/性能、契约/依赖三组合并点，以及 Git/CI/CD 条件触发的独立前向检查，均能正确选择分支、保留授权边界并产出所需证据。普通模块设计、TDD、重构、代码审查和非 workflow 冲突不会被迫追加 CI/CD 工作。
