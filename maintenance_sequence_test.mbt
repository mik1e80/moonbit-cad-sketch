// SPDX-License-Identifier: Apache-2.0

///|
fn maintenance_near(
  value : Double,
  expected : Double,
  case_label : String,
) -> Unit raise {
  assert_true(
    (value - expected).abs() <= 1.0e-6,
    msg="\{case_label}: measured \{value}, expected \{expected}",
  )
}

///|
test "seeded arc continuation across pi preserves handles and old snapshots" {
  let seed = 20261120
  let mut state = seed
  for direction in [@sketch.CounterClockwise, @sketch.Clockwise] {
    let sign = if direction == @sketch.CounterClockwise { 1.0 } else { -1.0 }
    let s = @sketch.Sketch::new()
    let c = s.try_add_point(0.0, 0.0).unwrap()
    let a = s.try_add_point(2.0, 0.0).unwrap()
    let b = s.try_add_point(-2.0, 0.0).unwrap()
    let axis = s.try_add_line(c, a).unwrap()
    let arc = s.try_add_arc(c, a, b, direction).unwrap()
    s.try_constrain(Fix(c, 0.0, 0.0)).unwrap() |> ignore
    s.try_constrain(Horizontal(axis)).unwrap() |> ignore
    let initial_radius = s.try_constrain(ArcRadius(arc, 2.0)).unwrap()
    let sweep = s.try_constrain(ArcSweep(arc, @math.PI)).unwrap()
    let old = s.solve_and_apply().unwrap()
    assert_true(old.report.is_satisfied())
    let old_ratio = old.report.max_tolerance_ratio

    for i in 0..<16 {
      // Park–Miller PRNG with a fixed seed. Alternate sides of the half turn.
      let next = 16807 * (state % 127773) - 2836 * (state / 127773)
      state = if next > 0 { next } else { next + 2147483647 }
      let unit = state.to_double() / 2147483647.0
      let r = 1.7 + 0.6 * unit
      let delta = 0.00001 + 0.03 * unit
      let angle = if i % 2 == 0 { @math.PI + delta } else { @math.PI - delta }
      let case_label = "seed=\{seed} sign=\{sign} edit=\{i} radius=\{r} sweep=\{angle}"

      let spare = s.try_add_point(9.0, 9.0).unwrap()
      let check = s.try_constrain(Fix(spare, 9.0, 9.0)).unwrap()
      assert_true(s.set_constraint_enabled(check, false))
      assert_true(s.remove_point(spare) is Err(GeometryInUse(_)))
      assert_true(s.remove_constraint(check))
      assert_true(s.remove_point(spare).unwrap())
      assert_true(s.point(spare) is None)
      let replacement = s.try_add_point(8.0, 8.0).unwrap()
      assert_true(replacement.index > spare.index)
      assert_true(s.remove_point(replacement).unwrap())

      s.try_set_constraint(initial_radius, ArcRadius(arc, r)).unwrap()
      s.try_set_constraint(sweep, ArcSweep(arc, angle)).unwrap()
      let solved = s.solve_and_apply().unwrap()
      assert_true(solved.report.is_satisfied(), msg=case_label)
      let end = s.point(b).unwrap()
      maintenance_near(end.x, r * @math.cos(angle), case_label)
      maintenance_near(end.y, sign * r * @math.sin(angle), case_label)

      assert_true(s.try_set_point(b, { x: 0.0 / 0.0, y: end.y, }) is Err(_))
      assert_eq(s.point(b).unwrap().x, end.x)
      assert_eq(s.point(b).unwrap().y, end.y)
      maintenance_near(old.arc(arc).unwrap().radius(), 2.0, case_label)
      maintenance_near(old.point(b).unwrap().x, -2.0, case_label)
      assert_eq(old.report.max_tolerance_ratio, old_ratio)
    }
  }
}

///|
test "finite arc projection changes from endpoint to interior on both sweeps" {
  for direction in [@sketch.CounterClockwise, @sketch.Clockwise] {
    let sign = if direction == @sketch.CounterClockwise { 1.0 } else { -1.0 }
    for angle in [-0.0001, 0.0001] {
      let s = @sketch.Sketch::new()
      let center = s.try_add_point(0.0, 0.0).unwrap()
      let start = s.try_add_point(1.0, 0.0).unwrap()
      let end = s.try_add_point(0.0, sign).unwrap()
      let arc = s.try_add_arc(center, start, end, direction).unwrap()
      s.try_constrain(Fix(center, 0.0, 0.0)).unwrap() |> ignore
      s.try_constrain(Fix(start, 1.0, 0.0)).unwrap() |> ignore
      s.try_constrain(Fix(end, 0.0, sign)).unwrap() |> ignore
      let query = s
        .try_add_point(@math.cos(angle), sign * @math.sin(angle))
        .unwrap()
      s.try_constrain(PointOnArc(query, arc)).unwrap() |> ignore
      let report = s.solve_and_apply().unwrap().report
      assert_true(report.is_satisfied())
      if angle < 0.0 {
        // A point on the supporting circle just before the arc start is not on
        // the finite arc. Check the initial report before any point is moved.
        assert_true(report.initial_max_tolerance_ratio > 500.0)
      } else {
        assert_true(report.initial_max_tolerance_ratio <= 1.0)
      }
      let p = s.point(query).unwrap()
      let expected_angle = if angle < 0.0 { 0.0 } else { angle }
      maintenance_near(p.x, @math.cos(expected_angle), "projection x")
      maintenance_near(p.y, sign * @math.sin(expected_angle), "projection y")
    }
  }
}

///|
test "seeded mixed edit sessions recover without changing the saved shape" {
  let seed = 20261121U
  let mut state = seed
  let s = @sketch.Sketch::new()
  let c = s.try_add_point(0.0, 0.0).unwrap()
  let a = s.try_add_point(2.0, 0.0).unwrap()
  let b = s.try_add_point(0.0, 2.0).unwrap()
  let t = s.try_add_point(3.0, 2.0).unwrap()
  let axis = s.try_add_line(c, a).unwrap()
  let tangent = s.try_add_line(b, t).unwrap()
  let arc = s.try_add_arc(c, a, b, CounterClockwise).unwrap()
  let circle = s.try_add_circle(c, 2.0).unwrap()
  s.try_constrain(Fix(c, 0.0, 0.0)).unwrap() |> ignore
  s.try_constrain(Horizontal(axis)).unwrap() |> ignore
  s.try_constrain(ArcSweep(arc, @math.PI / 2.0)).unwrap() |> ignore
  s.try_constrain(ArcTangentAt(tangent, arc, End)).unwrap() |> ignore
  s.try_constrain(Distance(b, t, 3.0)).unwrap() |> ignore
  s.try_constrain(EqualCircleArcRadius(circle, arc)).unwrap() |> ignore
  let radius = s.try_constrain(ArcRadius(arc, 2.0)).unwrap()
  for i in 0..<12 {
    state = state * 1664525U + 1013904223U
    let r = 1.9 + (state % 201U).reinterpret_as_int().to_double() / 1000.0
    let case_label = "seed=\{seed} edit=\{i} radius=\{r}"
    s.try_set_constraint(radius, ArcRadius(arc, r)).unwrap()
    let snapshot = s.solve_and_apply().unwrap()
    assert_true(snapshot.report.is_satisfied(), msg=case_label)
    maintenance_near(snapshot.radius(circle).unwrap(), r, case_label)
    maintenance_near(snapshot.point(t).unwrap().x, 3.0, case_label)
    maintenance_near(snapshot.point(t).unwrap().y, r, case_label)
    let saved_shape = s.to_svg().unwrap()
    let bad = s.try_constrain(ArcRadius(arc, r + 1.0)).unwrap()
    let report = s.solve_and_apply().unwrap().report
    assert_false(report.is_satisfied(), msg=case_label)
    assert_eq(s.to_svg().unwrap(), saved_shape)
    let analysis = s
      .analyze_conflicts(max_subset_solves=1, max_linear_solves=400)
      .unwrap()
    assert_true(analysis.budget_exhausted, msg=case_label)
    assert_eq(analysis.subset_solves, 1)
    assert_eq(s.constraint_enabled(bad), Some(true))
    assert_eq(s.to_svg().unwrap(), saved_shape)
    assert_true(s.remove_constraint(bad))
    assert_true(
      s.solve_and_apply().unwrap().report.is_satisfied(),
      msg=case_label,
    )
    maintenance_near(snapshot.radius(circle).unwrap(), r, case_label)
    assert_true(snapshot.report.is_satisfied())
  }
}

///|
test "changing the rank threshold changes local candidates without editing the sketch" {
  let s = @sketch.Sketch::new()
  let a = s.try_add_point(0.0, 0.0).unwrap()
  let dy = 1.0e-6
  let b = s.try_add_point(1.0, dy).unwrap()
  let x = s.try_constrain(DistanceX(a, b, 1.0)).unwrap()
  let distance = s.try_constrain(Distance(a, b, @math.hypot(1.0, dy))).unwrap()
  let exact = s
    .analyze_redundancy(options={
      ..@sketch.SolveOptions::default(),
      rank_tolerance: 1.0e-10,
    })
    .unwrap()
  let coarse = s
    .analyze_redundancy(options={
      ..@sketch.SolveOptions::default(),
      rank_tolerance: 1.0e-4,
    })
    .unwrap()
  assert_true(exact.baseline.is_satisfied() && coarse.baseline.is_satisfied())
  assert_eq(exact.rank, 2)
  assert_eq(exact.candidates.length(), 0)
  assert_eq(coarse.rank, 1)
  assert_eq(coarse.candidates.length(), 2)
  assert_eq(s.constraint_enabled(x), Some(true))
  assert_eq(s.constraint_enabled(distance), Some(true))
  assert_eq(s.point(b).unwrap().y, dy)
}
