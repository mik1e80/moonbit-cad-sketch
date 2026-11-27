# Windows 环境准备与排查

当前维护源码与 CI 使用 `moonc 1.0.0-rc1+3c0520448` 及匹配的 MoonBit core。已发布的 0.4.1 也已使用同一 RC 从 Mooncakes 独立安装验证。旧版工具链记录见[兼容性](COMPATIBILITY.md)。

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

这些命令适用于日常环境检查。四后端完整回归、模型验证及发布包验证见[验收记录](ACCEPTANCE.md)。

## 可选的 Agent 开发技能

[MoonBit 官方技能](https://github.com/moonbitlang/skills)可按其 README 安装到个人 `.agents/skills` 目录；这是开发辅助，不是核心库的依赖或使用前置条件。技能文件无需复制进发布包。
