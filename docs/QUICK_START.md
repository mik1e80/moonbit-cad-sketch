# 快速开始

创建几何 → 添加约束 → 求解 → 读取结果 → 编辑尺寸 → 再求解。安装与第一个草图在使用方项目中执行；仓库内案例在源码仓库根目录执行。

## 安装与版本

当前版本 `0.2.2`：[Mooncakes 包页面](https://mooncakes.io/docs/mik1e80/cad_sketch)。源码仓库：[moonbit-cad-sketch](https://github.com/mik1e80/moonbit-cad-sketch)。模块名：`mik1e80/cad_sketch`。

在已有 MoonBit 项目的根目录运行：

```sh
moon add mik1e80/cad_sketch
```

该命令从注册表下载模块，并写入当前项目的 `moon.mod` 依赖。然后按下文配置使用方的 `moon.pkg` 导入核心包。

工具链要求：`moonc >= 0.10.15`。`0.2.2` 的 Windows 轻量验证使用 `moon 0.1.20261023` / `moonc 0.10.17+d971670cd` 和匹配的 core；旧版 0.10.14 需要先更新工具链。标准库缺失或 Windows 路径问题见[环境排查](ENVIRONMENT.md)。

如果希望修改源码或运行仓库内案例：

```sh
git clone https://github.com/mik1e80/moonbit-cad-sketch.git
cd moonbit-cad-sketch
moon test README.mbt.md --target js
moon run examples/basic
```

源码开发也可使用下文的本地 workspace；示例及核心库只需要 MoonBit。Node.js 和 Python 仅用于可选的开发验证。

## 第一个草图

日常使用只需：创建几何 → 添加约束 → 求解 → 编辑尺寸 → 查看诊断。默认选项即可开始；[API 使用指南](API_GUIDE.md)按这五步介绍接口。

在使用方项目中创建 `cmd/main/moon.pkg`，内容如下；`pkgtype` 将这个包标记为可运行程序：

```moonbit
import {
  "mik1e80/cad_sketch" @sketch,
}

pkgtype(kind: "executable")
```

在同一目录创建 `cmd/main/main.mbt`，写入下面的完整程序。对应的坐标与重复求解行为由 [README.mbt.md](../README.mbt.md) 的公开接口测试核对。

```moonbit
fn main {
  let s = @sketch.Sketch::new()
  let a = s.add_point(0.0, 0.0)
  let b = s.add_point(3.0, 0.5)
  let line = s.add_line(a, b)
  s.constrain(Fix(a, 0.0, 0.0)) |> ignore
  s.constrain(Horizontal(line)) |> ignore
  let dimension = s.constrain(Distance(a, b, 5.0))

  match s.solve_and_apply() {
    Ok(solution) => {
      println("initial satisfied: \{solution.report.is_satisfied()}")
      if solution.report.is_satisfied() {
        let p = s.point(b).unwrap()
        println("B = (\{p.x}, \{p.y})")
      } else {
        for finding in solution.report.likely_conflicts() {
          println("constraint #\{finding.id.index()}: ratio=\{finding.tolerance_ratio}")
        }
      }
    }
    Err(error) => println(error.message())
  }

  // 只修改尺寸约束，以已有几何为初值重新求解。
  if s.set_constraint(dimension, Distance(a, b, 7.0)) {
    match s.solve_and_apply() {
      Ok(updated) => {
        println("edited satisfied: \{updated.report.is_satisfied()}")
        if updated.report.is_satisfied() {
          let p = s.point(b).unwrap()
          println("B = (\{p.x}, \{p.y})")
        }
      }
      Err(error) => println(error.message())
    }
  }
}
```

在使用方项目根目录运行：

```sh
moon run cmd/main --target js
```

两次 `satisfied` 都应为 `true`，B 先接近 `(5,0)`，再接近 `(7,0)`，A 保持在原点附近。坐标按容差解释，浮点打印可能略有差异。长度沿用应用的统一单位；本例未指定毫米或米。

`Ok(Solution)` 包含求解尝试的结果，不一定达标；应先检查 `report.is_satisfied()`。未达标时 `s.point()` 仍是原有保存几何，候选几何从 `solution.point()` 读取。`Err(SketchError)` 用于无效输入或数值错误。冲突后的启停和删除恢复见[冲突示例](../examples/conflict/README.md)。

进行源码开发时，可使用 MoonBit 的[本地 workspace](https://docs.moonbitlang.com/en/latest/toolchain/moon/module.html#local-dependencies) 调用源码。在共同父目录创建 `moon.work`，例如 `members = ["moonbit-cad-sketch", "my_app"]`；在 `my_app/moon.mod` 添加 `import { "mik1e80/cad_sketch@0.2.2" }`，再按上面的 `moon.pkg` 导入。workspace 优先解析本地成员。普通使用者直接用上面的 `moon add` 安装即可。

## 运行案例

| 目录 | 命令 | 观察内容 |
| --- | --- | --- |
| [basic](../examples/basic/README.md) | `moon run examples/basic --target js` | 矩形改宽、三角形与相切圆 |
| [parametric_bracket](../examples/parametric_bracket/README.md) | `moon run examples/parametric_bracket --target js` | 板宽、孔径、边距联动 |
| [mirror_holes](../examples/mirror_holes/README.md) | `moon run examples/mirror_holes --target js` | 镜像孔与对称轴移动 |
| [four_bar](../examples/four_bar/README.md) | `moon run examples/four_bar --target js` | 同一机构连续改变角度 |
| [conflict](../examples/conflict/README.md) | `moon run examples/conflict --target js` | 打印误差比、停用及删除冲突关系 |

修改驱动尺寸使用 `set_constraint()`，直接移动初值使用 `set_point()` / `set_radius()`。查询或编辑返回 `None` / `false` 时先检查句柄归属；所有句柄仅属于创建它的草图。

继续阅读：[约束参考](CONSTRAINTS.md)、[求解与结果](SOLVER.md)、[错误与诊断](DIAGNOSTICS.md)、[限制](LIMITATIONS.md)。
