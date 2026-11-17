///|
test "32 redundancy models report individual local candidates without editing state" {
  for i in 0..<32 {
    let s = @sketch.Sketch::new()
    let p = s.try_add_point(i.to_double(), -1.0).unwrap()
    let a = s.try_constrain(Fix(p, i.to_double(), -1.0)).unwrap()
    let b = s.try_constrain(Fix(p, i.to_double(), -1.0)).unwrap()
    let report = s.analyze_redundancy().unwrap()
    assert_true(report.baseline.is_satisfied())
    assert_eq(report.rank, 2)
    assert_eq(report.rank_evaluations, 3)
    assert_eq(report.candidates.length(), 2)
    assert_eq(report.candidates[0].id.index(), a.index())
    assert_eq(report.candidates[1].id.index(), b.index())
    assert_eq(s.constraint_enabled(a), Some(true))
    assert_eq(s.constraint_enabled(b), Some(true))
    assert_eq(s.point(p).unwrap().x, i.to_double())
    let budget = s.analyze_redundancy(max_rank_evaluations=1).unwrap()
    assert_true(budget.budget_exhausted)
    assert_eq(budget.candidates.length(), 0)
  }
}

///|
test "64 conflict models distinguish independent groups and observed repairs" {
  for i in 0..<64 {
    let s = @sketch.Sketch::new()
    let a = s.try_add_point(0.0, 0.0).unwrap()
    let a1 = s.try_constrain(Fix(a, 0.0, 0.0)).unwrap()
    let a2 = s.try_constrain(Fix(a, 1.0 + i.to_double() * 0.01, 0.0)).unwrap()
    let double = i % 2 == 0
    if double {
      let b = s.try_add_point(10.0, 0.0).unwrap()
      s.try_constrain(Fix(b, 10.0, 0.0)).unwrap() |> ignore
      s.try_constrain(Fix(b, 12.0, 0.0)).unwrap() |> ignore
    }
    let analysis = s.analyze_conflicts().unwrap()
    assert_false(analysis.baseline.is_satisfied())
    assert_eq(analysis.groups.length(), if double { 2 } else { 1 })
    assert_eq(analysis.groups[0].constraints.length(), 2)
    for group in analysis.groups {
      assert_true(group.narrowing_completed)
      for id in group.constraints {
        assert_true(s.constraint(id) is Some(_))
      }
    }
    assert_eq(analysis.removal_suggestions.length(), if double { 0 } else { 2 })
    assert_true(analysis.subset_solves <= 32)
    assert_true(analysis.charged_linear_solves <= 400)
    assert_false(analysis.budget_exhausted)
    assert_eq(s.point(a).unwrap().x, 0.0)
    assert_eq(s.constraint_enabled(a1), Some(true))
    assert_eq(s.constraint_enabled(a2), Some(true))
    assert_eq(s.analyze_redundancy().unwrap().candidates.length(), 0)
  }
}

///|
test "64 singular starts are recoverable and are never diagnosed as proven infeasible" {
  for i in 0..<64 {
    let s = @sketch.Sketch::new()
    let x = i.to_double() * 0.1
    let a = s.try_add_point(x, 0.0).unwrap()
    let b = s.try_add_point(x, 0.0).unwrap()
    s.try_constrain(Distance(a, b, 1.0)).unwrap() |> ignore
    let report = s.solve_and_apply().unwrap().report
    assert_true(report.status is Stalled)
    assert_true(report.stop_reason is SingularJacobian)
    assert_eq(s.point(b).unwrap().x, x)
    let candidates = s.analyze_conflicts().unwrap()
    assert_eq(candidates.groups.length(), 1)
    s.try_set_point(b, { x: x + 0.2, y: 0.0, }).unwrap()
    assert_true(s.solve_and_apply().unwrap().report.is_satisfied())
  }
}

///|
test "diagnostic budgets, disabled invalid definitions and row origins remain explicit" {
  let s = @sketch.Sketch::new()
  let p = s.try_add_point(0.0, 0.0).unwrap()
  let retired = s.try_constrain(Fix(p, 0.0, 0.0)).unwrap()
  assert_true(s.remove_constraint(retired))
  let a = s.try_constrain(Fix(p, 0.0, 0.0)).unwrap()
  let b = s.try_constrain(Fix(p, 1.0, 0.0)).unwrap()
  let disabled = s.constrain(Distance(p, p, -1.0))
  assert_true(s.set_constraint_enabled(disabled, false))
  let analysis = s
    .analyze_conflicts(max_subset_solves=1, max_linear_solves=1)
    .unwrap()
  assert_true(analysis.budget_exhausted)
  assert_eq(analysis.subset_solves, 1)
  assert_true(analysis.charged_linear_solves <= 1)
  let report = s.solve(max_linear_solves=1).unwrap().report
  assert_true(report.status is BudgetLimit)
  assert_true(report.stop_reason is QrBudgetExhausted)
  assert_eq(report.equation_residuals.length(), 4)
  for row in report.equation_residuals {
    assert_true(
      row.origin is ConstraintEquation(id) &&
      (id.index() == a.index() || id.index() == b.index()),
    )
    assert_true(row.component == 0 || row.component == 1)
  }
  assert_true(
    s.analyze_conflicts(max_subset_solves=0) is Err(InvalidOptions(_)),
  )
  assert_true(
    s.analyze_redundancy(max_rank_evaluations=130) is Err(InvalidOptions(_)),
  )
  assert_eq(s.constraint_enabled(disabled), Some(false))
}
