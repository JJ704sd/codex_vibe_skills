# codex_vibe_skills

面向日常代码工作的精简 Codex Skills 集合。该集合只保留高错误成本、跨项目复用且具有明确触发边界的流程，不包装 Codex 已具备的普通实现能力。

## Skills

| Skill | 用途 |
| --- | --- |
| `grilling` | 在实现前逐轮压力测试尚未闭合的计划、设计和关键决策 |
| `codebase-design` | 设计模块接口、依赖方向、CI/CD 发布路径与安全敏感信任边界 |
| `tdd` | 对已知行为或已验证修复执行 red-green-refactor |
| `refactoring-safely` | 用明确不变量、绿色基线和小步验证证明重构不改变行为 |
| `evolving-contracts` | 安全演进 API、数据、schema、依赖、运行时和 CI/CD 工作流 |
| `diagnosing-bugs` | 诊断未知根因、CI/CD 失败、Windows GitHub 凭据上下文分离，并优化已有基线的性能瓶颈 |
| `review-code-against-spec` | 从仓库规范与原始 spec 两个独立轴审查固定 diff |
| `resolving-merge-conflicts` | 基于双方意图安全处理进行中的 merge/rebase 冲突 |

## 设计与验证

- [设计规范](docs/coding-core-skills-spec.md)
- [开发场景编排提效规范](docs/development-orchestration-efficiency-spec.md)
- Windows 结构与内容校验：

  ```powershell
  powershell -NoProfile -ExecutionPolicy Bypass -File scripts/Test-CoreSkills.ps1
  ```

- 校验器负向行为测试：

  ```powershell
  powershell -NoProfile -ExecutionPolicy Bypass -File scripts/Test-CoreSkills.Validator.ps1
  ```

GitHub Actions 会在 push、pull request 和手动触发时运行上述两层自检；校验任务仅授予仓库内容只读权限。

每个技能包含最小 `SKILL.md`、桌面端 UI 元数据 `agents/openai.yaml`，以及仅在需要时加载的 `references/`。

当 Codex 沙箱与 Administrator 终端的 `gh auth status` 结论不一致时，`diagnosing-bugs` 会先执行脱敏的双上下文探针，区分 token 失效与 Windows Keyring 可见性边界，再决定是否需要重新登录或在获批上下文执行 Git 网络命令。

## Git 与 CI/CD 职责

Git 管理和 CI/CD 不是第 9 个独立 skill，而是按证据类型和授权边界分布在现有流程中。只有仓库存在相关 workflow、required checks、制品或部署契约，且当前任务会读取、影响或改变它们时，才启用对应规则；普通 Git 或编码任务继续走各 skill 的基础流程。

| Skill | Git / CI/CD 职责 |
| --- | --- |
| `grilling` | 发布决策依赖交付状态时，先读取可发现的分支、PR、检查和部署状态，只询问发布政策、风险接受与上线时机 |
| `codebase-design` | 流水线属于设计范围时，设计触发器、最小权限、凭据边界、制品晋级、环境、并发与回滚 |
| `tdd` | 存在相关 CI 时，将本地 red/green 命令映射到 CI job，不把 push 后失败当作第一条 red |
| `refactoring-safely` | 重构会影响构建或交付时固定 required checks 基线，不以削弱门禁换取绿色 |
| `evolving-contracts` | 交付契约发生变化时，把 action、runner、权限、缓存、制品、环境和部署接口作为兼容契约迁移 |
| `diagnosing-bugs` | CI/CD 确有失败证据时，固定 workflow/run/attempt/SHA/job/runner，区分代码、权限、secret、runner、缓存和平台故障 |
| `review-code-against-spec` | diff、Spec 或用户请求涉及交付时，将 workflow diff、action SHA、权限和对应 head SHA 的检查结果纳入审查；绿色 CI 不替代 Spec 验收 |
| `resolving-merge-conflicts` | 实际冲突涉及 workflow 时重建两侧语义，解析后使旧 CI 结论失效并重新验证 |

共同硬边界：读取状态和日志通常是只读证据；commit、push、建 PR、rerun/cancel、merge、环境批准和 deploy 是彼此独立的写操作，必须分别处于当前请求的授权范围内。任何绿色检查都不自动授予下一项操作的权限。

### Windows 凭据上下文分离

仅当 Git/GitHub 认证结果确实因 Windows 执行身份、沙箱或服务边界而不一致时启用：

| Skill | 按需职责 |
| --- | --- |
| `grilling` | 把身份间认证差异当可发现事实，仅询问是否授权某个身份执行明确网络动作 |
| `codebase-design` | 将执行身份、凭据存储可见性、仓库所有权与命令放置建模为信任边界 |
| `tdd` | 保持本地 red/green；认证探针不能充当测试证据 |
| `refactoring-safely` | 保持本地保存性证明，只把获批的凭据相关 Git 命令放到外部身份 |
| `evolving-contracts` | 身份、凭据存储、helper、secret 注入或 runner 认证改变时作为契约迁移 |
| `diagnosing-bugs` | 先比较脱敏身份探针，区分认证无效与 credential-visibility boundary |
| `review-code-against-spec` | 当前身份读不到 PR/check 时记录 evidence gap，并在获批身份只读取证 |
| `resolving-merge-conflicts` | index/HEAD/worktree 保持单一身份写入，凭据网络命令独立执行 |

不复制或导出 token，不把凭据写入仓库或全局环境，不为统一身份而修改 ACL、仓库所有权、全局 credential helper 或全局 `safe.directory`。对已经核实的仓库，跨所有者外部命令优先使用单命令 `git -c safe.directory=<absolute-repo>`；这只解决该命令的仓库信任判断，不改变认证状态或后续操作授权。

公开仓库的 `git ls-remote` 成功只证明远端和 ref 可读，不证明具有 push 权限。发布获批后，在凭据拥有身份保留已配置的 Git Credential Manager，以固定 SHA 和明确 ref 先做 `git push --dry-run`，再执行同形状真实推送；不要用 `GCM_INTERACTIVE=Never` 阻断所需的 Keyring 认证流程。

## 开发执行提效

Graph、loop 和 subagent 是现有 8 个 skills 内部按场景使用的执行策略，不是第 9 个独立 skill（not a ninth skill）。复杂任务还可使用固定输入的 context capsule、安全 checkpoint、客观 evaluator gate、预算与 stuck guard；小任务保持单 agent 线性执行。

只有当前依赖 frontier 上输入已固定、证据可独立验收且读写集合不冲突的节点才能并行。共享 artifact、公共契约、权威外部状态和 Git 状态采用 single-writer，由一个主责 agent 汇总并运行跨节点验证。

## 安装

将需要的完整技能目录复制到 Codex 的用户 skills 目录。不要只复制 `SKILL.md`；`agents/` 和 `references/` 属于技能的一部分。

Codex 通常会自动发现技能变更；若桌面端技能选择器未刷新，请重启 Codex。

## 来源与许可

本集合从 `quality_tests_skills` 的工程技能中选择性改写，并按更小的通用代码工作边界重新设计；新增技能则从开发闭环中的高风险空白独立推导。遵循仓库根目录的 MIT License。
