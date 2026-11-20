# 功能与验收矩阵（稳定版 0.4.1）

本库是纯 MoonBit 的小型二维参数化草图求解组件。下表指源码能力，发布与回归状态见 [版本证据](COMPLETENESS_VALIDATION.md)，不能用功能存在代替安装和回归验证。

| 能力 | 入口 / 行为 | 验证 |
| --- | --- | --- |
| 点、有限线段、圆 | checked builder / setter；稳定草图内句柄 | 原有功能、所有权与边界测试 |
| 有限有向圆弧 | center/start/end + 方向；内置等半径方程 | arc_test、arc_boundaries_test、arc_wbtest。发布后维护另增 maintenance_sequence_test |
| 37 种用户关系 | 原 24 种 + 圆直径、12 种圆弧相关关系 | CONSTRAINT_SPEC；原回归与新增导数检查 |
| 参数编辑 | checked 编辑；约束修改、启停、删除 | checked_edit_test、geometry_edit_test |
| 几何生命周期 | 引用检查；显式删除；不自动级联；编号不复用 | geometry_edit_test、arc_boundaries_test |
| 构造几何 | 参与求解；可在 SVG 中隐藏或虚线显示 | geometry_edit_test |
| 参考测量 | 不添加方程；不修改草图；支持 Solution 快照 | measurement.mbt 文档测试、geometry_edit_test |
| 矩形辅助 | 原子创建四点四边；不自动添加尺寸或方向约束 | geometry_edit_test |
| 求解 | 局部阻尼迭代；成功才应用 | 原有求解器回归、圆弧冲突恢复 |
| 方程来源 | 用户 ConstraintId 或内置 ArcId；分量、容差比 | diagnostics_analysis_test、arc_test |
| 局部冗余候选 | 满足基线的单条排除秩比较 | diagnostics_analysis_test |
| 冲突候选 | 固定初值、有界子集试验；保留试验结果和预算 | diagnostics_analysis_test |
| SVG | 真实圆弧路径；方向、大弧标志、共享视野 | arc_test、SVG 原回归与 arc_fillet |
| 模型来源 | 自行生成，无外部 CAD 模型数据 | MODEL_DATA_POLICY；语料清单 |

仓库外公开 API 工作流见[独立圆角安装板](REGISTRY_PLATE.md)。

不包含完整 CAD 界面、自动圆角/修剪、三维实体、DXF/STEP、通用装配、全局可满足性证明。具体约束定义优先于名称相似性；见 [SolveSpace 对照](SOLVESPACE_COMPARISON.md)。

