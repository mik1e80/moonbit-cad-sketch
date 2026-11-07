///|
test "seeded combinations cover all 24 relations against analytic geometry" {
  let mut state = 20261107U
  let covered = Array::make(24, false)
  for sample in 0..<8 {
    let s = @sketch.Sketch::new()
    let expected : Array[@sketch.Point] = [
      { x: 0.0, y: 0.0, },
      { x: 4.0, y: 0.0, },
      { x: 4.0, y: 3.0, },
      { x: 0.0, y: 3.0, },
      { x: 2.0, y: 0.0, },
      { x: -4.0, y: 0.0, },
      { x: 3.0, y: 0.0, },
      { x: 8.0, y: 0.0, },
      { x: -4.0, y: 5.0, },
      { x: 4.0, y: 5.0, },
      { x: 0.0, y: 5.0, },
      { x: 0.0, y: 0.0, },
    ]
    let points = expected.map(p => {
      state = state * 1664525U + 1013904223U
      let dx = (state % 101U).reinterpret_as_int().to_double() / 1000.0 - 0.05
      state = state * 1664525U + 1013904223U
      let dy = (state % 101U).reinterpret_as_int().to_double() / 1000.0 - 0.05
      s.try_add_point(p.x + dx, p.y + dy).unwrap()
    })
    let a = points[0]
    let b = points[1]
    let c = points[2]
    let d = points[3]
    let ab = s.try_add_line(a, b).unwrap()
    let bc = s.try_add_line(b, c).unwrap()
    let cd = s.try_add_line(c, d).unwrap()
    let axis = s.try_add_line(a, d).unwrap()
    let tangent = s.try_add_line(points[8], points[9]).unwrap()
    let outer = s.try_add_circle(a, 5.01).unwrap()
    let same = s.try_add_circle(a, 4.99).unwrap()
    let inner = s.try_add_circle(points[6], 2.01).unwrap()
    let external = s.try_add_circle(points[7], 3.01).unwrap()
    for i, p in points {
      s.try_constrain(Fix(p, expected[i].x, expected[i].y)).unwrap() |> ignore
    }
    for pair in [(outer, 5.0), (same, 5.0), (inner, 2.0), (external, 3.0)] {
      s.try_constrain(Radius(pair.0, pair.1)).unwrap() |> ignore
    }
    let relations : Array[@sketch.Constraint] = [
      Fix(a, 0.0, 0.0),
      Coincident(a, points[11]),
      Symmetric(b, points[5], a),
      Mirror(b, points[5], axis),
      Horizontal(ab),
      Vertical(bc),
      Distance(a, c, 5.0),
      DistanceX(a, b, 4.0),
      DistanceY(a, c, 3.0),
      Parallel(ab, cd),
      Perpendicular(ab, bc),
      Angle(ab, bc, @math.PI / 2.0),
      EqualLength(ab, cd),
      LengthRatio(ab, bc, 4.0 / 3.0),
      Midpoint(points[4], ab),
      PointOnLine(b, ab),
      DistanceToLine(c, ab, 3.0),
      Radius(outer, 5.0),
      EqualRadius(outer, same),
      Concentric(outer, same),
      PointOnCircle(points[10], outer),
      Tangent(tangent, outer),
      ExternalTangent(outer, external),
      InternalTangent(outer, inner),
    ]
    let order = Array::makei(24, i => i)
    for i in 0..<23 {
      state = state * 1664525U + 1013904223U
      let j = i + (state % (24 - i).reinterpret_as_uint()).reinterpret_as_int()
      let old = order[i]
      order[i] = order[j]
      order[j] = old
    }
    for k in 0..<(if sample == 0 { 24 } else { 12 }) {
      let i = order[k]
      s.try_constrain(relations[i]).unwrap() |> ignore
      covered[i] = true
    }
    let report = s.solve_and_apply(max_linear_solves=40).unwrap().report
    assert_true(report.is_satisfied())
    assert_true(report.linear_solves <= 40)
    for i, p in points {
      let actual = s.point(p).unwrap()
      assert_true((actual.x - expected[i].x).abs() <= 1.0e-7)
      assert_true((actual.y - expected[i].y).abs() <= 1.0e-7)
    }
    for pair in [(outer, 5.0), (same, 5.0), (inner, 2.0), (external, 3.0)] {
      assert_true((s.radius(pair.0).unwrap() - pair.1).abs() <= 1.0e-7)
    }
  }
  assert_true(covered.all(x => x))
}
