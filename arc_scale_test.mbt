///|
test "arc scales and branch margins remain explicit" {
  for r in [1.0e-9, 1.0e9] {
    for direction in [@sketch.CounterClockwise, @sketch.Clockwise] {
      let s = @sketch.Sketch::new()
      let sign = if direction == @sketch.CounterClockwise { 1.0 } else { -1.0 }
      let c = s.try_add_point(0.0, 0.0).unwrap()
      let a = s.try_add_point(r, 0.0).unwrap()
      let b = s.try_add_point(0.0, sign * r).unwrap()
      let arc = s.try_add_arc(c, a, b, direction).unwrap()
      s.try_constrain(Fix(c, 0.0, 0.0)).unwrap() |> ignore
      s.try_constrain(Fix(a, r, 0.0)).unwrap() |> ignore
      s.try_constrain(ArcSweep(arc, 1.5707963267948966)).unwrap() |> ignore
      let result = s
        .solve_and_apply(options={
          ..@sketch.SolveOptions::default(),
          length_tolerance: r * 1.0e-7,
        })
        .unwrap()
      assert_true(result.report.is_satisfied())
      assert_true((result.arc(arc).unwrap().radius() / r - 1.0).abs() < 1.0e-7)
      assert_true(s.to_svg(arc_tolerance=r * 1.0e-7) is Ok(_))
    }
  }
  let s = @sketch.Sketch::new()
  let c = s.try_add_point(0.0, 0.0).unwrap()
  let a = s.try_add_point(1.0, 0.0).unwrap()
  let nearly = s.try_add_point(1.0, 1.0e-14).unwrap()
  assert_true(
    s.try_add_arc(c, a, nearly, @sketch.CounterClockwise) is Err(InvalidArc(_)),
  )
  assert_true(
    s.try_add_arc(c, a, nearly, @sketch.Clockwise) is Err(InvalidArc(_)),
  )
  let b = s.try_add_point(0.0, 1.0).unwrap()
  let arc = s.try_add_arc(c, a, b, @sketch.CounterClockwise).unwrap()
  for invalid in [0.0, 1.0e-14, 6.283185307179586, 0.0 / 0.0] {
    assert_true(
      s.try_constrain(ArcSweep(arc, invalid)) is Err(InvalidConstraint(_)),
    )
  }
}
