///|
test "arc input limits and invalid edits preserve geometry and IDs" {
  let s = @sketch.Sketch::new()
  let c = s.try_add_point(0.0, 0.0).unwrap()
  let a = s.try_add_point(1.0, 0.0).unwrap()
  let b = s.try_add_point(0.0, 1.0).unwrap()
  assert_true(
    s.try_add_arc(c, c, b, @sketch.CounterClockwise) is Err(InvalidArc(_)),
  )
  assert_true(
    s.try_add_arc(c, a, a, @sketch.CounterClockwise) is Err(InvalidArc(_)),
  )
  let foreign = @sketch.Sketch::new().try_add_point(0.0, 0.0).unwrap()
  assert_true(
    s.try_add_arc(foreign, a, b, @sketch.CounterClockwise) is Err(ForeignHandle),
  )
  let arc = s.try_add_arc(c, a, b, @sketch.CounterClockwise).unwrap()
  assert_eq(arc.index, 0)
  assert_true(
    s.try_set_arc(arc, c, a, a, @sketch.Clockwise) is Err(InvalidArc(_)),
  )
  assert_true(s.arc(arc).unwrap().direction is CounterClockwise)
  for _ in 1..<128 {
    s.try_add_arc(c, a, b, @sketch.CounterClockwise).unwrap() |> ignore
  }
  assert_true(
    s.try_add_arc(c, a, b, @sketch.CounterClockwise) is Err(ResourceLimit),
  )
  assert_true(s.remove_arc(arc).unwrap())
  assert_true(
    s.try_add_arc(c, a, b, @sketch.CounterClockwise).unwrap().index > 127,
  )
}

///|
test "arc intrinsic equations are mandatory and unsuccessful export rejects unequal radii" {
  let s = @sketch.Sketch::new()
  let c = s.try_add_point(0.0, 0.0).unwrap()
  let a = s.try_add_point(1.0, 0.0).unwrap()
  let b = s.try_add_point(0.0, 2.0).unwrap()
  let arc = s.try_add_arc(c, a, b, @sketch.CounterClockwise).unwrap()
  assert_true(s.to_svg() is Err(InvalidArc(_)))
  for (p, x, y) in [(c, 0.0, 0.0), (a, 1.0, 0.0), (b, 0.0, 2.0)] {
    s.try_constrain(Fix(p, x, y)).unwrap() |> ignore
  }
  let candidate = s.solve_and_apply().unwrap()
  assert_false(candidate.report.is_satisfied())
  assert_true(candidate.report.geometry_residuals[0].tolerance_ratio > 1.0)
  assert_eq(s.point(b).unwrap().y, 2.0)
  assert_true(s.remove_point(b) is Err(GeometryInUse(_)))
  assert_true(s.arc(arc) is Some(_))
}

///|
test "arc snapshot, deleted slots and construction SVG remain consistent" {
  let s = @sketch.Sketch::new()
  let extra = s.try_add_point(9.0, 9.0).unwrap()
  let c = s.try_add_point(0.0, 0.0).unwrap()
  let a = s.try_add_point(1.0, 0.0).unwrap()
  let b = s.try_add_point(0.0, 1.0).unwrap()
  let arc = s.try_add_arc(c, a, b, @sketch.CounterClockwise).unwrap()
  let old = s.solve().unwrap()
  assert_true(s.remove_point(extra).unwrap())
  assert_eq(s.arc_radius(arc), Some(1.0))
  s
  .set_geometry_role(@sketch.ArcGeometry(arc), @sketch.ConstructionGeometry)
  .unwrap()
  assert_true(s.to_svg().unwrap().contains("data-arc=\"0\""))
  assert_false(
    s.to_svg(show_construction=false).unwrap().contains("data-arc=\"0\""),
  )
  assert_true(s.remove_arc(arc).unwrap())
  assert_eq(old.arc(arc).unwrap().radius(), 1.0)
  assert_true(s.arc(arc) is None)
  assert_true(s.remove_point(a).unwrap())
  assert_eq(old.point(a).unwrap().x, 1.0)
}

///|
test "shared endpoint tangency and circle arc equality constrain real geometry" {
  let s = @sketch.Sketch::new()
  let c1 = s.try_add_point(0.0, 0.0).unwrap()
  let a1 = s.try_add_point(2.0, 0.0).unwrap()
  let shared = s.try_add_point(0.0, 2.0).unwrap()
  let c2 = s.try_add_point(0.0, 4.0).unwrap()
  let e2 = s.try_add_point(2.0, 4.0).unwrap()
  let circle_center = s.try_add_point(0.0, 5.0).unwrap()
  let first = s.try_add_arc(c1, a1, shared, @sketch.CounterClockwise).unwrap()
  let second = s.try_add_arc(c2, shared, e2, @sketch.CounterClockwise).unwrap()
  let circle = s.try_add_circle(circle_center, 3.0).unwrap()
  for
    (p, x, y) in [
      (c1, 0.0, 0.0),
      (a1, 2.0, 0.0),
      (shared, 0.0, 2.0),
      (c2, 0.0, 4.0),
      (e2, 2.0, 4.0),
      (circle_center, 0.0, 5.0),
    ] {
    s.try_constrain(Fix(p, x, y)).unwrap() |> ignore
  }
  s
  .try_constrain(ArcArcTangentAt(first, @sketch.End, second, @sketch.Start))
  .unwrap()
  |> ignore
  s.try_constrain(EqualArcRadius(first, second)).unwrap() |> ignore
  s.try_constrain(ArcCircleTangentAt(first, @sketch.End, circle)).unwrap()
  |> ignore
  s.try_constrain(ArcLength(first, 3.141592653589793)).unwrap() |> ignore
  s.try_constrain(Diameter(circle, 6.0)).unwrap() |> ignore
  assert_true(s.solve_and_apply().unwrap().report.is_satisfied())
  assert_true(
    s.try_constrain(ArcArcTangentAt(first, @sketch.Start, second, @sketch.End))
    is Err(InvalidConstraint(_)),
  )
  let line = s.try_add_line(shared, e2).unwrap()
  let tangent = s.try_constrain(ArcTangentAt(line, first, @sketch.End)).unwrap()
  assert_true(
    s.try_set_arc(first, c1, a1, e2, @sketch.CounterClockwise)
    is Err(InvalidArc(_)),
  )
  assert_true(s.constraint(tangent) is Some(_))
}
