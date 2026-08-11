# Codex 通用代码核心 Skills 规范

状态：已实施并验证
日期：2026-08-11
参考源：`D:\quality_tests_skills`
目标安装位置：`C:\Users\Administrator\.codex\skills`

## 1. 目标

从参考库中提炼一组跨语言、跨仓库、低重叠的代码工作技能。技能只覆盖 Codex 默认能力容易在高风险节点失稳的流程，不包装普通读代码、改代码、运行测试或解释代码等默认能力。最终技能必须能被 Codex 桌面端发现，并以“个人”技能出现在技能选择器中。

最终仅保留六个技能：

| 技能 | 守住的核心决策点 | 主要价值 |
| --- | --- | --- |
| `grilling` | 方案、计划或关键决策尚未闭合 | 用依赖化问题轮次暴露隐含假设，在编码前收敛决策 |
| `codebase-design` | 接口、边界和 seam 尚未定型 | 在写代码前缩小公共接口，明确约束、错误和依赖方向 |
| `tdd` | 行为或已验证修复已知，用户要求 test-first | 强制经过可观察行为的 red-green-refactor 证据链 |
| `diagnosing-bugs` | 根因未知、难复现、flaky 或性能回归 | 先建立可重复反馈回路，再验证可证伪假设 |
| `review-code-against-spec` | 需要判断一个固定 diff 是否合规且完整 | 将仓库规范与产品/spec 完整性分成两个独立审查轴 |
| `resolving-merge-conflicts` | Git merge/rebase 已出现未解决冲突 | 基于双方意图安全消解冲突，并保护无关工作树改动 |

## 2. 第一性原理筛选标准

一个技能必须同时满足：

1. **独立触发**：用户意图可以清楚地区分，不能只是“帮我实现”的别名。
2. **高错误成本**：省略其流程会显著增加误修、错误抽象、漏验收或破坏工作树的风险。
3. **跨项目复用**：不依赖特定 tracker、组织角色、语言、框架或部署平台。
4. **新增程序知识**：提供 Codex 默认推理之外的硬边界、证据要求或操作顺序。
5. **低重叠**：相邻技能必须有可说明的入口和交接条件。
6. **最小上下文**：`SKILL.md` 只包含每次触发都需要的流程；细节按需放入一层 `references/`。
7. **授权安全**：诊断不自动变成修复，审查不自动变成改代码，冲突解决不扫入无关改动。

## 3. 不纳入范围

| 参考库能力 | 结论 | 原因 |
| --- | --- | --- |
| 普通实现、重新解释、技能写作包装 | 不纳入 | Codex 默认能力或系统 `skill-creator` 已覆盖 |
| `configure-engineering-skills`、`route-engineering-work` | 不纳入 | 增加元编排层；六个技能已有清晰独立触发 |
| `research`、`domain-modeling` | 不纳入 | 通用调研由现有工具规则覆盖；领域建模不是每个代码任务的核心入口 |
| `to-questionnaire`、`wayfinder` | 不纳入 | 属于异步知识收集或跨会话路线发现，不是直接代码工作闭环 |
| `to-spec`、`to-tickets`、`triage` | 不纳入 | 偏 tracker 和工作管理；本规范本身只作为本次实施的规格，不新增常驻包装 |
| `review-codebase-architecture` | 不纳入 | 全仓扫描与可视报告是低频专项；已选模块的设计由 `codebase-design` 覆盖 |
| `prototype` | 不纳入 | 是探索性专项，不属于稳定代码修改闭环 |
| 五个测试/评测/发布治理技能 | 不纳入 | 依赖组织门禁、批准阈值和发布决策权，不适合作为个人通用代码技能 |
| `handoff`、`wizard`、`run-learning-workspace` | 不纳入 | 属于协作、人工配置或学习工作流 |

`resolving-merge-conflicts` 虽低频，但一旦触发就具有明确 Git 状态、较高破坏风险和不可由普通实现流程替代的安全约束，因此保留。

## 4. 技能边界与交接

```text
方案或关键决策未闭合 ──> grilling ──> 共享理解

接口/边界未定 ──> codebase-design
                      │
行为已知且要求 test-first ──> tdd

根因未知 ──> diagnosing-bugs ──验证根因且获准修复──> tdd

固定 diff 待验收 ──> review-code-against-spec

merge/rebase 冲突中 ──> resolving-merge-conflicts
```

硬边界：

- `grilling` 只询问不可从代码、文档或工具发现的真实决策；决策前沿清空且共享理解确认后停止，不隐式开始实现。
- `diagnosing-bugs` 默认停在已验证根因和最小修复建议；只有用户明确要求修复才进入实现。
- `tdd` 只处理已知行为或已验证回归；根因未知时退回诊断。
- `codebase-design` 只设计已选模块，不扩张为全仓架构审计。
- `review-code-against-spec` 默认只报告 findings；除非用户另行要求，不修改代码。
- `resolving-merge-conflicts` 仅在 Git 已报告冲突时使用，只暂存明确解决的路径。

## 5. 针对参考技能的调整

### 5.1 `grilling`

- 保留 decision tree、decision frontier 和按依赖分轮提问。
- 每个真正决策都给出推荐项和简短理由；可发现事实由 Codex 自行调查，不转嫁给用户。
- 删除对未安装 `domain-modeling`、`to-questionnaire` 的调用依赖；用户明确要求时，可把已确认结论写入其指定文档。
- 当前沿为空且用户确认共享理解时结束，不把访谈隐式延伸为实现。

### 5.2 `codebase-design`

- 保留深模块、接口即测试面、依赖分类、真实 seam 和 design-it-twice。
- 删除对未安装 `review-codebase-architecture` 的调用依赖。
- 将特定 `CONTEXT.md` 假设改为读取仓库实际存在的 instructions、spec 和 ADR。
- 将“并行子代理”改为可选的独立设计轮次，不把运行时编排写成硬要求。

### 5.3 `tdd`

- 保留公共 seam 上的一次一个纵向行为和 red-green-refactor。
- 明确首次红灯必须因目标行为缺失而失败，避免环境错误造成伪红。
- 保留独立期望值、真实本地替身和最小到全量的验证梯度。
- 仓库文档发现采用通用路径，不假设存在 `CONTEXT.md`。

### 5.4 `diagnosing-bugs`

- 保留最小反馈回路、复现率、可证伪假设、单变量实验和原始场景回归。
- 保留诊断与修复的授权分离。
- 删除 Bash 人工循环模板；人工步骤直接使用结构化说明，避免为罕见分支引入平台依赖。
- 将后续架构建议指向已安装的 `codebase-design`。

### 5.5 `review-code-against-spec`

- 保留 Standards 与 Spec 两轴独立结论，不用一轴掩盖另一轴。
- 修正比较面：区分分支/PR 的 merge-base diff、单提交 diff、工作树 diff，并显式发现未跟踪文件。
- 规范来源包括就近 `AGENTS.md`、贡献指南、代码规范和项目配置；spec 缺失时只运行 Standards 轴。
- 只报告本次 diff 引入的问题，给出紧凑文件/行证据和最小可执行修正。

### 5.6 `resolving-merge-conflicts`

- 保留双方意图追溯、显式路径暂存、逐提交 rebase 和最小验证。
- 不自动 `--abort`、不全量 `git add`、不创建额外 commit、不 push。
- 继续操作只限于用户已授权完成当前 merge/rebase 的情形。

## 6. 目录与元数据

工作区先生成可审查源文件：

```text
D:\codx_vibe_skills\skills\
  grilling\
  codebase-design\
  diagnosing-bugs\
  resolving-merge-conflicts\
  review-code-against-spec\
  tdd\
```

每个目录包含：

- `SKILL.md`：frontmatter 仅有 `name` 与 `description`；正文使用指令式表达。
- `agents/openai.yaml`：只含 `display_name`、`short_description`、显式提及 `$skill-name` 的 `default_prompt`。
- `references/`：仅在按需读取能降低主入口上下文时创建；所有资源必须从 `SKILL.md` 一层直达。

完成工作区校验后，将六个完整目录安装到 `C:\Users\Administrator\.codex\skills\<skill-name>`。不修改 `.system` 技能。

## 7. 实施顺序

1. 使用系统 `skill-creator/scripts/init_skill.py` 初始化六个目录。
2. 先实现资源文件，再编写最小 `SKILL.md`。
3. 生成并核对 `agents/openai.yaml`。
4. 运行 `quick_validate.py`；若其运行时依赖缺失，则记录阻断并运行覆盖同等规则的本地校验器。
5. 检查相对链接、未引用资源、旧技能调用和目录名称一致性。
6. 将校验通过的目录安装到 Codex 通用 skills 位置。
7. 对已安装副本再次运行相同校验，并比较源目录与安装目录内容。

## 8. 验收案例

| 请求 | 预期技能 |
| --- | --- |
| “先别写代码，逐轮挑战这个缓存方案里的决定” | `grilling` |
| “这个模块接口太乱，帮我比较三种 seam” | `codebase-design` |
| “行为已经确定，用 TDD 实现” | `tdd` |
| “这个测试偶发失败，根因不知道” | `diagnosing-bugs` |
| “按 AGENTS.md 和原始 spec 审查这次 diff” | `review-code-against-spec` |
| “rebase 卡在三个冲突，保留两边意图并继续” | `resolving-merge-conflicts` |
| “实现这个明确的小改动” | 不触发技能，使用 Codex 默认实现能力 |
| “根因还不知道，直接给它补个测试修掉” | 先用 `diagnosing-bugs`，不直接进入 `tdd` |
| “扫描整个仓库并生成架构可视报告” | 当前核心集合不覆盖，按普通专项任务处理 |

## 9. 完成标准

- 通用目录中恰有上述六个新增个人技能，且不覆盖系统技能。
- Codex 运行时能够发现六个技能；桌面端技能选择器刷新后显示对应 `display_name` 和 `short_description`。
- 六个技能通过名称、frontmatter、元数据、链接、资源直达和上下文预算校验；官方校验器的环境阻断需被如实记录。
- 相对链接、资源直达、旧依赖技能调用、目录/名称不一致均为 0。
- 工作区源目录与通用安装目录逐文件一致。
- 本文状态更新为“已实施并验证”，并记录最终文件和校验结果。

## 10. 实施结果

已创建并安装：

- `grilling`
- `codebase-design`
- `diagnosing-bugs`
- `tdd`
- `review-code-against-spec`
- `resolving-merge-conflicts`

最终产物包含 6 个 `SKILL.md`、6 个 `agents/openai.yaml` 和 5 个按需 reference，共 17 个技能文件。没有复制 Bash 人工循环模板，也没有保留对未安装技能的调用。

校验结果：

| 检查 | 结果 |
| --- | --- |
| 工作区 `scripts/Test-CoreSkills.ps1` | 通过，6/6 |
| 安装目录 `scripts/Test-CoreSkills.ps1 -SkillsRoot C:\Users\Administrator\.codex\skills` | 通过，6/6 |
| 名称/目录、frontmatter、description、`agents/openai.yaml` | 通过 |
| 相对链接、资源从 `SKILL.md` 一层直达 | 通过，失效或孤立资源 0 |
| TODO、未安装技能调用、意外根目录文件 | 0 |
| `SKILL.md` 本地预算 | 全部不超过 100 行 |
| 工作区源与安装副本 SHA-256 | 逐文件一致 |
| Codex 当前技能目录发现 | 通过，六个安装路径均已进入技能目录 |
| 桌面技能选择器元数据 | 通过静态校验；若已有窗口仍显示旧索引，按产品规则重启 Codex 后刷新 |
| 系统 `quick_validate.py` | 未启动：默认 Python 与 Codex 随附 Python 均缺少 `PyYAML`；未为校验额外安装依赖 |

官方校验器在导入阶段退出，尚未读取任何技能文件。仓库内等价校验器覆盖其当前实现检查的 frontmatter 存在性、字段、名称格式、名称长度、description 类型/长度/非法尖括号，并额外覆盖 UI 元数据、资源布局、链接和安装一致性。
