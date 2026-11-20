# 独立消费案例：圆角安装板

维护者自建的 MoonBit 命令行案例。它在仓库外的新模块中用 Mooncakes 的 `mik1e80/cad_sketch@0.4.1` 和 MoonBit core 编译，由公开 API 驱动草图编辑。

板轮廓由四段直线和一段预先创建的有限圆弧组成，圆弧与相邻边共享端点。两圆孔的间距用构造线测量。使用方显式建立相切关系、控制尺寸，并决定何时应用结果。此案例覆盖一个固定构型，自动圆角、加工校验和交互界面超出其范围。

| 阶段 | 输入 | 实际检查 |
| --- | --- | --- |
| 初次求解 | 板宽 60，高 40，孔心距 25，圆角半径 6 | 检查角点、弧端点、孔位与参考测量，输出 SVG |
| 尺寸编辑 | 四参数改为 76、48、33、9 | 只替换尺寸约束，按解析坐标检查联动。旧结果仍测得半径 6 |
| 冲突处理 | 额外要求同一圆弧半径为 12 | 求解结果未达标，已保存几何保持不变。诊断最多试 16 个子集、计费 120 次 QR |
| 恢复 | 删除额外的半径约束 | 再求解达标，检查已保存几何 |

## 复现

从源码仓库根目录运行以下命令（POSIX shell），或在 Windows 中手动将同样两个文件复制到新的仓库外项目。将 `moon.pkg.in` 复制成 `moon.pkg`。示例源码在 [dev/registry_plate](https://github.com/mik1e80/moonbit-cad-sketch/tree/main/dev/registry_plate)。

```sh
repo="$PWD"
cd "$(mktemp -d)"
moon new registry_plate --user audit
cd registry_plate
moon add mik1e80/cad_sketch@0.4.1
cp "$repo/dev/registry_plate/main.mbt" main.mbt
cp "$repo/dev/registry_plate/moon.pkg.in" moon.pkg
moon run . --target js --release --deny-warn > plate-js.txt
moon run . --target js --release --deny-warn -- --benchmark
```

`plate-js.txt` 中有 `before`、`after`、`conflict` 三个阶段和对应 SVG 文档。构造线使用虚线，圆弧使用 SVG 路径。阶段末尾列出诊断的实际预算消耗和恢复结果。

## 实测记录

2026-11-20，Windows x64（build 26200），AMD Ryzen 9 8945HX，Node.js 24.22.1，`moon 0.1.20261023` / `moonc 0.10.17+d971670cd` 与匹配 core。显式 `moon add` 更新了注册表索引，使用已缓存的 0.4.1 注册表包。工作目录在仓库外，依赖声明是固定注册表版本。

JS release 模式下初始和编辑均达标，各 18 变量、18 方程、4 次迭代及 4 次 QR。编辑后最大容差比约 0.0182。冲突实际未达标，诊断完成 3 次子集求解并耗尽 120 次计费 QR，删除额外约束后恢复。这个预算结果仅描述该次局部诊断。

计时在相同构型上一轮预热后取三次，每次重建同一模型。计时区间为编辑后求解、一次 SVG 生成和冲突诊断，不包括构建和输出到终端的时间。单位为 µs。

| 样本 | 编辑后求解 | SVG | 冲突诊断 |
| --- | ---: | ---: | ---: |
| 1 | 312.2 | 46.2 | 7275.2 |
| 2 | 575.2 | 56.1 | 7770.3 |
| 3 | 390.1 | 44.9 | 7538.7 |

这些是单机、固定模型的局部测量，无跨版本、跨机器或大规模性能结论。独立应用验证与历史完整回归见[消费记录](CONSUMER_TEST.md)。

案例代码和几何均为项目自建，按 [Apache-2.0](../LICENSE) 分发。输入是源码中的尺寸和解析几何，来源与范围见[模型许可政策](MODEL_DATA_POLICY.md)。
