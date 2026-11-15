# 2026 年 11 月贡献与验证索引

更新日期：2026-11-15。本文整理公开开发记录，不是报名表、资格审核结果或获奖声明。具体参赛周期及可计入工作以赛事方确认的范围为准。

## 既有基础

十一月之前的基线为 [7ee73f1](https://github.com/mik1e80/moonbit-cad-sketch/commit/7ee73f1eceda008f22ca28dedfef332c1ca10e39)（2026-10-27），对应已发布的 Mooncakes 0.2.2。已有 Point / Line / Circle、24 种几何与尺寸约束、编辑与永久删除、诊断、SVG、安装板及四杆机构案例。以上属于既有成果，不能整体重新计作十一月新增。

## 本期实质新增

| 新增工作 | 行为与边界 | 可追溯证据 |
| --- | --- | --- |
| 创建前资源与输入保护 | 所有公开 builder 在追加前限制存储；新增 `try_add_*` / `try_constrain`，非法字段、跨草图句柄、超限和编号耗尽可恢复地拒绝，失败不消耗编号 | [11 月 7 日实现](https://github.com/mik1e80/moonbit-cad-sketch/commit/4b12290f478cc5e2dba27d890f4f93b01cc0fe1c)、[model.mbt](../model.mbt)、[hardening_test.mbt](../hardening_test.mbt) |
| 求解总预算 | 限制累计阻尼 QR 尝试；新增 `BudgetLimit` 和 `linear_solves`；未达标候选不写回。计算次数限制不等于墙钟超时 | [solver.mbt](../solver.mbt)、[预算与边界测试](../hardening_test.mbt) |
| 安全编辑接口 | 新增 `try_set_point` / `try_set_radius` / `try_set_constraint`；拒绝非法字段或句柄，失败保留原值，替换关系保留编号及启停状态。尺度与联合关系仍在求解时复核 | [11 月 13 日实现](https://github.com/mik1e80/moonbit-cad-sketch/commit/a52fd2f1be8f5a5fb3d8117e51394b5bc8c01f94)、[checked_edit_test.mbt](../checked_edit_test.mbt)、[API 指南](API_GUIDE.md) |
| SVG 与奇异输入防护 | 标题转义前限制 4096 UTF-16 代码单元；扩展奇异初值、失败不写回、容量及编号边界测试 | [svg.mbt](../svg.mbt)、[白盒边界测试](../hardening_wbtest.mbt) |
| 维护及供应链加固 | 增加安全与贡献规则、补全第三方说明；Actions 固定 SHA，编译器及 core 固定版本并校验散列；支持四后端轻量检查 | [安全策略](../SECURITY.md)、[贡献规则](../CONTRIBUTING.md)、[第三方说明](../THIRD_PARTY_NOTICES.md)、[CI 配置](../.github/workflows/ci.yml) |
| 新版本交付闭环 | 发布 Mooncakes 0.3.0 及 GitHub v0.3.0，执行本版完整回归、真实注册表安装及归档一致性检查 | [发布回执](releases/0.3.0.json)、[CHANGELOG](../CHANGELOG.md)、[正式 Release](https://github.com/mik1e80/moonbit-cad-sketch/releases/tag/v0.3.0) |

[完整基线差异](https://github.com/mik1e80/moonbit-cad-sketch/compare/7ee73f1eceda008f22ca28dedfef332c1ca10e39...928b9466e8f6ceb441e3c5179fe968f88b1a3bbe)包含上述实现、测试和发布说明。后续文档提交不冒充新的核心算法成果。

## 当前版本的实测证据

- [完整回归](https://github.com/mik1e80/moonbit-cad-sketch/actions/runs/43365012044)固定到核心提交 `5ea24f2`：wasm / wasm-gc / JS / native 各 127 项测试，各 400 个生成模型；JS 1000 组随机初值通过独立几何检查。解包后的完整测试各 132 项通过。
- [0.3.0 发布提交](https://github.com/mik1e80/moonbit-cad-sketch/commit/928b9466e8f6ceb441e3c5179fe968f88b1a3bbe)仅随后更新发布说明，运行时代码保持不变；对应[轻量检查](https://github.com/mik1e80/moonbit-cad-sketch/actions/runs/43365443114)通过。
- [真实 registry consumer](releases/consumer-0.3.0.json)：仓库外新项目从 Mooncakes 安装，3 项消费测试及程序运行、SVG XML 校验通过，124 个下载文件与上传 ZIP 逐字节一致；另有 10 项安装包安全接口测试通过，见[发布回执](releases/0.3.0.json)。
- SciPy 对照与四档 Benchmark 计时没有在本次重新测量；旧测量保留原始源码指纹。测试条目数、生成模型数、随机初值数分别统计，不相互混算。

这些是维护者构造的案例与消费验证，证明限定场景下的可用性；不等于第三方生产采用、独立安全审计或任意模型收敛保证。外部集成和后续维护安排见[维护计划](MAINTENANCE.md)。

## 对外说明时需要另行核实

实际提交的一页项目说明应与上述范围、版本、仓库及验证记录一致；其附件、账户报名、入群、审核状态和评选资格不能由本仓库证明。当前未核验实际报名附件，也未代填或提交报名材料。当前赛事安排参考[官方活动入口](https://moonbitlang.github.io/Hackathon2026/)，不沿用历史十月日期判断全年参赛资格。
