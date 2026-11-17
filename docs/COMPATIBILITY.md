# 0.3.x → 0.4.0 迁移与兼容性

0.4.0 扩展公开枚举和报告结构，是 0.x 阶段可见接口变更。调用方对 Constraint、SketchError、SolveStopReason 等做穷尽匹配时需增加新分支；不要把整个记录或枚举当作稳定序列化协议。

- PointId / LineId / CircleId 的 index 变为稳定创建编号，删除后不再等于内部数组下标。ArcId 同样如此。只使用公开查询接口，不自行解引用编号。
- Solution 保存独立几何快照；旧快照可查询后来被删除的对象，不能查询后来才创建的对象。
- 既有 24 种关系和 SolveStatus 四种分类保留；新增 13 种关系，以及 InvalidArc / GeometryInUse 等错误。
- SolveReport 新增几何内置残差、逐方程来源、停止原因、初始最大容差比、接受/拒绝步数和最终阻尼。内置弧方程参与 rank、DOF、满意判定，但不进入用户 constraint_residuals。
- SVG 的既有 SvgOptions 记录不变，to_svg 新增可选 show_construction、arc_tolerance。显示不是文件交换协议；不承诺浮点文本逐字稳定。
- 参考测量是只读方法，不等同可编辑驱动约束。构造角色只控制显示，不能禁用几何内置方程。
- try_add_rectangle 只创建几何；需要调用方添加设计关系。

要求 moonc >=0.10.17，使用匹配 core。锁定的 0.10.17+d971670cd 为本轮验证工具链；较新编译器、macOS、浏览器集成和嵌入式宿主未因最低版本声明而自动取得验证。四后端可移植性仍受宿主运行环境限制，资源预算不是实时或内存隔离保证。发布回归和安装结果见 [验证记录](COMPLETENESS_VALIDATION.md)。

