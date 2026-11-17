///|
pub(all) enum SolveStatus {
  Satisfied
  Stalled
  IterationLimit
  BudgetLimit
} derive(Debug)

///|
pub extend SolveStatus with @debug.Debug::{to_repr}

///|
pub(all) enum SolveStopReason {
  Converged
  NoDescent
  StepTooSmall
  LinearSolveFailure
  SingularJacobian
  IterationBudgetExhausted
  QrBudgetExhausted
  WorldToleranceFailure
} derive(Debug)

///|
pub(all) enum EquationOrigin {
  ConstraintEquation(ConstraintId)
  ArcEquation(ArcId)
} derive(Debug)

///|
pub struct EquationResidual {
  origin : EquationOrigin
  component : Int32
  angular : Bool
  error : Double
  tolerance_ratio : Double
} derive(Debug)

///|
pub struct GeometryResidual {
  arc : ArcId
  length_error : Double
  tolerance_ratio : Double
} derive(Debug)

///|
priv struct SolveTrace {
  reason : SolveStopReason
  initial_ratio : Double
  accepted : Int32
  damping : Double
}

///|
pub(all) struct SolveOptions {
  length_tolerance : Double
  angular_tolerance : Double
  rank_tolerance : Double
  max_iterations : Int32
}

///|
pub fn SolveOptions::default() -> SolveOptions {
  {
    length_tolerance: 1.0e-7,
    angular_tolerance: 1.0e-8,
    rank_tolerance: 1.0e-9,
    max_iterations: 200,
  }
}

///|
/// Maximum component errors per constraint, before tolerance weighting.
pub struct ConstraintResidual {
  id : ConstraintId
  active : Bool
  length_error : Double
  angular_error : Double
  tolerance_ratio : Double
} derive(Debug)

///|
pub extend ConstraintResidual with @debug.Debug::{to_repr}

///|
/// DOF and equation dependence refer to the local Jacobian at this result.
/// Unsatisfied constraints are symptoms, not a proven minimal conflict set.
pub struct SolveReport {
  priv owner : Array[Unit]
  status : SolveStatus
  iterations : Int32
  linear_solves : Int32
  variables : Int32
  equations : Int32
  rank : Int32
  local_dof : Int32
  dependent_equations : Int32
  max_tolerance_ratio : Double
  residuals : Array[ConstraintResidual]
  geometry_residuals : Array[GeometryResidual]
  equation_residuals : Array[EquationResidual]
  stop_reason : SolveStopReason
  initial_max_tolerance_ratio : Double
  accepted_steps : Int32
  rejected_steps : Int32
  final_damping : Double
} derive(Debug)

///|
pub extend SolveReport with @debug.Debug::{to_repr}

///|
pub struct Solution {
  priv owner : Array[Unit]
  report : SolveReport
  priv points : Array[Point]
  priv radii : Array[Double]
  priv point_ids : Array[PointId]
  priv circle_ids : Array[CircleId]
  priv line_ids : Array[LineId]
  priv lines : Array[Line]
  priv arcs : Array[Arc]
  priv arc_ids : Array[ArcId]
}

///|
pub fn Solution::point(self : Solution, id : PointId) -> Point? {
  if physical_equal(self.owner, id.owner) {
    for i, p in self.point_ids {
      if p.index == id.index {
        return self.points.get(i)
      }
    }
    None
  } else {
    None
  }
}

///|
pub fn Solution::radius(self : Solution, id : CircleId) -> Double? {
  if physical_equal(self.owner, id.owner) {
    for i, c in self.circle_ids {
      if c.index == id.index {
        return self.radii.get(i)
      }
    }
    None
  } else {
    None
  }
}

///|
pub fn SolveReport::is_satisfied(self : SolveReport) -> Bool {
  match self.status {
    Satisfied => true
    _ => false
  }
}

///|
pub fn SolveReport::unsatisfied(
  self : SolveReport,
) -> Array[ConstraintResidual] {
  self.residuals.filter(r => r.active && r.tolerance_ratio > 1.0)
}

///|
/// Heuristic inspection order, not proof of inconsistency or a minimal conflict
/// set. Sort active violations by descending tolerance_ratio, then stable ID.
/// Returns a fresh array without changing this report or the sketch.
pub fn SolveReport::likely_conflicts(
  self : SolveReport,
) -> Array[ConstraintResidual] {
  let findings = self.unsatisfied()
  findings.sort_by((a, b) => {
    if a.tolerance_ratio > b.tolerance_ratio {
      -1
    } else if a.tolerance_ratio < b.tolerance_ratio {
      1
    } else {
      a.id.index.compare(b.id.index)
    }
  })
  findings
}

///|
/// Look up a stable ID in this report's solve-time snapshot. Deleted relations
/// remain readable in older reports and are absent from subsequent reports.
pub fn SolveReport::residual(
  self : SolveReport,
  id : ConstraintId,
) -> ConstraintResidual? {
  if !physical_equal(self.owner, id.owner) {
    return None
  }
  for residual in self.residuals {
    if residual.id.index == id.index {
      return Some(residual)
    }
  }
  None
}

///|
fn row_tolerance(row : Row, frame : Frame, options : SolveOptions) -> Double {
  if row.angular {
    options.angular_tolerance
  } else {
    options.length_tolerance / frame.scale
  }
}

///|
fn weighted_system(
  rows : Array[Row],
  frame : Frame,
  options : SolveOptions,
) -> (Array[Double], Array[Array[Double]]) {
  let residual = rows.map(r => r.jet.v / row_tolerance(r, frame, options))
  let jacobian = rows.map(r => {
    r.jet.d.map(d => d / row_tolerance(r, frame, options))
  })
  (residual, jacobian)
}

///|
fn cost(residual : Array[Double]) -> Double {
  let mut value = 0.0
  for r in residual {
    value = value + r * r
  }
  value
}

///|
fn Sketch::solution(
  self : Sketch,
  x : Array[Double],
  frame : Frame,
  options : SolveOptions,
  status : SolveStatus,
  iterations : Int32,
  linear_solves : Int32,
  trace~ : SolveTrace? = None,
) -> Result[Solution, SketchError] {
  let points : Array[Point] = Array::makei(self.points.length(), i => {
    x: x[i * 2] * frame.scale + frame.x,
    y: x[i * 2 + 1] * frame.scale + frame.y,
  })
  let radii = Array::makei(self.circles.length(), i => {
    x[self.points.length() * 2 + i] * frame.scale
  })
  if points.any(p => !finite(p.x) || !finite(p.y)) || radii.any(r => !finite(r)) {
    return Err(NumericalFailure("Output geometry overflow"))
  }
  // Measure returned coordinates directly in world units. Re-normalizing the
  // output can hide a tolerance violation through another cancellation.
  let physical_x = []
  for p in points {
    physical_x.push(p.x)
    physical_x.push(p.y)
  }
  for r in radii {
    physical_x.push(r)
  }
  let world_frame : Frame = { x: 0.0, y: 0.0, scale: 1.0, }
  let rows = match
    self.evaluate(physical_x, world_frame, geometry_scale=frame.scale) {
    Ok(r) => r
    Err(e) => return Err(e)
  }
  let length_errors = Array::make(self.constraints.length(), 0.0)
  let angular_errors = Array::make(self.constraints.length(), 0.0)
  let ratios = Array::make(self.constraints.length(), 0.0)
  let geometry_ratios = Array::make(self.arcs.length(), 0.0)
  let geometry_errors = Array::make(self.arcs.length(), 0.0)
  let equation_residuals = []
  let components = Array::make(
    self.constraints.length() + self.arcs.length(),
    0,
  )
  let mut all_ratio = 0.0
  for row in rows {
    let i = row.slot
    let error = row.jet.v.abs()
    let ratio = error / row_tolerance(row, world_frame, options)
    all_ratio = dmax(all_ratio, ratio)
    let origin = if i < 0 {
      ArcEquation(self.arc_ids[-i - 1])
    } else {
      ConstraintEquation(self.constraint_ids[i])
    }
    let component_slot = if i < 0 {
      self.constraints.length() - i - 1
    } else {
      i
    }
    equation_residuals.push({
      origin,
      component: components[component_slot],
      angular: row.angular,
      error,
      tolerance_ratio: ratio,
    })
    components[component_slot] += 1
    if i < 0 {
      geometry_errors[-i - 1] = dmax(geometry_errors[-i - 1], error)
      geometry_ratios[-i - 1] = dmax(geometry_ratios[-i - 1], ratio)
      continue
    }
    if row.angular {
      angular_errors[i] = dmax(angular_errors[i], error)
    } else {
      length_errors[i] = dmax(length_errors[i], error)
    }
    ratios[i] = dmax(
      ratios[i],
      error / row_tolerance(row, world_frame, options),
    )
  }
  let rank = numerical_rank(
    rows.map(r => r.jet.d),
    x.length(),
    options.rank_tolerance,
  )
  let residuals = Array::makei(self.constraints.length(), i => {
    id: self.constraint_ids[i],
    active: self.enabled[i],
    length_error: length_errors[i],
    angular_error: angular_errors[i],
    tolerance_ratio: ratios[i],
  })
  let status = if all_ratio <= 1.0 {
    Satisfied
  } else {
    match status {
      Satisfied => Stalled
      other => other
    }
  }
  let default_reason = match status {
    Satisfied => Converged
    Stalled => NoDescent
    IterationLimit => IterationBudgetExhausted
    BudgetLimit => QrBudgetExhausted
  }
  let reason = if all_ratio <= 1.0 {
    Converged
  } else if status is Stalled && max_abs(ratios) <= 1.0 && trace is None {
    WorldToleranceFailure
  } else {
    trace.map(t => t.reason).unwrap_or(default_reason)
  }
  let reason = if all_ratio > 1.0 && trace is Some({ reason: Converged, .. }) {
    WorldToleranceFailure
  } else {
    reason
  }
  let report : SolveReport = {
    owner: self.owner,
    status,
    iterations,
    linear_solves,
    variables: x.length(),
    equations: rows.length(),
    rank,
    local_dof: x.length() - rank,
    dependent_equations: rows.length() - rank,
    max_tolerance_ratio: all_ratio,
    residuals,
    geometry_residuals: Array::makei(self.arcs.length(), i => {
      arc: self.arc_ids[i],
      length_error: geometry_errors[i],
      tolerance_ratio: geometry_ratios[i],
    }),
    equation_residuals,
    stop_reason: reason,
    initial_max_tolerance_ratio: trace
    .map(t => t.initial_ratio)
    .unwrap_or(all_ratio),
    accepted_steps: trace.map(t => t.accepted).unwrap_or(0),
    rejected_steps: linear_solves - trace.map(t => t.accepted).unwrap_or(0),
    final_damping: trace.map(t => t.damping).unwrap_or(0.0),
  }
  Ok({
    owner: self.owner,
    report,
    points,
    radii,
    point_ids: self.point_ids.copy(),
    circle_ids: self.circle_ids.copy(),
    line_ids: self.line_ids.copy(),
    lines: self.lines.copy(),
    arcs: self.arcs.copy(),
    arc_ids: self.arc_ids.copy(),
  })
}

///|
/// Local damped Gauss-Newton solve with forward-mode AD in Double arithmetic.
/// Err means invalid input/evaluation, not a mathematical proof of inconsistency.
/// A nonconverged Solution still contains the best accepted iterate for inspection.
/// max_linear_solves (1..4000, default 400) counts every damped QR attempt,
/// including rejected/failed steps. Final diagnostic rank evaluation is separate.
/// max_damping_attempts (1..16) bounds trials within each iteration.
pub fn Sketch::solve(
  self : Sketch,
  options~ : SolveOptions = SolveOptions::default(),
  max_linear_solves~ : Int32 = 400,
  max_damping_attempts~ : Int32 = 16,
) -> Result[Solution, SketchError] {
  match self.validate() {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  if !finite(options.length_tolerance) ||
    options.length_tolerance <= 0.0 ||
    !finite(options.angular_tolerance) ||
    options.angular_tolerance < 1.0e-14 ||
    options.angular_tolerance > 0.1 ||
    !finite(options.rank_tolerance) ||
    options.rank_tolerance < 1.0e-14 ||
    options.rank_tolerance > 0.01 ||
    options.max_iterations < 1 ||
    options.max_iterations > 1000 ||
    max_linear_solves < 1 ||
    max_linear_solves > 4000 ||
    max_damping_attempts < 1 ||
    max_damping_attempts > 16 {
    return Err(
      InvalidOptions(
        "Invalid tolerances or budgets: iterations 1..1000, linear solves 1..4000, damping attempts 1..16",
      ),
    )
  }
  let frame = self.frame()
  let relative_tolerance = options.length_tolerance / frame.scale
  if !finite(relative_tolerance) ||
    relative_tolerance < 1.0e-14 ||
    relative_tolerance > 1.0e6 {
    return Err(
      InvalidOptions(
        "Length tolerance / sketch scale must be between 1e-14 and 1e6",
      ),
    )
  }
  let mut x = self.parameters(frame)
  let mut rows = match self.evaluate(x, frame) {
    Ok(r) => r
    Err(e) => return Err(e)
  }
  let mut lambda = 1.0e-3
  let mut linear_solves = 0
  let initial_ratio = max_abs(weighted_system(rows, frame, options).0)
  let mut accepted_steps = 0
  for iteration = 0
      iteration < options.max_iterations
      iteration = iteration + 1 {
    let (residual, jacobian) = weighted_system(rows, frame, options)
    if max_abs(residual) <= 1.0 {
      return self.solution(
        x,
        frame,
        options,
        Satisfied,
        iteration,
        linear_solves,
        trace=Some({
          reason: Converged,
          initial_ratio,
          accepted: accepted_steps,
          damping: lambda,
        }),
      )
    }
    let old_cost = cost(residual)
    let mut accepted = false
    let mut reason = NoDescent
    for attempt = 0; attempt < max_damping_attempts; attempt = attempt + 1 {
      if linear_solves >= max_linear_solves {
        return self.solution(
          x,
          frame,
          options,
          BudgetLimit,
          iteration,
          linear_solves,
          trace=Some({
            reason: QrBudgetExhausted,
            initial_ratio,
            accepted: accepted_steps,
            damping: lambda,
          }),
        )
      }
      linear_solves += 1
      let delta = match damped_step(jacobian, residual, x.length(), lambda) {
        Some(d) => d
        None => {
          reason = LinearSolveFailure
          lambda = lambda * 10.0
          continue
        }
      }
      if max_abs(delta) <= 1.0e-14 {
        reason = if jacobian.all(row => max_abs(row) == 0.0) {
          SingularJacobian
        } else {
          StepTooSmall
        }
        break
      }
      let trial = Array::makei(x.length(), i => x[i] + delta[i])
      match self.evaluate(trial, frame) {
        Ok(trial_rows) => {
          let (trial_residual, _) = weighted_system(trial_rows, frame, options)
          if cost(trial_residual) < old_cost {
            x = trial
            rows = trial_rows
            lambda = dmax(lambda * 0.25, 1.0e-12)
            accepted = true
            accepted_steps += 1
            break
          }
        }
        Err(_) => ()
      }
      lambda = lambda * 10.0
      reason = NoDescent
    }
    if !accepted {
      return self.solution(
        x,
        frame,
        options,
        Stalled,
        iteration + 1,
        linear_solves,
        trace=Some({
          reason,
          initial_ratio,
          accepted: accepted_steps,
          damping: lambda,
        }),
      )
    }
  }
  let (residual, _) = weighted_system(rows, frame, options)
  let status = if max_abs(residual) <= 1.0 { Satisfied } else { IterationLimit }
  self.solution(
    x,
    frame,
    options,
    status,
    options.max_iterations,
    linear_solves,
    trace=Some({
      reason: if status is Satisfied {
        Converged
      } else {
        IterationBudgetExhausted
      },
      initial_ratio,
      accepted: accepted_steps,
      damping: lambda,
    }),
  )
}

///|
/// Commit geometry only if all residuals meet tolerance. Failed solves are atomic.
pub fn Sketch::solve_and_apply(
  self : Sketch,
  options~ : SolveOptions = SolveOptions::default(),
  max_linear_solves~ : Int32 = 400,
  max_damping_attempts~ : Int32 = 16,
) -> Result[Solution, SketchError] {
  let solution = match
    self.solve(options~, max_linear_solves~, max_damping_attempts~) {
    Ok(s) => s
    Err(e) => return Err(e)
  }
  if solution.report.is_satisfied() {
    for i, p in solution.points {
      self.points[i] = p
    }
    for i, r in solution.radii {
      let c = self.circles[i]
      self.circles[i] = { center: c.center, radius: r, }
    }
  }
  Ok(solution)
}

///|
pub extend SolveStopReason with @debug.Debug::{to_repr}

///|
pub extend EquationOrigin with @debug.Debug::{to_repr}

///|
pub extend EquationResidual with @debug.Debug::{to_repr}

///|
pub extend GeometryResidual with @debug.Debug::{to_repr}
