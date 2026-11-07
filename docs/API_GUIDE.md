# API 使用指南

从 [快速开始](QUICK_START.md)进入：创建几何、添加关系、求解、修改尺寸，再按报告判断结果。

| 工作 | 接口 | 专题 |
| --- | --- | --- |
| Geometry | `Sketch::new()`、`add_point()`、`add_line()`、`add_circle()` | [快速开始](QUICK_START.md) |
| Constraint | `constrain()` 与 24 种关系构造器 | [约束参考](CONSTRAINTS.md) |
| Solve | `solve()`、`solve_and_apply()`、`Solution` | [求解与结果](SOLVER.md) |
| Edit | `set_constraint()`、`set_constraint_enabled()`、`remove_constraint()` | [约束生命周期](CONSTRAINT_LIFECYCLE.md) |
| Diagnostic | `SketchError`、`SolveReport`、`likely_conflicts()` | [错误与诊断](DIAGNOSTICS.md) |

## 类型化错误与迁移

源码开发版 0.3.0 增加 `try_add_point()`、`try_add_line()`、`try_add_circle()` 和 `try_constrain()`，返回 `Result[Id, SketchError]`，在写入前拒绝超限或非法定义，失败不消耗编号。处理外部输入应使用这些接口。圆和线的尺度退化、既有几何及组合关系仍在求解时复核；编辑接口仍保留延迟校验语义。

旧 `add_*()` / `constrain()` 保留原签名供可信、有界输入使用：资源超限前会 trap，`constrain()` 的编号耗尽同样会 trap；可恢复的 `IdentifierExhausted` 由 `try_constrain()` 返回。创建失败中的几何/约束 ID 是未写入的候选编号，不能作为已存在对象使用。

长度必须使用调用者统一单位，本库不换算毫米或英寸。句柄仅在同一 `Sketch` 生命周期中使用，不适合作为持久化标识。`let b = a` 共享同一份可变草图，不能用作深复制；本库不承诺并发修改安全，宿主须自行同步。

`solve()` / `solve_and_apply()` 返回 `Result[Solution,SketchError]`。完整分类、模式匹配和 String API 迁移说明已整理到 [诊断文档](DIAGNOSTICS.md#类型化错误与迁移)。

## 进阶入口

范围与资源边界见 [LIMITATIONS](LIMITATIONS.md)。高级数值设置见 [SOLVER](SOLVER.md#容差与选项)，算法细节见 [ARCHITECTURE](ARCHITECTURE.md)。可执行公开接口示例保留在 [README.mbt.md](../README.mbt.md)。


## SVG 导出

`Sketch::to_svg()` 返回当前保存几何的 SVG 字符串；可选设置画布、点标记、标题和共享视野。Mooncakes 0.2.0 起包含此接口。[完整用法与三阶段图形](SVG_EXPORT.md)说明校验、坐标方向和冲突保留语义。
