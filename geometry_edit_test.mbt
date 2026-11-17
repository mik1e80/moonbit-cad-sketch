///|
test "geometry deletion preserves stable IDs and historical measurements" {
  let s = @sketch.Sketch::new()
  let unused = s.try_add_point(99.0, 99.0).unwrap()
  let a = s.try_add_point(0.0, 0.0).unwrap()
  let b = s.try_add_point(3.0, 4.0).unwrap()
  let line = s.try_add_line(a, b).unwrap()
  let circle = s.try_add_circle(a, 2.0).unwrap()
  let old = s.solve().unwrap()
  assert_true(s.remove_point(unused).unwrap())
  assert_eq(s.measure(@sketch.LineLength(line)).unwrap(), 5.0)
  assert_eq(s.radius(circle), Some(2.0))
  assert_true(s.remove_point(a) is Err(GeometryInUse(_)))
  assert_true(s.remove_line(line).unwrap())
  assert_true(s.remove_circle(circle).unwrap())
  assert_true(s.remove_point(a).unwrap())
  assert_true(s.point(a) is None)
  assert_eq(old.point(a).unwrap().x, 0.0)
  assert_eq(old.measure(@sketch.LineLength(line)).unwrap(), 5.0)
  assert_eq(old.radius(circle), Some(2.0))
  let fresh = s.try_add_point(9.0, 10.0).unwrap()
  assert_true(fresh.index > b.index)
  assert_true(old.point(fresh) is None)
  assert_eq(s.point(b).unwrap().x, 3.0)
  assert_true(s.solve_and_apply().unwrap().report.is_satisfied())
}

///|
test "disabled constraints block deletion until explicitly removed" {
  let s = @sketch.Sketch::new()
  let p = s.try_add_point(1.0, 2.0).unwrap()
  let c = s.try_add_circle(p, 1.0).unwrap()
  let relation = s.try_constrain(Radius(c, 1.0)).unwrap()
  assert_true(s.set_constraint_enabled(relation, false))
  assert_true(s.remove_circle(c) is Err(GeometryInUse(_)))
  assert_eq(s.radius(c), Some(1.0))
  assert_true(s.remove_constraint(relation))
  assert_true(s.remove_circle(c).unwrap())
  assert_false(s.remove_circle(c).unwrap())
  assert_true(s.remove_point(p).unwrap())
  let other = @sketch.Sketch::new().try_add_point(0.0, 0.0).unwrap()
  assert_true(s.remove_point(other) is Err(ForeignHandle))
}

///|
test "construction roles affect display but not equations or measurements" {
  let s = @sketch.Sketch::new()
  let rectangle = s.try_add_rectangle(0.0, 0.0, 10.0, 6.0).unwrap()
  let line = rectangle.edges[0]
  let relation = s.try_constrain(Horizontal(line)).unwrap()
  s
  .set_geometry_role(@sketch.LineGeometry(line), @sketch.ConstructionGeometry)
  .unwrap()
  let before = s.solve().unwrap().report
  let visible = s.to_svg().unwrap()
  let hidden = s.to_svg(show_construction=false).unwrap()
  assert_true(visible.contains("data-construction=\"true\""))
  assert_false(hidden.contains("data-line=\"0\""))
  assert_true(hidden.contains("data-line=\"1\""))
  assert_eq(s.measure(@sketch.LineLength(line)).unwrap(), 10.0)
  assert_eq(s.solve().unwrap().report.equations, before.equations)
  assert_true(s.constraint(relation) is Some(Horizontal(_)))
  assert_true(s.remove_line(line) is Err(GeometryInUse(_)))
}

///|
test "reference dimensions add no equations and snapshots survive edits" {
  let s = @sketch.Sketch::new()
  let a = s.try_add_point(0.0, 0.0).unwrap()
  let b = s.try_add_point(3.0, 0.0).unwrap()
  let c = s.try_add_point(0.0, 4.0).unwrap()
  let ab = s.try_add_line(a, b).unwrap()
  let ac = s.try_add_line(a, c).unwrap()
  let circle = s.try_add_circle(a, 2.0).unwrap()
  let solved = s.solve().unwrap()
  assert_eq(s.measure(@sketch.CircleDiameter(circle)).unwrap(), 4.0)
  assert_eq(s.measure(@sketch.CircleRadius(circle)).unwrap(), 2.0)
  assert_true(
    (s.measure(@sketch.LineAngle(ab, ac)).unwrap() - 1.5707963267948966).abs() <
    1.0e-12,
  )
  assert_eq(s.solve().unwrap().report.equations, 0)
  s.try_set_point(b, { x: 7.0, y: 0.0, }).unwrap()
  assert_eq(s.measure(@sketch.LineLength(ab)).unwrap(), 7.0)
  assert_eq(solved.measure(@sketch.LineLength(ab)).unwrap(), 3.0)
  let foreign = @sketch.Sketch::new().try_add_point(0.0, 0.0).unwrap()
  assert_true(
    s.measure(@sketch.PointDistance(a, foreign)) is Err(ForeignHandle),
  )
  assert_true(
    solved.measure(@sketch.PointDistance(a, foreign)) is Err(ForeignHandle),
  )
}

///|
test "1024 geometry replacement cycles release storage and never revive handles" {
  let s = @sketch.Sketch::new()
  let retired = s.try_add_point(0.0, 0.0).unwrap()
  assert_true(s.remove_point(retired).unwrap())
  for i in 0..<1024 {
    let p = s.try_add_point(i.to_double(), 1.0).unwrap()
    assert_true(p.index > retired.index)
    assert_true(s.remove_point(p).unwrap())
  }
  assert_true(s.point(retired) is None)
  assert_eq(s.solve().unwrap().report.variables, 0)
}

///|
test "rectangle overflow and invalid corners never partially allocate" {
  let s = @sketch.Sketch::new()
  assert_true(
    s.try_add_rectangle(0.0, 0.0, -1.0, 1.0) is Err(InvalidGeometry(_)),
  )
  assert_true(
    s.try_add_rectangle(1.0e100, 0.0, 1.0, 1.0) is Err(InvalidGeometry(_)),
  )
  let first = s.try_add_point(0.0, 0.0).unwrap()
  assert_eq(first.index, 0)
  for i in 1..<125 {
    s.try_add_point(i.to_double(), 0.0).unwrap() |> ignore
  }
  assert_true(s.try_add_rectangle(0.0, 0.0, 1.0, 1.0) is Err(ResourceLimit))
  assert_eq(s.solve().unwrap().report.variables, 250)
}
