# Parametric Bracket：四孔安装板

在仓库根目录运行 `moon run examples/parametric_bracket --target js`。同一草图输出初始、加宽、扩大孔、修改边距、冲突和恢复六个阶段。

| 输入或操作 | 输出（容差内的近似值） |
| --- | --- |
| 板宽 120、高 80、孔半径 5、水平 / 垂直孔心边距 20 / 15 | 四孔心 (20,15)、(100,15)、(20,65)、(100,65)，半径均为 5 |
| 依次将板宽 120→160、孔半径 5→8、水平边距 20→30 | 四孔心 (30,15)、(130,15)、(30,65)、(130,65)，半径均为 8 |
| 额外启用宽度 170，与已有宽度 160 冲突 | 返回未达标报告，保存几何保持上一阶段不变；停用冲突后恢复 `Satisfied` |

孔顺序为左下、右下、左上、右上；边距是孔心到板边的距离。输入通过 `set_constraint()` 修改，由 `solve_and_apply()` 重新计算几何，不直接给孔心赋目标坐标。

![实际求解结果](../../docs/images/bracket-before-after.svg)

[main.mbt](main.mbt)建立几何与关系；[bracket_wbtest.mbt](bracket_wbtest.mbt)额外检查板高和双向边距编辑。完整参数、约束、解析校验与 JSON 字段见 [Showcase 说明](../../docs/SHOWCASE.md)。

如需独立检查 SVG，运行 `node scripts/bracket_showcase.cjs --check --target js`；该命令需要 Node.js。它只验证这个案例，不运行全量套件。


案例的 JSON 事件包含核心 `Sketch::to_svg()` 返回的 `svg` 字符串。运行 `python scripts/export_svg.py --write` 写出独立的修改前、修改后及冲突 SVG；`--check` 只核对文件。接口和共享比例见 [SVG 导出](../../docs/SVG_EXPORT.md)。此功能已包含在当前 Mooncakes 0.2.2 正式版本中。
