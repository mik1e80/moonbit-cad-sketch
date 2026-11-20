# 0.4.1 兼容性与 0.3.x 迁移

0.4.1 保留 0.4.0 的公开 API 和运行时。0.4.0 扩展公开枚举和报告结构，是 0.x 阶段可见接口变更。调用方对 Constraint、SketchError、SolveStopReason 等做穷尽匹配时需增加新分支；不要把整个记录或枚举当作稳定序列化协议。

- PointId / LineId / CircleId 的 index 变为稳定创建编号，删除后不再等于内部数组下标。ArcId 同样如此。只使用公开查询接口，不自行解引用编号。
- Solution 保存独立几何快照；旧快照可查询后来被删除的对象，不能查询后来才创建的对象。
- 既有 24 种关系和 SolveStatus 四种分类保留；新增 13 种关系，以及 InvalidArc / GeometryInUse 等错误。
- SolveReport 新增几何内置残差、逐方程来源、停止原因、初始最大容差比、接受/拒绝步数和最终阻尼。内置弧方程参与 rank、DOF、满意判定，但不进入用户 constraint_residuals。
- SVG 的既有 SvgOptions 记录不变，to_svg 新增可选 show_construction、arc_tolerance。显示不是文件交换协议；不承诺浮点文本逐字稳定。
- 参考测量是只读方法，不等同可编辑驱动约束。构造角色只控制显示，不能禁用几何内置方程。
- try_add_rectangle 只创建几何；需要调用方添加设计关系。

要求 moonc >=0.10.17，使用匹配 core。锁定的 0.10.17+d971670cd 为本轮验证工具链；较新编译器、macOS、浏览器集成和嵌入式宿主未因最低版本声明而自动取得验证。四后端可移植性仍受宿主运行环境限制，资源预算不是实时或内存隔离保证。发布回归和安装结果见 [验证记录](COMPLETENESS_VALIDATION.md)。

| 环境 | 已验证范围 |
| --- | --- |
| Ubuntu x64，固定的 0.10.17+d971670cd 与匹配 core | 0.4.1 四后端完整 CI、归档工作区与公开 API 测试 |
| Windows x64，0.10.17+d971670cd | 0.4.1 本机发布回归。新增专项四后端测试、独立 JS 案例及 Windows 2025 的 JS 检查通过 |
| macOS 15 ARM64，0.10.17+d971670cd | JS 编译与公开示例、维护专项检查通过 |
| Ubuntu x64，0.10.22+124d61d05 | JS 编译与公开示例、维护专项检查通过。此探测豁免旧 derive 语法的 0027 弃用诊断，其余警告仍视为错误 |
| 浏览器宿主 | 尚无单独验证记录。 |

[兼容性探测](https://github.com/mik1e80/moonbit-cad-sketch/actions/workflows/compatibility.yml)只在修改该工作流的 PR 上自动触发，亦可按需手动运行。工具链与匹配 core 使用精确版本和 SHA-256。三组配置在 [2026-11-20 的运行](https://github.com/mik1e80/moonbit-cad-sketch/actions/runs/44743293500)通过。更换稳定快照时同步复核两个归档的指纹。

[首次稳定版检查](https://github.com/mik1e80/moonbit-cad-sketch/actions/runs/44742906952)因旧的后置 derive 被编译器弃用而未通过严格检查。最低编译器尚不支持新的前置属性，因此保留兼容语法并只在 0.10.22 探测豁免 0027。平台结果仅覆盖各自列出的工具链与 JS 后端。

实测开发工具限制：Windows 深目录下运行独立 .mbtx 脚本可能因依赖的编译输出路径过长报错；使用较短 checkout 或显式 --target-dir 可绕过。全新开发环境先 moon update 取得开发脚本依赖索引；核心库只需匹配 core，CI 直接运行示例，不依赖脚本网络索引。

