# Mooncakes 发布与独立安装验证

## 当前正式版本 0.4.1 — 2026-11-17

Mooncakes 正式上传返回 **200 OK**，GitHub [v0.4.1](https://github.com/mik1e80/moonbit-cad-sketch/releases/tag/v0.4.1)已发布并建立 tag。四后端完整回归和最终四项检查通过；发布后独立安装 0.4.1，新 API 四后端各 22 项、圆弧程序和标准消费 3 项 / SVG XML 通过，167 个下载文件与上传 ZIP 完全一致。

[发布收据](releases/0.4.1.json)和[完整验证](COMPLETENESS_VALIDATION.md)记录提交、归档指纹、缓存状态与真实消费结果。事后收据在上传之后生成，不属于不可变归档；0.4.0 保留不覆盖。日常仍只做相关轻量检查，本轮完整回归是授权例外。以下保留各版本的准备与历史记录。

## 0.4.1 维护后发布验收 — 2026-11-20

本次复验现有正式发行版 0.4.1 和维护后的源码。GitHub 正式 [Release](https://github.com/mik1e80/moonbit-cad-sketch/releases/tag/v0.4.1) 与 tag 仍对应 `54eca322`。维护后主分支的验收源码为 `2e5fc4a`，其核心实现、公开接口、模块清单和 Apache-2.0 正文经比较与 tag 一致。原始发布包与事后更新的仓库文档有各自的版本证据。

| 验收对象 | 本次实测结果 |
| --- | --- |
| 维护后的源码 | wasm、wasm-gc、JavaScript、native 各 164/164 项测试通过，包含 480 组圆弧与诊断配置。原有 400 组生成配置及 6 项检查器故障注入每后端通过。JS 1000 组随机三角形全部达标并经独立检查 |
| 维护后的本地源码归档 | GitHub 工作流将新生成的源码归档解包至独立工作区，四后端各 169/169 项通过，其中 5 项为独立消费者测试 |
| Mooncakes 正式包 | 在隔离且空的注册表缓存中下载 0.4.1，ZIP SHA-256 与原发布指纹一致，167 个安装文件逐字节匹配。仓库外的标准消费者 3 项 JS 测试、尺寸编辑程序和 SVG XML 验证通过 |
| 正式包公开 API | 另一新建消费者使用已缓存的注册表包，四后端各 22/22 项公开测试及 JS 圆弧编辑程序通过。项目通过版本依赖引用发布包 |

[当前源码完整回归](https://github.com/mik1e80/moonbit-cad-sketch/actions/runs/44744643950)和[验收收据](releases/0.4.1-maintenance-acceptance.json)记录源代码 SHA、工具链、包指纹和原始验证产物。原始 2026-11-17 的发布记录继续保留。日常仍采用轻量检查。

## 0.4.1 补丁验证

0.4.0 已上传并完成真实注册表消费，163 个文件与上传 ZIP 一致。修正后的新 API 消费工具在四后端各 22 项测试和圆弧程序通过，但原 0.4.0 归档包含导入配置有误的旧开发工具。因此新增 0.4.1 分发修复，核心求解器不变。详见 [版本证据](COMPLETENESS_VALIDATION.md)，不覆盖既有归档。

0.4.1 的 [完整回归](https://github.com/mik1e80/moonbit-cad-sketch/actions/runs/44089465166)已通过，四后端各 160 项测试（含同一新增 480 配置）、原 400 配置各后端通过、JS 1000 初值通过，解包消费工作区各 165 项。以本版实际发布/安装收据验收最终分发，不拿已安装 0.4.0 代替 0.4.1。

## 0.4.0 发布门槛 — 2026-11-17

本版新增有限圆弧、几何生命周期、构造显示、只读测量和有界局部诊断。[实际完整回归](https://github.com/mik1e80/moonbit-cad-sketch/actions/runs/44087504847)固定到 `5e7817c`：四后端各 160 项测试，包含新增 480 配置循环；原有 400 配置各后端通过，JS 1000 随机三角形通过，归档消费工作区各 165 项通过。完整证据见 [0.4.0-full-regression](releases/0.4.0-full-regression.json)。

上传前需复核最终文档版本、公开接口与归档；正式发布后才补记服务端回执、GitHub tag/Release 与新目录注册表消费。发布收据不属于已上传的不可变 ZIP，最新状态统一见 [COMPLETENESS_VALIDATION](COMPLETENESS_VALIDATION.md)。不覆盖 0.3.0 或其历史测量。

## 0.3.0 实际发布与验证 — 2026-11-13

Mooncakes 正式上传返回 `200 OK`；GitHub 已发布 [v0.3.0](https://github.com/mik1e80/moonbit-cad-sketch/releases/tag/v0.3.0)，tag 指向 `928b946`。此前核心提交 `5ea24f2` 的[完整四后端回归](https://github.com/mik1e80/moonbit-cad-sketch/actions/runs/43365012044)通过，发布文档提交的[四后端轻量检查](https://github.com/mik1e80/moonbit-cad-sketch/actions/runs/43365443114)通过，期间运行时代码未变。

仓库外全新项目实际从注册表安装 0.3.0，未用缓存或 workspace/path 替换；3 项 JS 消费测试、程序运行和 SVG XML 检查通过，124 个下载文件与上传 ZIP 逐字节一致。另有 10 项安装包 checked setter、builder 和预算测试通过。[发布回执](releases/0.3.0.json)记录归档 SHA256，[注册表消费回执](releases/consumer-0.3.0.json)记录真实命令与结果。Windows 默认 GBK 环境使用 `python -X utf8 scripts/check_consumer.py`，避免命令输出解码失败。

本次全量回归是用户单独授权的例外，日常仍采用轻量检查。未重新测量 SciPy 对照或全规模 Benchmark，旧版回执保持不变。以下按原日期保留历史发布记录。

该历史记录的模块：`mik1e80/cad_sketch`；版本：`0.3.0`（首版 `0.1.0` 保留不可变）。[Mooncakes 包页面](https://mooncakes.io/docs/mik1e80/cad_sketch)。

## 使用方安装

0.3.0 发布准备已完成核心四后端全量回归，各 127 项测试、400×4 生成模型、1000 组随机初值和四后端各 132 项源码包消费检查通过。[对应源码与 CI 记录](releases/0.3.0-full-regression.json)不使用旧版结果替代本版验证。发布后另保存上传归档指纹和真实 registry consumer 回执；日常检查仍保持轻量。0.3.0 最低要求 `moonc >= 0.10.17`。

在已有 MoonBit 项目的根目录运行：

```sh
moon add mik1e80/cad_sketch
```

使用方的 `moon.pkg`：

```moonbit
import {
  "mik1e80/cad_sketch" @sketch,
}
```

继续阅读[快速开始](QUICK_START.md)。开发时可用本地 workspace；注册表安装验证使用独立项目，不通过 workspace 或本地路径替换依赖。

## 维护者发布

按 [MoonBit 官方发布说明](https://docs.moonbitlang.com/en/stable/toolchain/moon/package-manage-tour.html)操作。使用兼容工具链，确认 `moon.mod` 的模块名、版本、许可证、仓库和 README。版本变更后重新检查归档内容，避免上传未准备好的版本。

```sh
moon login
moon package --list
moon publish --dry-run
moon publish
```

`moon login` 将凭据保存在本机工具链目录，不应复制到仓库。`moon package` 只创建本地 ZIP；只有服务端确认正式发布成功，才能视为已经上传。预检不发布版本。当前验证工具链对成功预检返回的 `202 Accepted` 仍可能以非零退出，须核对服务端明确的 “Dry run completed successfully. No changes were made” 信息；不能把任意非零退出当成成功。

归档包括核心 MoonBit 源码、文档和示例；可选的 `dev/scipy/` 工具通过 `.moonignore` 排除。没有新增运行时依赖。不要向已发布的版本重复上传修改内容；需更新时递增版本。

## 轻量验证范围

首版交付检查发布包及其解包后的静态编译、6 项 README 公开接口示例，以及注册表独立项目的尺寸编辑和类型化错误处理。独立项目必须通过 `moon add` 获取 `0.1.0`，不含 `moon.work`、path 依赖或本地源码替换。

本次不重跑全量回归、后端矩阵、400 / 1000 项实验或 SciPy 对照。历史数据保留其原始源码指纹；提交使用 `[skip ci]` 跳过自动全量工作流。Mooncakes 发布不等于 GitHub Release，也不表示赛事验收已完成。


## 0.1.0 实际发布记录

2026-10-22，正式上传返回 `200 OK`。随后在不属于本地 workspace 的独立项目执行 `moon add mik1e80/cad_sketch`，解析并下载 `0.1.0`；JS 下两项冒烟检查均通过：尺寸 5→7 的求解与编辑、公开 `SketchError::InvalidRadius` 模式匹配。已下载的 99 个归档文件逐字节与上传包一致。

[发布回执](releases/0.1.0.json)记录归档 SHA-256、工具链和验证范围。回执在发布后生成，不属于不可变的 0.1.0 归档。此次未创建 GitHub Release；源码和安装文档通过 Git 提交同步。


## 完整 Consumer Test

发布后的独立安装检查进一步补齐 `moon new → moon add → 最小示例 → moon test → moon run` 全流程；仓库外新项目的两个测试及可执行程序均通过。运行 `python scripts/check_consumer.py` 可复现，完整手工步骤、代码、缓存说明与真实结果见 [Consumer Test](CONSUMER_TEST.md)。该检查只使用公开发布的 0.1.0，未再次发布版本，也不执行库的全量回归。


## 仓库名称与已发布版本

GitHub 源码仓库使用 [mik1e80/moonbit-cad-sketch](https://github.com/mik1e80/moonbit-cad-sketch)，README 标题为 MoonBit CAD Sketch，Mooncakes 模块名继续为 `mik1e80/cad_sketch`。`moon.mod` 的 `repository`、克隆示例和源码文档链接均使用新地址。已有本地检出可执行：

```sh
git remote set-url origin https://github.com/mik1e80/moonbit-cad-sketch.git
```

已发布的 0.1.0 归档包含发布时的原仓库地址，归档保持不可变；本次重命名不重新发布该版本，也不修改原发布回执、源码指纹或历史测量。新地址随后续版本元数据发布。


## 0.2.0 版本与验证策略

0.2.0 将 `Sketch::to_svg()`、`SvgOptions` 和 `SvgBounds` 纳入正式包，模块元数据使用重命名后的仓库地址。0.1.0 归档及历史回执保持不变。

默认 Actions 只运行四后端静态编译、7 项 README 与 9 项 SVG 测试，JS 另运行 5 项真实源码归档消费测试。工作流中的 `full` job 只有在手动触发并勾选 `full_regression` 时才运行；日常提交和默认手动触发不会执行全量回归、400 / 1000 模型实验或完整包矩阵。提交使用 `[skip ci]` 时，可在同一提交上手动触发默认冒烟检查。

`python scripts/check_package.py` 默认只执行消费包的 5 项 JS 测试，使用 `--package audit/cad_consumer`，避免 workspace 把库测试连带执行。`--full` 为明确的完整检查入口。`python scripts/check_consumer.py --archive <上传ZIP>` 在仓库外安装当前版本，执行 3 项 JS 测试与可执行程序，并独立解析 SVG、逐字节核对归档。

GitHub 对应交付名称为 `v0.2.1`。发布记录分别保存 Mooncakes 的实际服务端结果、消费检查和对应提交的 Actions 结果，历史规模数据不改写为本版的新测量。

0.2.1 修复开发消费工具对多行 SVG 的解析；核心库与 0.2.0 相同。0.2.0 的安装、三项测试及程序运行已通过，工具末尾的 XML 解析问题在 0.2.1 修复。


## 0.2.1 实际发布与消费记录

2026-10-22 正式发布返回 `200 OK`。仓库外全新项目从注册表下载 0.2.1，未命中缓存；110 个上传归档文件与安装文件逐字节一致。尺寸编辑、类型化错误及 SVG 接口的 3 项 JS 测试通过，程序实际输出尺寸 6.9999999993777795，多行 SVG 经独立 XML 解析通过。

[发布回执](releases/0.2.1.json)和[消费记录](releases/consumer-0.2.1.json)保留真实版本、归档指纹与验证范围。GitHub 正式版本入口为 [v0.2.1](https://github.com/mik1e80/moonbit-cad-sketch/releases/tag/v0.2.1)，发布验证附件记录对应提交和四后端冒烟工作流结果。

旧包检查脚本首次执行曾意外连带运行 112 项 JS 测试，全部通过；已修复默认执行范围为消费模块的 5 项测试。首次交付至本次例外授权前未再执行库全量回归；随后对当前 Release 的完整回归结果见下节，SciPy 对照与四档 Benchmark 计时仍未重测。


## 2026-10-22 当前 Release 完整回归

2026-10-22，按用户本次例外授权，对 **`v0.2.1` / `458d5f397b2112e392b859c5a3054fafa1eb9185`** 执行完整回归，[实际工作流](https://github.com/mik1e80/moonbit-cad-sketch/actions/runs/39787171206)结果为 **success**。

| 检查 | 实际结果 |
| --- | --- |
| wasm / wasm-gc / JS / native 全量测试 | 各 107/107 通过 |
| 六组自动模型配置 | 四后端各 400/400，通过每后端 6 项检查器故障注入 |
| JS 随机三角形初值 | 1000/1000 Satisfied；Stalled / IterationLimit / Invalid 均为 0 |
| 解包后的完整测试与消费检查 | 四后端各 112/112（107 项库测试 + 5 项消费测试） |
| 安装板、四杆机构、编辑与冲突示例 | 通过 |
| Benchmark | Small 冒烟通过；四档性能计时未重测 |

完整摘要：[full-regression.json](releases/0.2.1-full-regression.json)；[逐模型原始数据 ZIP](https://github.com/mik1e80/moonbit-cad-sketch/releases/download/v0.2.1/full-regression-results.zip)；[完整任务日志](https://github.com/mik1e80/moonbit-cad-sketch/releases/download/v0.2.1/full-regression.log)。ZIP 的 SHA-256 为 `239725cd4cb3d3a92f4aa57bcad1cd06618a2ff9a16cffbcb6d197ab3be759c3`，已与 GitHub artifact 摘要核对一致。

原 `verification.json` 保留首次发布时的轻量验证记录，本节是随后补充的全量结果。旧批量快照保持原始指纹，新运行证据单独保存；SciPy 开发对照及四档 Benchmark 未重测。日常 CI 仍默认轻量，未修改 tag、运行时代码或已发布的 Mooncakes 包。


## 2026-10-26 环境恢复与 0.2.2 轻量发布准备

默认 Windows 工具链已更新为 `moon 0.1.20261023` / `moonc 0.10.17+d971670cd`，编译器与 core 版本一致，标准库重新 bundle。旧工具链目录已备份，注册表缓存与现有登录凭据保留。新终端直接使用默认 `moon` 后，JS 零警告检查、7 项 README 测试和基础示例实际运行通过。

本次发布准备另通过格式检查、JS 构建、9 项 SVG 测试及解包后的 5 项 JS 消费测试。归档检查要求包含新的 [Windows 环境准备](ENVIRONMENT.md)文档；MoonBit 官方技能仅安装在个人环境，不进入库依赖。

0.2.2 的核心 MoonBit 实现、测试及生成接口与 0.2.1 相同；本次发布只更新环境与分发文档、模块版本和归档内容检查。完整四后端回归继续引用原 v0.2.1 tag 的实际记录，不将其改写为 0.2.2 的新全量测量。


## 0.2.2 实际发布记录

2026-10-26，正式发布返回 `200 OK`；仓库外全新项目从注册表安装 0.2.2，3 项 JS 消费测试与程序运行通过，SVG 经独立 XML 解析。上传归档的 114 个文件与下载文件逐字节一致。默认工具链的实际使用路径为个人 `.moon` 安装，编译器版本 `0.10.17+d971670cd`，旧安装已备份、登录凭据保留。

[发布回执](releases/0.2.2.json)与[消费记录](releases/consumer-0.2.2.json)记录实际版本、归档 SHA-256 与轻量验证范围。GitHub 版本入口为 [v0.2.2](https://github.com/mik1e80/moonbit-cad-sketch/releases/tag/v0.2.2)。没有修改核心实现、测试或旧版全量回归产物。
