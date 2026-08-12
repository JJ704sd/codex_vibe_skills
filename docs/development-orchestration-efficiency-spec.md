# 开发场景编排提效规范

状态：已实施并验证
日期：2026-08-12
适用范围：`codex_vibe_skills` 现有 8 个核心 skills

## 1. 背景与目标

当前 skills 已包含多种隐式循环与图结构：`tdd` 的 red-green-refactor、`diagnosing-bugs` 的反馈回路、`grilling` 的决策图、`evolving-contracts` 的迁移顺序等，但没有统一说明何时可以并行、何时必须串行，以及如何避免 subagents 带来的重复读取、冲突写入和结论漂移。长任务也缺少统一的上下文交接、阶段检查点、无进展停止和预算意识。

本轮不新增泛化的 orchestration skill，而是在现有开发场景中引入一组受约束的执行原语：

- **Graph**：显式表达依赖、关键路径和可并行节点。
- **Loop**：围绕可观察证据迭代，并定义成功、无进展和安全停止条件。
- **Subagents**：仅对独立、输入已固定且收益高于协调成本的节点进行有限 fan-out，由一个主责 agent 完成 fan-in。
- **Context capsule**：只向下一节点传递目标、固定输入、约束、相关路径/行和完成证据，探索过程留在原节点。
- **Checkpoint/resume**：在一致且已验证的阶段边界记录状态，失败或人工反馈后从最近安全点继续。
- **Evaluator gate**：用测试、类型检查、兼容矩阵、实验信号、规范要求或用户判断控制条件路由，而不是靠“看起来完成”。
- **Budget/stuck guard**：限制低价值 fan-out、重复读取、无新增证据的重试和无界循环。

目标是在不削弱证据、安全和授权边界的前提下，缩短关键路径、减少重复上下文和降低返工。普通小任务仍走最简单的单 agent 线性执行。

## 2. 开源项目证据与适配结论

本规范借鉴机制而不引入这些框架依赖，也不照搬其运行时接口：

| 项目 | 官方机制 | 对本仓库的适配结论 |
| --- | --- | --- |
| [LangGraph workflows](https://docs.langchain.com/oss/python/langgraph/workflows-agents) / [persistence](https://docs.langchain.com/oss/python/langgraph/persistence) | 条件边、并行节点、orchestrator-worker、evaluator-optimizer、持久化与 human-in-the-loop | graph 只表达真实依赖；客观 evaluator 决定回路；长迁移在安全阶段做 checkpoint |
| [Microsoft AutoGen GraphFlow](https://microsoft.github.io/autogen/dev/user-guide/agentchat-user-guide/graph-flow.html) / [teams](https://microsoft.github.io/autogen/stable/user-guide/agentchat-user-guide/tutorial/teams.html) / [state](https://microsoft.github.io/autogen/dev/user-guide/agentchat-user-guide/tutorial/state.html) | 官方建议简单任务先用单 agent；GraphFlow 支持顺序、并行、条件和带退出条件的循环；team 可保存/恢复状态 | 默认线性执行；复杂任务才升级到结构化编排；停止条件与状态一致性优先于并行数 |
| [OpenHands stuck detector](https://docs.openhands.dev/sdk/guides/agent-stuck-detector) / [skills](https://docs.openhands.dev/overview/skills) | 检测重复 action-observation、重复错误、交替模式和上下文错误；skills 按 discovery/invocation/resources 渐进加载 | 引入 no-progress/stuck guard；上下文按需披露；skill 正文继续保持小而专注 |
| [mini-SWE-agent](https://github.com/SWE-agent/mini-swe-agent) | 简单线性 history、独立动作、显式 step/cost limit 和默认确认模式 | 不为编排本身增加层级；副作用前保留确认门；预算是停止/降级信号而非完成证据 |
| [SWE-agent ACI](https://swe-agent.com/latest/background/aci/) | 编辑时立即 lint、限制单次文件视图、搜索结果保持精简 | 把快速静态检查放到最近的编辑回路；向下游传递定位结果而非完整探索日志 |

上述项目也说明并行重试、多 agent 竞争和通用 critic 可能显著增加成本，且 experimental API 会变化。本仓库只保留不依赖特定框架、能由现有 skill 验证的稳定原则。

## 3. 非目标

- 不把普通实现、写 spec、拆 ticket、handoff 或全仓扫描包装成新 skill。
- 不以 agent 数量、并行调用数或循环次数作为效率指标。
- 不让 subagent 代替当前用户作决定、绕过审批或扩大外部副作用。
- 不并行修改同一文件、同一公共契约或同一 Git 状态。
- 不把 graph 维护成独立且易过期的项目管理产物；它只服务当前任务。
- 不默认采用多次竞争生成后“投票选优”；只有结果可由独立 evaluator 低成本判定时才允许有限尝试。
- 不用摘要替换规范、原始 diff、失败输出或其他必须精确复核的一手证据。

## 4. 调用者可见契约

### 4.1 输入

每个 skill 从调用者接收既有任务上下文、适用规范、仓库状态和可用工具。准备并行的节点还必须拥有固定输入：明确的路径、提交或 diff、复现命令、行为 slice、契约版本或决策问题。

### 4.2 输出

skill 的最终输出仍遵循原有场景契约，同时补充：

- 采用的关键路径或迭代回路；
- 每个并行节点产生的证据及其固定输入；
- fan-in 后的冲突处理、未覆盖区域和残余风险；
- 因无进展、安全或授权边界而停止时的明确原因。
- 跨阶段或跨 agent 时使用的 context capsule 及其来源版本。

### 4.3 不变量

1. **先图后并行**：先识别依赖和写入集合，再决定是否 fan-out。
2. **单一集成主责**：只有主责 agent 汇总结论、处理重叠并执行最终 Git 操作。
3. **固定输入（pinned input）**：并行节点基于同一仓库快照、diff、spec、复现条件或契约矩阵；输入变化后旧结论必须 revalidate。
4. **写入互斥（non-conflicting read/write sets）**：重叠文件、共享生成物、公共接口、数据库状态、生产环境和 Git index/HEAD 始终串行。
5. **证据闭环**：每次 loop 都有假设或目标、动作、观察与下一步；重复同一动作而没有新增证据不算进展。
6. **有界 fan-out**：只并行 current frontier（当前依赖前沿）上彼此独立的高价值节点，默认不超过可用 agent 槽位，也不递归扩散无关工作。
7. **降级透明**：subagents 不可用、协调开销过高或输入无法固定时，保持相同契约并串行执行。
8. **最小上下文**：下游获得足够复核结论的 capsule，不接收无关搜索转录；被省略的证据仍可按路径、命令或节点结果定位。
9. **客观路由**：优先用确定性工具和业务证据作 gate；LLM reviewer 只能发现候选问题，不能替代测试、规范、用户审批或运行时证据。
10. **安全检查点**：只在工作区/外部状态一致且验证通过时 checkpoint；恢复时核对仓库 revision、输入版本和未完成副作用。
11. **有界路由**：节点结果只可推进到已解锁节点、携带新证据后重试、由主责串行接管、交给一个既有适用 skill，或停止；不允许递归 fan-out 或临时创造元路由层。

### 4.4 错误与停止语义

- 节点证据冲突：主责 agent 回到共同输入复核，不以多数票替代证据。
- 节点失败：只重试可恢复且能产生新信息的节点；否则串行接管或报告未覆盖范围。
- loop 无进展（no-progress）：连续两轮没有缩小假设、改变信号或推进验收，或者开始重复相同 action/error、交替无效路径时停止，重新设计回路或请求最小缺失信息。
- 安全或授权不足（safety/authorization stop）：立即停止相关节点，不通过其他 agent 或替代工具绕过。
- 外部状态变化：重新固定输入并验证受影响节点，不能直接复用过期结论。
- 预算接近上限：优先停止低价值分支、压缩上下文或退回单 agent 关键路径；不得把预算耗尽描述为完成。
- checkpoint 不一致：丢弃该 checkpoint 并回到最近已验证边界，不猜测或拼接部分状态。

## 5. 执行模型

### 5.1 Work graph

节点至少记录：目标、输入、依赖、读写集合、完成证据和副作用等级。边表示“完成或证据可用后才能开始”，不是文件之间所有可能关系。

调度顺序：

1. 优先执行能解除最多下游阻塞的关键节点。
2. 同一 frontier 中只有读写集合不冲突的节点可并行。
3. fan-in 后先验证共同不变量，再开放下一批节点。
4. 小于并行协调成本的节点直接串行执行。
5. 条件分支由节点的完成证据激活；“任一完成即可”的 fast path 仅用于真正可替代的结果，正确性 gate 默认等待所有必需依赖。

节点完成后只允许以下路由：

```text
advance | retry-with-new-evidence | serial-takeover | handoff-to-existing-skill | stop
```

`retry` 必须说明相较上轮新增的输入、假设或信号；`handoff` 必须满足目标 skill 的原触发条件。

### 5.2 Evidence loop

每轮使用以下最小状态：

```text
目标/假设 -> 本轮动作 -> 可观察结果 -> 与上轮的增量 -> 下一步或停止原因
```

场景已有循环优先复用，不增加第二套元循环。循环必须保留原技能要求的 red 证据、绿色基线、分布样本、兼容矩阵或用户确认等完成条件。快速 lint/typecheck 可作为 edit-time feedback，但不能替代调用者可见行为验证。

### 5.3 Subagent fan-out/fan-in

满足以下全部条件才 fan-out：

- 至少两个节点位于当前 frontier，且不存在前置依赖；
- 每个节点有可独立检查的交付物和固定输入；
- 节点不会修改重叠路径或共享外部状态；
- 预计节省的关键路径时间大于分派、读取和汇总成本。

默认优先并行只读分析。需要写入时，为每个节点分配互斥路径和验收命令。主责 agent 在 fan-in 时检查输入版本、去重、解决矛盾、运行跨节点验证，并独占 staging、commit、merge、rebase 和 push。

### 5.4 Context capsule

跨节点最小交接格式：

```text
objective; pinned input/revision; dependencies; constraints; allowed read/write and side effects; path:line or commands; expected/observed evidence; budget and stop condition; unresolved risks
```

仓库探索节点应返回相关位置和为何相关，不返回完整 shell/search 历史。上下文接近上限或任务恢复时，压缩为 capsule 后重新读取仍需精确引用的一手材料。

### 5.5 Checkpoint、预算与人工门

- 在绿色测试、已验证设计、迁移阶段 gate、已复核审查轴或冲突 wave 结束后记录可恢复状态。
- checkpoint 至少包含 revision、已完成节点、验证命令/结果、未完成副作用和下一 frontier；不持久化密钥或敏感载荷。
- 为高不确定节点先设置小的探索预算；只有产生新证据才扩展。昂贵的多尝试必须有独立 evaluator 和明确上限。
- destructive、生产、权限提升、公共契约取舍和用户业务判断始终经过现有授权或 human-in-the-loop gate。

## 6. 方案比较与选择

| 方案 | 接口与迁移 | 优点 | 主要问题 | 结论 |
| --- | --- | --- | --- | --- |
| 新增 `orchestrating-work` skill | 新入口统一处理所有任务，再路由到现有 skills | 规则集中 | 触发边界宽，与默认规划/实现能力重叠；容易形成浅层元路由 | 不采用 |
| 在每个 skill 复制完整编排规则 | 每个 skill 自包含 | 安装后无需仓库级文档 | 重复高、易漂移、增加主入口上下文 | 不采用 |
| 仓库 spec + skill 内场景化最小契约 | spec 维护共同原则，各 skill 只保留适用规则 | 边界清晰、上下文小、可独立安装 | 需要仓库验证器防止关键约束漂移 | **采用** |

采用第三种方案。共同设计依据保留在本 spec；每个 `SKILL.md` 仅加入该开发场景真正需要的提效规则。

## 7. 现有 skills 的场景化调整

| Skill | 典型开发场景 | 关键提效机制 | 并行与 gate |
| --- | --- | --- | --- |
| `grilling` | 发布方案、缓存策略、数据保留等关键决策 | decision graph、frontier rounds、decision capsule | 用户判断不可委派；仅批量询问互不依赖的问题，用户确认是完成 gate |
| `codebase-design` | 支付接口、插件边界、租户隔离 | interface/dataflow graph、独立方案、constraint evaluator | 重要方案可基于同一 evidence capsule 独立推导，再由主责综合；不共同编辑草稿 |
| `tdd` | 已确定行为的功能交付或回归修复 | behavior-slice graph、red-green-refactor、edit-time checks、green checkpoint | 仅并行互不依赖、文件不重叠且各自可 red 的 slices；同一 seam 单主责，测试是 gate |
| `refactoring-safely` | 模块迁移、重命名、调用方批量迁移 | impact graph、migration waves、preservation checkpoint | 只并行互斥路径；删除旧路径和全局验证串行，证据变化立即停止当前 wave |
| `evolving-contracts` | API/schema/事件/依赖升级 | producer-reader-storage-deployment graph、阶段 gate、resumable cursor/checkpoint | 可并行兼容性检查和互斥迁移批次；权威写入、收缩和恢复串行 |
| `diagnosing-bugs` | 线上缺陷、flake、性能瓶颈 | evidence graph、单变量实验、focused context、stuck guard | 可并行采集互不影响的只读证据；环境变更和因果实验串行，原始场景复验是 gate |
| `review-code-against-spec` | PR/diff 双轴验收 | coverage map、双独立 reviewer、精确引用、risk-first budget | Standards 与 Spec 可基于同一 pinned diff 并行只读审查；主责 fan-in 去重，不能循环改代码 |
| `resolving-merge-conflicts` | merge/rebase 多文件冲突 | conflict graph、resolution waves、Git-state checkpoint | subagents 仅分析独立冲突；单一 resolver 写入、暂存并继续 Git 操作，状态检查是 gate |

## 8. 验收标准

- 仍然只有现有 8 个核心 skills，不新增泛化编排入口。
- 8 个 `SKILL.md` 均保留原触发与停止边界，并加入表中对应的最小提效规则；不要求每个 skill 使用全部原语。
- 所有 subagent 规则都约束固定输入、独立节点和单一 fan-in 主责；不存在无条件并行表述。
- 所有 mutation、生产副作用和 Git 状态变更都有明确串行或授权边界。
- `scripts/Test-CoreSkills.ps1` 能检查每个 skill 的场景化编排契约仍然存在。
- README 能让使用者发现该 spec，并说明 graph/loop/subagents 是 skill 内部执行策略而非第 9 个 skill。
- 长任务或多 agent 场景能交付最小 context capsule；至少迁移类 skills 明确安全 checkpoint/resume，循环类 skills 明确 no-progress/stuck guard。
- gate 优先依赖场景的一手确定性证据；安全敏感副作用仍受人工或既有授权控制。
- 仓库验证器、`git diff --check` 和适用的系统 skill 校验全部通过。

## 9. 实施顺序

1. 先冻结并复核本 spec 的设计内容。
2. 按“决策与设计 -> 实现与迁移 -> 诊断与审查 -> Git 冲突”的业务链逐项调整 skills。
3. 更新 README 与仓库验证器。
4. 运行验证，按本 spec 做完整性复核。
5. 在独立 `codex/` 分支提交单个原子变更；除非用户另行要求，不推送远端。
