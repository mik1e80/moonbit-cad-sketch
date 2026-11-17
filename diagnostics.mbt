///|
/// Individually removable at one satisfied numerical configuration, not a
/// jointly removable set or global redundancy proof.
pub struct RedundantConstraintCandidate {
  id : ConstraintId
  rank_without : Int32
} derive(Debug)

///|
pub struct RankAnalysis {
  baseline : SolveReport
  rank : Int32
  rank_evaluations : Int32
  budget_exhausted : Bool
  candidates : Array[RedundantConstraintCandidate]
} derive(Debug)

///|
pub struct SubsetTrial {
  constraints : Array[ConstraintId]
  result : Result[SolveReport, SketchError]
} derive(Debug)

///|
/// Observed unresolved subset from the same initial geometry. Never a proof of
/// infeasibility or a minimal unsatisfiable core.
pub struct ConflictCandidate {
  constraints : Array[ConstraintId]
  observed_status : SolveStatus
  max_tolerance_ratio : Double
  narrowing_completed : Bool
} derive(Debug)

///|
pub struct ConflictAnalysis {
  baseline : SolveReport
  groups : Array[ConflictCandidate]
  removal_suggestions : Array[ConstraintId]
  trials : Array[SubsetTrial]
  subset_solves : Int32
  charged_linear_solves : Int32
  budget_exhausted : Bool
} derive(Debug)

///|
priv struct AnalysisBudget {
  max_solves : Int32
  max_linear : Int32
  per_solve : Int32
  counts : Array[Int32]
  trials : Array[SubsetTrial]
}

///|
fn Sketch::analysis_copy(self : Sketch) -> Sketch {
  {
    owner: self.owner,
    points: self.points.copy(),
    lines: self.lines.copy(),
    circles: self.circles.copy(),
    point_ids: self.point_ids.copy(),
    line_ids: self.line_ids.copy(),
    circle_ids: self.circle_ids.copy(),
    next_geometry: self.next_geometry.copy(),
    arcs: self.arcs.copy(),
    arc_ids: self.arc_ids.copy(),
    roles: Map([]),
    constraints: self.constraints.copy(),
    enabled: self.enabled.copy(),
    constraint_ids: self.constraint_ids.copy(),
    next_constraint: self.next_constraint.copy(),
  }
}

///|
fn Sketch::apply_snapshot_for_analysis(self : Sketch, s : Solution) -> Unit {
  for i, p in s.points {
    self.points[i] = p
  }
  for i, r in s.radii {
    let c = self.circles[i]
    self.circles[i] = { center: c.center, radius: r, }
  }
}

///|
/// Baseline must satisfy all enabled user and intrinsic geometry equations.
/// Each candidate is checked by removing its whole block of Jacobian rows.
/// ```mbt check
/// test {
///   let s = @sketch.Sketch::new()
///   let p = s.try_add_point(0.0, 0.0).unwrap()
///   s.try_constrain(@sketch.Fix(p, 0.0, 0.0)).unwrap() |> ignore
///   s.try_constrain(@sketch.Fix(p, 0.0, 0.0)).unwrap() |> ignore
///   assert_eq(s.analyze_redundancy().unwrap().candidates.length(), 2)
/// }
/// ```
pub fn Sketch::analyze_redundancy(
  self : Sketch,
  options~ : SolveOptions = SolveOptions::default(),
  max_rank_evaluations~ : Int32 = 33,
  max_linear_solves~ : Int32 = 128,
) -> Result[RankAnalysis, SketchError] {
  if max_rank_evaluations < 1 || max_rank_evaluations > 129 {
    return Err(InvalidOptions("Rank evaluation budget must be 1..129"))
  }
  let baseline = match self.solve(options~, max_linear_solves~) {
    Ok(s) => s
    Err(e) => return Err(e)
  }
  let copy = self.analysis_copy()
  copy.apply_snapshot_for_analysis(baseline)
  let frame = copy.frame()
  let x = copy.parameters(frame)
  let rows = match copy.evaluate(x, frame) {
    Ok(r) => r
    Err(e) => return Err(e)
  }
  let rank = numerical_rank(
    rows.map(r => r.jet.d),
    x.length(),
    options.rank_tolerance,
  )
  let candidates = []
  let mut evaluations = 1
  let mut exhausted = false
  if baseline.report.is_satisfied() {
    for i, id in self.constraint_ids {
      if !self.enabled[i] {
        continue
      }
      if evaluations >= max_rank_evaluations {
        exhausted = true
        break
      }
      let without = numerical_rank(
        rows.filter(r => r.slot != i).map(r => r.jet.d),
        x.length(),
        options.rank_tolerance,
      )
      evaluations += 1
      if without == rank {
        candidates.push({ id, rank_without: without, })
      }
    }
  }
  Ok({
    baseline: baseline.report,
    rank,
    rank_evaluations: evaluations,
    budget_exhausted: exhausted,
    candidates,
  })
}

///|
fn Sketch::analysis_trial(
  self : Sketch,
  mask : Array[Bool],
  options : SolveOptions,
  budget : AnalysisBudget,
) -> Result[Solution, SketchError]? {
  if budget.counts[0] >= budget.max_solves ||
    budget.counts[1] >= budget.max_linear {
    return None
  }
  let remaining = budget.max_linear - budget.counts[1]
  let limit = if remaining < budget.per_solve {
    remaining
  } else {
    budget.per_solve
  }
  let copy = self.analysis_copy()
  for i in 0..<mask.length() {
    copy.enabled[i] = self.enabled[i] && mask[i]
  }
  budget.counts[0] += 1
  let result = copy.solve(options~, max_linear_solves=limit)
  let constraints = []
  for i, id in self.constraint_ids {
    if copy.enabled[i] {
      constraints.push(id)
    }
  }
  let report = match result {
    Ok(s) => {
      budget.counts[1] += s.report.linear_solves
      Ok(s.report)
    }
    Err(e) => {
      budget.counts[1] += limit
      Err(e)
    }
  }
  budget.trials.push({ constraints, result: report, })
  Some(result)
}

///|
fn root_of(parents : Array[Int32], value : Int32) -> Int32 {
  let mut p = value
  while parents[p] != p {
    p = parents[p]
  }
  p
}

///|
fn join_variables(parents : Array[Int32], variables : Array[Int32]) -> Unit {
  if variables.length() == 0 {
    return
  }
  let a = root_of(parents, variables[0])
  for b in variables {
    parents[root_of(parents, b)] = a
  }
}

///|
fn Sketch::geometry_variables(self : Sketch, g : GeometryId) -> Array[Int32] {
  match g {
    PointGeometry(p) => {
      let i = self.point_slot(p).unwrap()
      [i * 2, i * 2 + 1]
    }
    LineGeometry(l) => {
      let l = self.lines[self.line_slot(l).unwrap()]
      let out = self.geometry_variables(PointGeometry(l.a))
      for i in self.geometry_variables(PointGeometry(l.b)) {
        out.push(i)
      }
      out
    }
    CircleGeometry(c) => {
      let i = self.circle_slot(c).unwrap()
      let out = self.geometry_variables(PointGeometry(self.circles[i].center))
      out.push(self.points.length() * 2 + i)
      out
    }
    ArcGeometry(a) => {
      let a = self.arc(a).unwrap()
      let out = self.geometry_variables(PointGeometry(a.center))
      for p in [a.start, a.end] {
        for i in self.geometry_variables(PointGeometry(p)) {
          out.push(i)
        }
      }
      out
    }
  }
}

///|
fn Sketch::constraint_components(self : Sketch) -> Array[Array[Int32]] {
  let parents : Array[Int32] = Array::makei(
    self.points.length() * 2 + self.circles.length(),
    (i : Int32) => i,
  )
  for a in self.arc_ids {
    join_variables(parents, self.geometry_variables(ArcGeometry(a)))
  }
  let variables = Array::makei(self.constraints.length(), slot => {
    let out = []
    if self.enabled[slot] {
      for g in constraint_geometry(self.constraints[slot]) {
        for i in self.geometry_variables(g) {
          out.push(i)
        }
      }
    }
    out
  })
  for i, vars in variables {
    if self.enabled[i] {
      join_variables(parents, vars)
    }
  }
  let roots = []
  let groups : Array[Array[Int32]] = []
  for i, vars in variables {
    if !self.enabled[i] {
      continue
    }
    let root = root_of(parents, vars[0])
    let mut group = -1
    for j, stored in roots {
      if stored == root {
        group = j
      }
    }
    if group < 0 {
      roots.push(root)
      groups.push([i])
    } else {
      groups[group].push(i)
    }
  }
  groups
}

///|
/// Bounded deletion experiments from exactly the same initial geometry.
/// Errors charge the full per-trial QR allowance conservatively. Failed local
/// solves are observations, never an infeasibility/MUS certificate.
/// ```mbt check
/// test {
///   let s = @sketch.Sketch::new()
///   let p = s.try_add_point(0.0, 0.0).unwrap()
///   s.try_constrain(@sketch.Fix(p, 0.0, 0.0)).unwrap() |> ignore
///   s.try_constrain(@sketch.Fix(p, 1.0, 0.0)).unwrap() |> ignore
///   assert_true(s.analyze_conflicts().unwrap().removal_suggestions.length() > 0)
///   assert_eq(s.point(p).unwrap().x, 0.0)
/// }
/// ```
pub fn Sketch::analyze_conflicts(
  self : Sketch,
  options~ : SolveOptions = SolveOptions::default(),
  max_subset_solves~ : Int32 = 32,
  max_linear_solves~ : Int32 = 400,
  per_subset_linear_solves~ : Int32 = 128,
) -> Result[ConflictAnalysis, SketchError] {
  if max_subset_solves < 1 ||
    max_subset_solves > 128 ||
    max_linear_solves < 1 ||
    max_linear_solves > 4000 ||
    per_subset_linear_solves < 1 ||
    per_subset_linear_solves > 4000 {
    return Err(
      InvalidOptions(
        "Diagnostics budgets: subsets 1..128, total/per-trial QR 1..4000",
      ),
    )
  }
  let budget : AnalysisBudget = {
    max_solves: max_subset_solves,
    max_linear: max_linear_solves,
    per_solve: per_subset_linear_solves,
    counts: [0, 0],
    trials: [],
  }
  let all = Array::make(self.constraints.length(), true)
  let baseline = match self.analysis_trial(all, options, budget).unwrap() {
    Ok(s) => s
    Err(e) => return Err(e)
  }
  let groups = []
  let repairs = []
  let mut exhausted = false
  if !baseline.report.is_satisfied() {
    let components = self.constraint_components()
    for component in components {
      let mask = Array::make(self.constraints.length(), false)
      for i in component {
        mask[i] = true
      }
      let observed = if components.length() == 1 {
        Some(Ok(baseline))
      } else {
        self.analysis_trial(mask, options, budget)
      }
      let mut report = match observed {
        None => {
          exhausted = true
          break
        }
        Some(Err(_)) => continue
        Some(Ok(s)) => s.report
      }
      if report.is_satisfied() {
        continue
      }
      let mut completed = true
      for i in component {
        mask[i] = false
        match self.analysis_trial(mask, options, budget) {
          None => {
            mask[i] = true
            exhausted = true
            completed = false
            break
          }
          Some(Err(_)) => mask[i] = true
          Some(Ok(s)) =>
            if s.report.is_satisfied() {
              mask[i] = true
            } else {
              report = s.report
            }
        }
      }
      let ids = []
      for i, id in self.constraint_ids {
        if self.enabled[i] && mask[i] {
          ids.push(id)
        }
      }
      groups.push({
        constraints: ids,
        observed_status: report.status,
        max_tolerance_ratio: report.max_tolerance_ratio,
        narrowing_completed: completed,
      })
    }
    for finding in baseline.report.likely_conflicts() {
      let mask = all.copy()
      mask[self.constraint_slot(finding.id).unwrap()] = false
      match self.analysis_trial(mask, options, budget) {
        None => {
          exhausted = true
          break
        }
        Some(Ok(s)) => if s.report.is_satisfied() { repairs.push(finding.id) }
        Some(Err(_)) => ()
      }
    }
  }
  Ok({
    baseline: baseline.report,
    groups,
    removal_suggestions: repairs,
    trials: budget.trials,
    subset_solves: budget.counts[0],
    charged_linear_solves: budget.counts[1],
    budget_exhausted: exhausted,
  })
}

///|
pub extend RedundantConstraintCandidate with @debug.Debug::{to_repr}

///|
pub extend RankAnalysis with @debug.Debug::{to_repr}

///|
pub extend SubsetTrial with @debug.Debug::{to_repr}

///|
pub extend ConflictCandidate with @debug.Debug::{to_repr}

///|
pub extend ConflictAnalysis with @debug.Debug::{to_repr}
