///|
test "checked point and radius edits reject bad values atomically" {
  let s = @sketch.Sketch::new()
  let p = s.try_add_point(2.0, 3.0).unwrap()
  let c = s.try_add_circle(p, 4.0).unwrap()
  for value in [0.0 / 0.0, 1.0 / 0.0, -1.0 / 0.0, 1.0e101] {
    assert_true(
      s.try_set_point(p, { x: value, y: 1.0, }) is Err(InvalidGeometry(_)),
    )
    assert_true(
      s.try_set_point(p, { x: 1.0, y: value, }) is Err(InvalidGeometry(_)),
    )
    assert_true(s.try_set_radius(c, value) is Err(InvalidRadius(_)))
    assert_eq(s.point(p).unwrap().x, 2.0)
    assert_eq(s.point(p).unwrap().y, 3.0)
    assert_eq(s.radius(c).unwrap(), 4.0)
  }
  assert_true(s.try_set_radius(c, 0.0) is Err(InvalidRadius(_)))
  assert_true(s.try_set_radius(c, -1.0) is Err(InvalidRadius(_)))
  s.try_set_point(p, { x: 5.0, y: 6.0, }).unwrap()
  s.try_set_radius(c, 7.0).unwrap()
  assert_eq(s.point(p).unwrap().x, 5.0)
  assert_eq(s.radius(c).unwrap(), 7.0)
}

///|
test "checked edits reject foreign handles and removed relations" {
  let s = @sketch.Sketch::new()
  let p = s.try_add_point(0.0, 0.0).unwrap()
  let id = s.try_constrain(Fix(p, 0.0, 0.0)).unwrap()
  let other = @sketch.Sketch::new()
  let q = other.try_add_point(8.0, 9.0).unwrap()
  let circle = other.try_add_circle(q, 2.0).unwrap()
  let foreign = other.try_constrain(Fix(q, 8.0, 9.0)).unwrap()
  assert_true(s.try_set_point(q, { x: 1.0, y: 1.0, }) is Err(ForeignHandle))
  assert_true(s.try_set_radius(circle, 3.0) is Err(ForeignHandle))
  assert_true(
    s.try_set_constraint(foreign, Fix(p, 1.0, 1.0)) is Err(ForeignHandle),
  )
  assert_true(s.try_set_constraint(id, Fix(q, 1.0, 1.0)) is Err(ForeignHandle))
  assert_true(s.remove_constraint(id))
  assert_true(
    s.try_set_constraint(id, Fix(p, 1.0, 1.0)) is Err(InvalidConstraint(_)),
  )
  assert_eq(s.try_constrain(Fix(p, 0.0, 0.0)).unwrap().index(), 1)
  assert_eq(other.point(q).unwrap().x, 8.0)
  assert_eq(other.radius(circle).unwrap(), 2.0)
}

///|
test "checked relation edits preserve state and solve a new dimension" {
  let s = @sketch.Sketch::new()
  let a = s.try_add_point(0.0, 0.0).unwrap()
  let b = s.try_add_point(3.0, 0.1).unwrap()
  let line = s.try_add_line(a, b).unwrap()
  s.try_constrain(Fix(a, 0.0, 0.0)).unwrap() |> ignore
  s.try_constrain(Horizontal(line)).unwrap() |> ignore
  let dimension = s.try_constrain(Distance(a, b, 5.0)).unwrap()
  assert_true(
    s.try_set_constraint(dimension, Distance(a, b, -1.0))
    is Err(InvalidConstraint(_)),
  )
  assert_true(s.constraint(dimension) is Some(Distance(_, _, 5.0)))
  assert_true(s.set_constraint_enabled(dimension, false))
  s.try_set_constraint(dimension, Distance(a, b, 7.0)).unwrap()
  assert_eq(s.constraint_enabled(dimension), Some(false))
  assert_true(s.set_constraint_enabled(dimension, true))
  assert_true(s.solve_and_apply().unwrap().report.is_satisfied())
  assert_true((s.point(b).unwrap().x - 7.0).abs() < 1.0e-5)
  assert_true(s.point(b).unwrap().y.abs() < 1.0e-5)
}
