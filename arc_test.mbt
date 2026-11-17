///|
fn arc_near(
  actual : Double,
  expected : Double,
  tolerance~ : Double = 2.0e-6,
) -> Unit raise {
  assert_true((actual - expected).abs() <= tolerance)
}

///|
test "64 analytic arcs preserve direction, sweep, radius and provenance" {
  for i in 0..<64 {
    let s = @sketch.Sketch::new()
    let cx = (i - 30).to_double() * 0.7
    let cy = (i % 9).to_double() * -1.3
    let r = [0.01, 1.0, 100.0][i % 3]
    let start = i.to_double() * 0.29 - 3.2
    let sweep = 0.15 + (i % 23).to_double() * 0.26
    let sign = if i % 2 == 0 { 1.0 } else { -1.0 }
    let dir = if sign > 0.0 {
      @sketch.CounterClockwise
    } else {
      @sketch.Clockwise
    }
    let c = s.try_add_point(cx, cy).unwrap()
    let a = s
      .try_add_point(cx + r * @math.cos(start), cy + r * @math.sin(start))
      .unwrap()
    let b = s
      .try_add_point(
        cx + r * @math.cos(start + sign * sweep),
        cy + r * @math.sin(start + sign * sweep),
      )
      .unwrap()
    let arc = s.try_add_arc(c, a, b, dir).unwrap()
    let result = s.solve().unwrap()
    assert_true(result.report.is_satisfied())
    assert_eq(result.report.variables, 6)
    assert_eq(result.report.equations, 1)
    assert_eq(result.report.local_dof, 5)
    assert_true(result.report.equation_residuals[0].origin is ArcEquation(_))
    assert_eq(result.report.geometry_residuals.length(), 1)
    arc_near(result.arc(arc).unwrap().radius(), r)
    arc_near(result.arc(arc).unwrap().sweep(), sweep)
    arc_near(
      result.measure(@sketch.ArcLengthValue(arc)).unwrap(),
      r * sweep,
      tolerance=1.0e-5,
    )
    assert_true(result.arc(arc).unwrap().direction == dir)
    let svg = s.to_svg().unwrap()
    assert_true(svg.contains("data-arc=\"0\""))
    let flags = if sweep > @math.PI {
      if sign > 0.0 {
        " 0 1 0 "
      } else {
        " 0 1 1 "
      }
    } else if sign > 0.0 {
      " 0 0 0 "
    } else {
      " 0 0 1 "
    }
    assert_true(svg.contains(flags))
  }
}

///|
test "128 seeded perturbations solve radius and sweep across angle branches" {
  let mut state = 20261117U
  for i in 0..<128 {
    state = state * 1664525U + 1013904223U
    let perturb = (state % 101U).reinterpret_as_int().to_double() / 1000.0 -
      0.05
    let s = @sketch.Sketch::new()
    let r = [0.1, 1.0, 10.0][i % 3]
    let cx = (i % 7).to_double() * r
    let cy = (i % 5).to_double() * -r
    let angle = i.to_double() * 0.171 - 3.3
    let sweep = 0.25 + (i % 29).to_double() * 0.19
    let sign = if i % 2 == 0 { 1.0 } else { -1.0 }
    let c = s.try_add_point(cx + perturb * r, cy - perturb * r).unwrap()
    let a = s
      .try_add_point(cx + r * @math.cos(angle), cy + r * @math.sin(angle))
      .unwrap()
    let b = s
      .try_add_point(
        cx + r * (1.0 + perturb) * @math.cos(angle + sign * (sweep + perturb)),
        cy + r * (1.0 + perturb) * @math.sin(angle + sign * (sweep + perturb)),
      )
      .unwrap()
    let arc = s
      .try_add_arc(
        c,
        a,
        b,
        if sign > 0.0 {
          @sketch.CounterClockwise
        } else {
          @sketch.Clockwise
        },
      )
      .unwrap()
    s.try_constrain(Fix(c, cx, cy)).unwrap() |> ignore
    s
    .try_constrain(Fix(a, cx + r * @math.cos(angle), cy + r * @math.sin(angle)))
    .unwrap()
    |> ignore
    s.try_constrain(ArcRadius(arc, r)).unwrap() |> ignore
    s.try_constrain(ArcSweep(arc, sweep)).unwrap() |> ignore
    let result = s.solve_and_apply().unwrap()
    assert_true(result.report.is_satisfied())
    let actual = result.point(b).unwrap()
    arc_near(actual.x, cx + r * @math.cos(angle + sign * sweep))
    arc_near(actual.y, cy + r * @math.sin(angle + sign * sweep))
    assert_true(result.report.geometry_residuals[0].tolerance_ratio <= 1.0)
  }
}

///|
test "128 mixed arc line circle models solve with shared endpoint tangency" {
  for i in 0..<128 {
    let s = @sketch.Sketch::new()
    let r = 0.5 + (i % 17).to_double() * 0.2
    let ox = (i % 8).to_double() * 3.0
    let oy = (i % 7).to_double() * -2.0
    let c = s.try_add_point(ox, oy).unwrap()
    let a = s.try_add_point(ox + r, oy).unwrap()
    let b = s.try_add_point(ox + 0.02 * r, oy + 0.97 * r).unwrap()
    let end = s.try_add_point(ox + r, oy + 1.03 * r).unwrap()
    let arc = s.try_add_arc(c, a, b, @sketch.CounterClockwise).unwrap()
    let line = s.try_add_line(b, end).unwrap()
    let circle = s.try_add_circle(c, 0.9 * r).unwrap()
    s.try_constrain(Fix(c, ox, oy)).unwrap() |> ignore
    s.try_constrain(Fix(a, ox + r, oy)).unwrap() |> ignore
    s.try_constrain(ArcSweep(arc, @math.PI / 2.0)).unwrap() |> ignore
    s.try_constrain(EqualCircleArcRadius(circle, arc)).unwrap() |> ignore
    s.try_constrain(ArcTangentAt(line, arc, @sketch.End)).unwrap() |> ignore
    s.try_constrain(Distance(b, end, r)).unwrap() |> ignore
    let result = s.solve_and_apply().unwrap()
    assert_true(result.report.is_satisfied())
    arc_near(result.point(b).unwrap().x, ox)
    arc_near(result.point(b).unwrap().y, oy + r)
    arc_near(result.point(end).unwrap().x, ox + r)
    arc_near(result.point(end).unwrap().y, oy + r)
    arc_near(result.radius(circle).unwrap(), r)
  }
}

///|
test "arc diameter editing and conflict keep previous geometry" {
  let s = @sketch.Sketch::new()
  let c = s.try_add_point(0.0, 0.0).unwrap()
  let a = s.try_add_point(2.0, 0.0).unwrap()
  let b = s.try_add_point(0.0, 2.0).unwrap()
  let axis = s.try_add_line(c, a).unwrap()
  let arc = s.try_add_arc(c, a, b, @sketch.CounterClockwise).unwrap()
  s.try_constrain(Fix(c, 0.0, 0.0)).unwrap() |> ignore
  s.try_constrain(Horizontal(axis)).unwrap() |> ignore
  let dim = s.try_constrain(ArcDiameter(arc, 4.0)).unwrap()
  s.try_constrain(ArcSweep(arc, @math.PI / 2.0)).unwrap() |> ignore
  assert_true(s.solve_and_apply().unwrap().report.is_satisfied())
  s.try_set_constraint(dim, ArcDiameter(arc, 6.0)).unwrap()
  assert_true(s.solve_and_apply().unwrap().report.is_satisfied())
  arc_near(s.arc_radius(arc).unwrap(), 3.0)
  let before = s.point(b).unwrap()
  let conflict = s.try_constrain(ArcRadius(arc, 7.0)).unwrap()
  assert_false(s.solve_and_apply().unwrap().report.is_satisfied())
  assert_eq(s.point(b).unwrap().x, before.x)
  assert_eq(s.point(b).unwrap().y, before.y)
  assert_true(s.remove_constraint(conflict))
  assert_true(s.solve_and_apply().unwrap().report.is_satisfied())
}

///|
test "finite arc membership rejects the supporting circle outside the sweep" {
  for dir in [@sketch.CounterClockwise, @sketch.Clockwise] {
    let s = @sketch.Sketch::new()
    let sign = if dir == @sketch.CounterClockwise { 1.0 } else { -1.0 }
    let c = s.try_add_point(0.0, 0.0).unwrap()
    let a = s.try_add_point(1.0, 0.0).unwrap()
    let b = s.try_add_point(0.0, sign).unwrap()
    let arc = s.try_add_arc(c, a, b, dir).unwrap()
    for (p, x, y) in [(c, 0.0, 0.0), (a, 1.0, 0.0), (b, 0.0, sign)] {
      s.try_constrain(Fix(p, x, y)).unwrap() |> ignore
    }
    let p = s.try_add_point(-0.2, sign * 1.1).unwrap()
    s.try_constrain(PointOnArc(p, arc)).unwrap() |> ignore
    let report = s.solve_and_apply().unwrap().report
    if !report.is_satisfied() {
      println("\{Repr(report)}")
    }
    assert_true(report.is_satisfied())
    arc_near(s.point(p).unwrap().x, 0.0)
    arc_near(s.point(p).unwrap().y, sign)
    s.try_constrain(Fix(p, -1.0, 0.0)).unwrap() |> ignore
    assert_false(s.solve_and_apply().unwrap().report.is_satisfied())
  }
}
