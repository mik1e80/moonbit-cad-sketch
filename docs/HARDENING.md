# Security & Reliability Hardening — 2026-11-07

**当前状态（2026-11-13）：0.3.0 已正式发布。** 四后端完整回归、400×4 模型、1000 随机初值、真实注册表消费和新增安全编辑接口验证已通过，详见[发布回执](releases/0.3.0.json)及[全量记录](releases/0.3.0-full-regression.json)。下文的“未发布”和“未全量测试”描述保留 11 月 7 日的历史时点，不能作为当前状态。

2026-11-13 后续修改：增加 `try_set_point` / `try_set_radius` / `try_set_constraint` 安全编辑，失败不写入，替换关系保留 ID 和启停状态；字段检查不代替求解时的尺度与联合关系验证。0.3.0 最低编译器调整为 `moonc >= 0.10.17`，与 CI 和 Windows 验证版本对应。新增 3 项编辑回归及 3 项公开接口文档示例。本次已获得全量回归和通过后发布的例外授权；实际结果和版本归档见后续发布记录，下文保留 11 月 7 日的测试范围。

本轮基于 `7ee73f1eceda008f22ca28dedfef332c1ca10e39`，按资源保护、协议边界、可靠性复核三阶段修改。源码版本为 **0.3.0，尚未发布**；已发布的 Mooncakes 0.2.2 和历史验证记录保持原样。此记录不代表独立安全审计。

## 修改与边界

| 事项 | 本次行为 |
| --- | --- |
| 创建前资源检查 | 所有 public builder 在追加前检查 256 标量变量、512 线、512 现存约束；禁用约束仍占名额，删除释放名额 |
| 可恢复创建 | `try_add_*` / `try_constrain` 返回类型化错误，拒绝非法数值、外部句柄和超限；错误不追加存储、不消耗编号 |
| 兼容接口 | 旧签名保留，超限及编号耗尽会 trap；不可信输入须改用 checked API。既有几何、编辑值和尺度退化仍由求解复核 |
| 计算预算 | 每个阻尼 QR 尝试均计数，包括失败/拒绝的步；默认总计 400、最多 4000，每轮最多 16 次；`BudgetLimit` 与 `linear_solves` 可检查，未达标不写回 |
| SVG | 标题最多 4096 UTF-16 代码单元，转义前检查；保留 XML 转义 |
| 接口迁移 | `SolveOptions` 结构保持；新增公开枚举变体需更新穷尽匹配，因此预留新 minor 版本 |
| 供应链 | Actions 使用完整 SHA；MoonBit 与 core 固定 `0.10.17+d971670cd` 并在解压前校验 SHA256；工作超时、只读 token、checkout 不保留凭据 |
| 维护 | 增加 SECURITY、CONTRIBUTING；补全 upload-artifact / NumPy / SciPy 许可来源；统一无限直线、单位、共享可变状态及工程验证边界 |

`linear_solves` 仅统计迭代 QR，不包括最终残差和局部秩诊断。它限制计算次数，不是墙钟超时。宿主仍须限制输入请求、任务时间与内存，并同步共享可变对象。计算停滞不证明数学无解；`likely_conflicts` 仍为启发式排序。

## 必要的轻量验证

本机使用 Windows、`moon 0.1.20261023`、`moonc 0.10.17+d971670cd` 和匹配 core：

- `moon fmt` / `moon fmt --check`、`moon check --target all --deny-warn`、`moon info` 并审阅接口差异。
- JS：`hardening_test.mbt` 7 项、`hardening_wbtest.mbt` 2 项。
- JS：`constraint_combinations_test.mbt` 1 项包含 8 个固定种子组合模型，覆盖全部 24 种关系，扰动初值、打乱关系顺序并抽样子集；以独立解析坐标/半径复核。它是小样本回归，不是任意组合成功率证明。
- JS：README 7 项、SVG 9 项、typed errors 8 项及 white-box 3 项；创建资源边界 2 项、最大 256 变量模型 1 项；新 builder 文档示例 4 项。
- Wasm：新输入与预算边界测试 7 项。
- JS：安装板 6 个实际阶段及提交的 SVG 一致性；源码归档和独立使用方 5 项测试。

默认 CI 在 wasm / wasm-gc / JS / native 上仅运行文档、SVG、加固和少量组合/错误测试；JS 另检查基本示例、安装板与归档使用方。完整库测试、400 模型、1000 随机初值及全规模 Benchmark **未在本轮执行**，继续保留显式 opt-in。最新提交的远程结果以 [Actions](https://github.com/mik1e80/moonbit-cad-sketch/actions/workflows/ci.yml) 对应 SHA 为准，历史批量数据不能充当本次核心修改的全量验证。

版权主体声明依维护者要求暂不新增。本次没有填写或提交报名材料，也没有覆盖已发布包。发布 0.3.0 前须单独确认发布范围并记录该版本的验证证据。
