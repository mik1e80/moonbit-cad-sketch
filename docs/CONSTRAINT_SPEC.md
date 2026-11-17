# 关系规格索引

0.4.0 共有 **37 种用户 Constraint 构造器**，另有每条 Arc 一个始终启用的内置等半径方程。禁用仅作用于用户关系，不关闭几何有效性检查或内置方程。

原有 24 种关系的方程、直线无限延伸语义、方向和退化定义见 [CONSTRAINTS](CONSTRAINTS.md)。新增关系如下；长度沿用统一单位，方向/角度使用 angle_tolerance，其余使用 length_tolerance。

| 构造器 | 方程 / 定义域 |
| --- | --- |
| Diameter(circle,d) | 2r-d；d>0 |
| ArcRadius(arc,r) | 起点半径-r；r>0 |
| ArcDiameter(arc,d) | 2×起点半径-d；d>0 |
| ArcSweep(arc,theta) | 指定方向正扫掠角-theta；1e-12<theta<2π-1e-12 |
| ArcLength(arc,l) | 起点半径×扫掠角-l；l>0 |
| EqualArcRadius(a,b) | 两圆弧起点半径差 |
| EqualCircleArcRadius(c,a) | 圆半径与圆弧起点半径差 |
| ArcConcentric(a,b) | 圆心坐标差，两个长度分量 |
| CircleArcConcentric(c,a) | 圆与圆弧圆心差，两个长度分量 |
| ArcTangentAt(line,arc,endpoint) | 必须共享所选端点 ID；线方向与半径归一化点积为零 |
| ArcArcTangentAt(a,endpoint,b,endpoint) | 必须共享所选端点 ID；归一化半径叉积为零 |
| ArcCircleTangentAt(arc,endpoint,circle) | 端点在圆上 + 归一化半径叉积为零 |
| PointOnArc(point,arc) | 点到有限弧最近投影点的二维长度差；拒绝圆心初值 |

相切不限定正反行进方向，不证明曲率连续。PointOnArc 是分段光滑投影，端点/分支切换不保证光滑性或全局收敛。细节与 SVG 语义见 [圆弧合同](ARC_DESIGN.md)。checked 添加检查定义，不验证关系可同时满足；不等式、条件约束、优先级软约束均不支持。

