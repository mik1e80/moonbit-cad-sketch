///|
test "checked builders reject invalid input without consuming handles" {
  let s = @sketch.Sketch::new()
  assert_true(s.try_add_point(0.0 / 0.0, 0.0) is Err(InvalidGeometry(_)))
  assert_true(s.try_add_point(1.0e101, 0.0) is Err(InvalidGeometry(_)))
  let a = s.try_add_point(0.0, 0.0).unwrap()
  let b = s.try_add_point(1.0, 0.0).unwrap()
  assert_eq(a.index, 0)
  let foreign = @sketch.Sketch::new().add_point(0.0, 0.0)
  assert_true(s.try_add_line(a, foreign) is Err(ForeignHandle))
  assert_true(s.try_add_line(a, a) is Err(DegenerateLine(_)))
  assert_eq(s.try_add_line(a, b).unwrap().index, 0)
  assert_true(s.try_add_circle(foreign, 1.0) is Err(ForeignHandle))
  assert_true(s.try_add_circle(a, -1.0) is Err(InvalidRadius(_)))
  assert_eq(s.try_add_circle(a, 1.0).unwrap().index, 0)
  assert_true(s.try_constrain(Distance(a, foreign, 1.0)) is Err(ForeignHandle))
  assert_true(
    s.try_constrain(Distance(a, b, -1.0)) is Err(InvalidConstraint(_)),
  )
  assert_eq(s.try_constrain(Distance(a, b, 1.0)).unwrap().index(), 0)
  assert_true(s.solve().unwrap().report.is_satisfied())
}

///|
test "checked builders bound combined point and circle storage" {
  let s = @sketch.Sketch::new()
  let a = s.try_add_point(0.0, 0.0).unwrap()
  for _ in 0..<254 {
    s.try_add_circle(a, 1.0).unwrap() |> ignore
  }
  assert_true(s.try_add_point(1.0, 0.0) is Err(ResourceLimit))
  assert_true(s.try_add_circle(a, 1.0) is Err(ResourceLimit))
  let svg = s.to_svg().unwrap()
  assert_true(svg.contains("data-circle=\"253\""))
  assert_false(svg.contains("data-circle=\"254\""))
}

///|
test "checked constraints free live capacity without reusing identifiers" {
  let s = @sketch.Sketch::new()
  let a = s.try_add_point(0.0, 0.0).unwrap()
  let first = s.try_constrain(Fix(a, 0.0, 0.0)).unwrap()
  for _ in 1..<512 {
    s.try_constrain(Fix(a, 0.0, 0.0)).unwrap() |> ignore
  }
  assert_true(s.try_constrain(Fix(a, 0.0, 0.0)) is Err(ResourceLimit))
  assert_true(s.set_constraint_enabled(first, false))
  assert_true(s.try_constrain(Fix(a, 0.0, 0.0)) is Err(ResourceLimit))
  assert_true(s.remove_constraint(first))
  assert_eq(s.try_constrain(Fix(a, 0.0, 0.0)).unwrap().index(), 512)
}

///|
test "linear solve budget is observable and failure does not apply geometry" {
  let s = @sketch.Sketch::new()
  let p = s.add_point(1.0, 1.0)
  s.constrain(Fix(p, 5.0, 3.0)) |> ignore
  let r = s.solve_and_apply(max_linear_solves=1).unwrap().report
  assert_true(r.status is BudgetLimit)
  assert_eq(r.linear_solves, 1)
  assert_eq(s.point(p).unwrap().x, 1.0)
  assert_eq(s.point(p).unwrap().y, 1.0)
  let solved = s.solve_and_apply().unwrap().report
  assert_true(solved.is_satisfied())
  assert_true(solved.linear_solves > 1 && solved.linear_solves <= 400)
  assert_eq(s.solve(max_linear_solves=1).unwrap().report.linear_solves, 0)
}

///|
test "linear solve and damping budgets validate before work" {
  let s = @sketch.Sketch::new()
  assert_true(s.solve(max_linear_solves=0) is Err(InvalidOptions(_)))
  assert_true(s.solve(max_linear_solves=4001) is Err(InvalidOptions(_)))
  assert_true(s.solve(max_damping_attempts=0) is Err(InvalidOptions(_)))
  assert_true(s.solve(max_damping_attempts=17) is Err(InvalidOptions(_)))
}

///|
test "svg title limit counts UTF16 units before escaping" {
  let s = @sketch.Sketch::new()
  let title = StringBuilder()
  for _ in 0..<2048 {
    title.write_string("😀")
  }
  assert_true(
    s.to_svg(options={
      ..@sketch.SvgOptions::default(),
      title: title.to_string(),
    })
    is Ok(_),
  )
  title.write_char('&')
  assert_true(
    s.to_svg(options={
      ..@sketch.SvgOptions::default(),
      title: title.to_string(),
    })
    is Err(InvalidOptions(_)),
  )
}

///|
test "singular norm initializations report stagnation without applying" {
  for kind in 0..<3 {
    let s = @sketch.Sketch::new()
    let a = s.add_point(0.0, 0.0)
    let b = s.add_point(0.0, 0.0)
    match kind {
      0 => s.constrain(Distance(a, b, 3.0)) |> ignore
      1 => {
        let c = s.add_circle(a, 3.0)
        s.constrain(Radius(c, 3.0)) |> ignore
        s.constrain(PointOnCircle(b, c)) |> ignore
      }
      _ => {
        let ca = s.add_circle(a, 3.0)
        let cb = s.add_circle(b, 2.0)
        s.constrain(Radius(ca, 3.0)) |> ignore
        s.constrain(Radius(cb, 2.0)) |> ignore
        s.constrain(ExternalTangent(ca, cb)) |> ignore
      }
    }
    let report = s.solve_and_apply(max_linear_solves=8).unwrap().report
    assert_false(report.is_satisfied())
    assert_true(report.status is (Stalled | BudgetLimit))
    assert_true(report.unsatisfied().length() > 0)
    assert_true(report.linear_solves <= 8)
    assert_eq(s.point(a).unwrap().x, 0.0)
    assert_eq(s.point(b).unwrap().x, 0.0)
  }
}
