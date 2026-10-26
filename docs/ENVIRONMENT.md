# Windows 环境准备与排查

项目最低要求 `moonc >= 0.10.15`。2026-10-26 本机修复与轻量验证使用 `moonc 0.10.17+d971670cd`、匹配版本的 MoonBit core；工具链来自官方 Windows 发布包。

## 官方安装与版本检查

参考 [MoonBit 官方下载页](https://www.moonbitlang.com/download)。PowerShell 安装入口：

```powershell
irm https://cli.moonbitlang.com/install/powershell.ps1 | iex
Get-Command moon
moon version --all
```

运行前可先下载并阅读脚本；若本机执行策略阻止运行，按官方说明处理。更新已有安装前应备份工具链，保留注册表登录凭据；不要将凭据或工具链二进制提交到项目仓库。更新后重开终端或编辑器，使其使用新安装。

## 编译器与标准库必须匹配

若报 `lazy.mi` 等标准库文件缺失、虚拟包接口缺失，先用 `Get-Command moon`、`moon version --all` 检查实际运行路径，并检查是否设置了指向旧安装的 `MOON_HOME`。这类错误不应直接解释为项目源码不兼容。

从官方安装包同时恢复编译器和匹配版本的 core，并重新 bundle 标准库；不要跨版本复制单个 `.mi` 文件或复用另一版 core 的 `_build` 缓存。官方安装脚本已包含恢复 core 与 bundle 的步骤。库源码无需因此改写。

Windows 上若发布预检解包后的深层 `target/.../*.typechecked` 文件无法写出，也应检查路径长度。`moon publish` 会再增加解包和检查目录，建议在较短的仓库或临时目录执行发布；确认编译器、标准库和路径后再判断源码错误。

## 必要的轻量验证

在项目根目录运行：

```sh
moon fmt --check
moon check --target js --deny-warn
moon build --target js
moon test README.mbt.md --target js --deny-warn
moon test svg_test.mbt --target js --deny-warn
moon run examples/basic --target js
python scripts/check_package.py
```

README 与 SVG 分别执行 7 项和 9 项定向测试；源码包检查默认仅执行 5 项消费测试。本次不重跑库全量回归、四后端测试矩阵、400 / 1000 模型实验或四档计时；`v0.2.1` 的[完整回归记录](releases/0.2.1-full-regression.json)仍对应原 tag。0.2.2 没有修改核心实现或测试。

## 可选的 Agent 开发技能

[MoonBit 官方技能](https://github.com/moonbitlang/skills)可按其 README 安装到个人 `.agents/skills` 目录；这是开发辅助，不是核心库的依赖或使用前置条件。技能文件无需复制进发布包。
