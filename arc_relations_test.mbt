///|
test "concentric arc and circle constraints move perturbed centers" {
  let s = @sketch.Sketch::new()
  let c1 = s.try_add_point(0.0, 0.0).unwrap()
  let a1 = s.try_add_point(2.0, 0.0).unwrap()
  let b1 = s.try_add_point(0.0, 2.0).unwrap()
  let c2 = s.try_add_point(0.15, -0.12).unwrap()
  let a2 = s.try_add_point(2.3, 0.01).unwrap()
  let b2 = s.try_add_point(0.1, 1.9).unwrap()
  let cc = s.try_add_point(-0.2, 0.1).unwrap()
  let first = s.try_add_arc(c1, a1, b1, @sketch.CounterClockwise).unwrap()
  let second = s.try_add_arc(c2, a2, b2, @sketch.CounterClockwise).unwrap()
  let circle = s.try_add_circle(cc, 1.8).unwrap()
  for (p, x, y) in [(c1, 0.0, 0.0), (a1, 2.0, 0.0), (b1, 0.0, 2.0)] {
    s.try_constrain(Fix(p, x, y)).unwrap() |> ignore
  }
  s.try_constrain(ArcConcentric(first, second)).unwrap() |> ignore
  s.try_constrain(CircleArcConcentric(circle, second)).unwrap() |> ignore
  s.try_constrain(EqualArcRadius(first, second)).unwrap() |> ignore
  s.try_constrain(EqualCircleArcRadius(circle, second)).unwrap() |> ignore
  s.try_constrain(ArcSweep(second, 1.5707963267948966)).unwrap() |> ignore
  let result = s.solve_and_apply().unwrap()
  assert_true(result.report.is_satisfied())
  for p in [c2, cc] {
    assert_true(s.point(p).unwrap().x.abs() < 1.0e-7)
    assert_true(s.point(p).unwrap().y.abs() < 1.0e-7)
  }
  assert_true((s.arc_radius(second).unwrap() - 2.0).abs() < 1.0e-7)
  assert_true((s.radius(circle).unwrap() - 2.0).abs() < 1.0e-7)
}

///|
test "arc length drives radius and finite membership accepts interior" {
  let s = @sketch.Sketch::new()
  let c = s.try_add_point(0.0, 0.0).unwrap()
  let a = s.try_add_point(2.0, 0.0).unwrap()
  let b = s.try_add_point(0.0, 2.0).unwrap()
  let axis = s.try_add_line(c, a).unwrap()
  let arc = s.try_add_arc(c, a, b, @sketch.CounterClockwise).unwrap()
  s.try_constrain(Fix(c, 0.0, 0.0)).unwrap() |> ignore
  s.try_constrain(Horizontal(axis)).unwrap() |> ignore
  s.try_constrain(ArcSweep(arc, 1.5707963267948966)).unwrap() |> ignore
  let length = s.try_constrain(ArcLength(arc, 3.141592653589793)).unwrap()
  assert_true(s.solve_and_apply().unwrap().report.is_satisfied())
  s.try_set_constraint(length, ArcLength(arc, 4.71238898038469)).unwrap()
  assert_true(s.solve_and_apply().unwrap().report.is_satisfied())
  assert_true((s.arc_radius(arc).unwrap() - 3.0).abs() < 1.0e-7)
  let p = s.try_add_point(2.15, 2.10).unwrap()
  s.try_constrain(PointOnArc(p, arc)).unwrap() |> ignore
  assert_true(s.solve_and_apply().unwrap().report.is_satisfied())
  let q = s.point(p).unwrap()
  assert_true(q.x > 0.0 && q.y > 0.0)
  assert_true(
    (s.measure(@sketch.PointDistance(c, p)).unwrap() - 3.0).abs() < 1.0e-7,
  )
}
