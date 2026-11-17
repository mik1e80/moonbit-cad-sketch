# 圆弧设计合同

Arc 引用同一草图的 center / start / end 三个 PointId 和 Clockwise / CounterClockwise 方向。共享端点通过复用 PointId 表达。三个点提供六个坐标变量，始终启用的内置长度残差为 hypot(S-C)-hypot(E-C)，独立圆弧在普通构型下有五个局部自由度。内置残差单独列为几何诊断，不占用户约束 ID。

半径取起点到圆心的距离；方向决定起点到终点的正扫掠角 theta∈(0,2π)，零弧和整圆拒绝，整圆用 Circle。半径可不同的初值由内置方程求解，但中心与任一端点重合、端点重合和尺度退化拒绝。圆弧上限 128，删除释放现存容量，ID 不复用。

ArcRadius: r-target（长度）；ArcDiameter: 2r-target（长度）；ArcSweep: theta-target（弧度）；ArcLength: r*theta-target（长度）；EqualArcRadius、EqualCircleArcRadius: 半径差（长度）；ArcConcentric / CircleArcConcentric: 两个圆心坐标差（两个长度分量）。

ArcTangentAt 在选定共享端点处要求线方向与该圆弧半径垂直，残差为归一化向量点积，使用方向容差；不约束沿曲线行进的正反方向。ArcArcTangentAt 要求选定端点共享 ID，归一化半径叉积为零；支持内/外接触，不声称曲率连续。ArcCircleTangentAt 同时约束选定端点落在圆上与径向平行。

PointOnArc 使用点到有限圆弧最近点的二维差向量，两个分量均为长度残差：扫掠范围内取径向投影，范围外取以起点半径投影得到的最近弧端点。它同时限制半径和有限扫掠范围，不能等同 PointOnCircle；圆弧端点和最近端点切换处为分段光滑，初值敏感，不保证全局收敛。导数验证避开切换点，另以行为测试覆盖边界和分支邻域；中心初值拒绝。

SVG 使用真实圆弧路径而非折线，Y 轴反转必须反转 SVG sweep flag，大弧标志以 theta>π 判定；为保守包含可使用支撑圆外接框。未求解且内置等半径未满足时不能伪造圆弧输出。
