# Codex 通用代码核心 Skills 规范

## 1. 目标

维护一组跨语言、跨仓库、低重叠的代码工作 skills。每个 skill 必须同时满足：

1. **独立触发**：用户请求中存在可区分的工作状态，而不是“任何编码任务都可能有用”。
2. **高错误成本**：省略该流程会显著增加错误归因、行为回退、兼容性破坏、数据损失或错误授权风险。
3. **非默认知识**：说明 Codex 默认能力之外的重要顺序、证据或停止条件。
4. **可观察完成**：输出能由测试、diff、兼容矩阵、实验、规范或用户确认验证。
5. **跨项目复用**：不把单一仓库、平台或历史故障固化成通用入口。
6. **渐进披露**：发现信息短而精确，入口只保留共享约束，场景细节按需加载。
7. **授权守恒**：完成当前分析或本地验证不扩大外部写入、生产操作或破坏性动作权限。

普通读代码、实现、解释、运行测试、写文档、拆 ticket、全仓扫描和通用编排不单独设 skill。

## 2. 核心集合

| Skill | 正向触发 | 主要排除边界 | 必须留下的证据 |
| --- | --- | --- | --- |
| `grilling` | 当前用户持有的关键判断尚未闭合 | 可从仓库或工具发现的事实；普通澄清 | 决策依赖、已确认选择、剩余风险 |
| `codebase-design` | 选定模块的调用者契约、seam、依赖或信任边界未定 | 全仓架构扫描；已定设计的直接实现 | 推荐契约、备选比较、验证 seam |
| `tdd` | 已知行为明确要求 test-first，或已验证回归需锁定 | 根因或预期未知；纯结构重构 | 目标行为导致的 red、green 和相关检查 |
| `refactoring-safely` | 结构改变而调用者可见行为保持 | 行为变更；未知缺陷；跨版本迁移 | 保持不变量、绿色基线、分步证明 |
| `evolving-contracts` | 新旧 API、数据、配置、依赖或环境状态需要共存 | 纯内部重构；目标契约未定 | 兼容矩阵、阶段 gate、收缩条件和恢复路径 |
| `diagnosing-bugs` | 根因未知、偶发、环境相关或性能回退 | 已知行为的直接实现 | 复现、假设实验、因果或 profile 证据、不确定性 |
| `review-code-against-spec` | 固定变更集需要验收 | 开放式代码库评估；默认修复 | Standards 与 Spec 独立 findings 和覆盖缺口 |
| `resolving-merge-conflicts` | Git 已进入 merge/rebase 冲突状态 | 预防性合并分析；普通 Git 操作 | 双方意图、逐路径解析、状态与验证结果 |

集合保持 8 项。新增入口必须证明其证据逻辑不能由现有项的条件分支或 reference 清晰承载。

## 3. 边界与交接

```text
用户判断未闭合 -> grilling -> 共享理解

接口或信任边界未定 -> codebase-design -> 普通实现 / tdd
已知行为且 test-first -> tdd
结构变化且行为不变 -> refactoring-safely
公共形式或依赖版本变化 -> evolving-contracts

根因未知 -> diagnosing-bugs
已验证原因且获准修复 -> tdd / 普通实现
固定 diff 待验收 -> review-code-against-spec
Git 已报告冲突 -> resolving-merge-conflicts
```

关键区分：

- `tdd` 必须先红；`refactoring-safely` 必须先有可解释的绿色基线。
- `codebase-design` 决定目标契约；`evolving-contracts` 处理已定目标在新旧状态间的过渡。
- `diagnosing-bugs` 默认止于已验证原因；修复是另一个明确授权的阶段。
- `review-code-against-spec` 默认只报告，不把审查请求解释为修改授权。
- `resolving-merge-conflicts` 只在 Git 已有冲突状态时触发，并保护无关工作树内容。

## 4. 渐进披露与资源

每个 skill 由三层组成：

1. **名称与 description**：用于选择，保持简短、区分性强，并写出主要反例。
2. **`SKILL.md`**：共享目标、非显然流程、关键 guardrails、报告契约和按需路由。
3. **资源**：只有当前场景需要时才读取 reference 或执行 script。

资源必须满足：

- 从 `SKILL.md` 经相对链接直接或间接可达；
- 相对链接不能逃逸 skill 目录；
- 内容只有一个权威位置，不在多个入口重复；
- 脚本处理可重复且易错的机械逻辑，并有可运行的行为测试；
- 不创建辅助 README、变更日志、占位目录或未引用示例。

Windows GitHub 凭据上下文是 `diagnosing-bugs` 的条件分支，而不是全部技能的共享入口规则。CI/CD 规则只在当前任务确实设计、改变、诊断、审查或解析交付契约时启用。

## 5. 安全与停止条件

- 保留用户已有改动；不以 reset、全树暂存或无关清理制造“干净”状态。
- 读取状态与日志不等于授权 rerun、commit、push、PR、merge、批准或部署。
- 生产观测、负载、迁移、不可逆写入和破坏性恢复都需要与风险相称的明确授权和停止条件。
- 凭据留在所属存储中；不复制 token，不通过 ACL、所有权或全局 Git 配置让身份共享凭据。
- 重复同一动作而没有新证据不是进展。诊断和访谈流程应停止、重建回路或请求最小缺失输入。
- 预算耗尽、单次绿灯或静态推断不能冒充完成证据。

## 6. 验收案例

| 请求 | 预期 |
| --- | --- |
| “逐轮挑战这个缓存方案中还没决定的取舍” | `grilling` |
| “这个事实能从仓库查到，帮我确认” | 不触发 `grilling`；直接调查 |
| “比较支付模块的两个公共接口，并分析租户越权边界” | `codebase-design` |
| “接口已经定了，直接实现这个小改动” | 默认能力；不触发 `codebase-design` |
| “行为已确定，用 TDD 实现” | `tdd` |
| “内部重命名，公开行为必须不变” | `refactoring-safely` |
| “公共字段改名，旧客户端还要运行两版” | `evolving-contracts` |
| “偶发超时，根因不清楚” | `diagnosing-bugs` |
| “已知慢查询，把 p95 从 800ms 降到 300ms” | `diagnosing-bugs` 的性能分支 |
| “按 AGENTS.md 和原始 spec 审查这个 diff” | `review-code-against-spec` |
| “rebase 已卡在冲突，保留双方意图并继续” | `resolving-merge-conflicts` |
| “沙箱和普通终端的 GitHub 认证结果不同” | `diagnosing-bugs` 的 Windows 凭据 reference |
| “实现这个明确的小改动” | 不触发 skill，使用默认能力 |

## 7. 仓库验收

- 恰有上述 8 个 skill，目录名、frontmatter、UI 元数据和 README 一致。
- 所有相对链接有效且不逃逸作用域；孤立资源、模板标记和未安装 skill 调用为 0。
- 每个入口保留其区分性语义：触发状态、核心证据、停止或交接边界。
- PowerShell 脚本语法有效，文本为严格 UTF-8，CI 外部 action 固定到完整提交 SHA，并使用只读权限。
- 仓库验证器、验证器负向行为测试、Windows GitHub 探针行为测试、系统 `quick_validate.py` 与 `git diff --check` 全部通过。
- 修改完成后检查工作树范围，在独立 `codex/` 分支创建说明意图的原子提交；push 保持为单独授权动作。
