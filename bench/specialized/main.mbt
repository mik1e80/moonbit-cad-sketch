// SPDX-License-Identifier: Apache-2.0

///|
fn require(condition : Bool, message : String) -> Unit {
  if !condition {
    abort(message)
  }
}

///|
fn close(actual : Double, expected : Double) -> Unit {
  require(
    (actual - expected).abs() <= 1.0e-6,
    "Expected \{expected}, got \{actual}",
  )
}

///|
fn emit(sample : Int32, name : String, us : Double, details : String) -> Unit {
  if sample > 0 {
    println("\{name} sample=\{sample} us=\{us} \{details}")
  }
}

///|
fn arc_solve(sample : Int32, count : Int32, tangent : Bool) -> Unit {
  let s = @cad.Sketch::new()
  let ends = []
  for i in 0..<count {
    let x = 4.0 * i.to_double()
    let c = s.try_add_point(x, 0.0).unwrap()
    let a = s.try_add_point(x + 1.0, 0.0).unwrap()
    let b = s.try_add_point(x + 0.04, 0.98).unwrap()
    s.try_constrain(Fix(c, x, 0.0)).unwrap() |> ignore
    s.try_constrain(Fix(a, x + 1.0, 0.0)).unwrap() |> ignore
    let arc = s.try_add_arc(c, a, b, CounterClockwise).unwrap()
    s.try_constrain(ArcSweep(arc, @math.PI / 2.0)).unwrap() |> ignore
    if tangent {
      let end = s.try_add_point(x + 0.97, 1.05).unwrap()
      let line = s.try_add_line(b, end).unwrap()
      s.try_constrain(ArcTangentAt(line, arc, End)).unwrap() |> ignore
      s.try_constrain(Distance(b, end, 1.0)).unwrap() |> ignore
      ends.push((end, x + 1.0))
    }
    ends.push((b, x))
  }
  let start = @clock.monotonic_clock_start()
  let solution = s.solve().unwrap()
  let us = @clock.monotonic_clock_end(start)
  let report = solution.report
  require(report.is_satisfied(), "Arc workload did not solve")
  let mut max_error = 0.0
  for entry in ends {
    let (id, x) = entry
    let p = solution.point(id).unwrap()
    close(p.x, x)
    close(p.y, 1.0)
    max_error = max_error.max(@math.hypot(p.x - x, p.y - 1.0))
  }
  let name = if tangent { "arc_tangency" } else { "many_arcs" }
  let constraints = count * (if tangent { 5 } else { 3 })
  emit(
    sample,
    name,
    us,
    "variables=\{report.variables} constraints=\{constraints} equations=\{report.equations} iterations=\{report.iterations} qr=\{report.linear_solves} satisfied=true max_position_error=\{max_error}",
  )
}

///|
fn redundancy(sample : Int32) -> Unit {
  let s = @cad.Sketch::new()
  for i in 0..<12 {
    let x = i.to_double()
    let id = s.try_add_point(x, 0.0).unwrap()
    s.try_constrain(Fix(id, x, 0.0)).unwrap() |> ignore
    s.try_constrain(Fix(id, x, 0.0)).unwrap() |> ignore
  }
  let start = @clock.monotonic_clock_start()
  let result = s.analyze_redundancy(max_rank_evaluations=25).unwrap()
  let us = @clock.monotonic_clock_end(start)
  require(
    result.candidates.length() == 24 && !result.budget_exhausted,
    "Unexpected local redundancy result",
  )
  emit(
    sample,
    "redundancy",
    us,
    "variables=\{result.baseline.variables} constraints=24 equations=\{result.baseline.equations} rank_evaluations=\{result.rank_evaluations} candidates=\{result.candidates.length()}",
  )
}

///|
fn lifecycle(sample : Int32) -> Unit {
  let s = @cad.Sketch::new()
  let kept = s.try_add_point(-1.0, 0.0).unwrap()
  let ids = Array::makei(120, i => s.try_add_point(i.to_double(), 0.0).unwrap())
  let start = @clock.monotonic_clock_start()
  for id in ids {
    require(s.remove_point(id).unwrap(), "Could not remove point")
  }
  let us = @clock.monotonic_clock_end(start)
  for id in ids {
    require(s.point(id) is None, "Deleted point still present")
  }
  require(s.point(kept).unwrap().x == -1.0, "Retained point changed")
  let replacement = s.try_add_point(0.0, 0.0).unwrap()
  require(replacement.index > ids[119].index, "Point ID was reused")
  emit(
    sample, "point_deletion", us, "variables_before=242 constraints=0 removed=120",
  )
}

///|
fn large_svg(sample : Int32) -> Unit {
  let s = @cad.Sketch::new()
  let a = s.try_add_point(0.0, 0.0).unwrap()
  let b = s.try_add_point(1.0, 0.0).unwrap()
  let c = s.try_add_point(0.0, 1.0).unwrap()
  for _ in 0..<512 {
    s.try_add_line(a, b).unwrap() |> ignore
  }
  for _ in 0..<128 {
    s.try_add_arc(a, b, c, CounterClockwise).unwrap() |> ignore
  }
  let start = @clock.monotonic_clock_start()
  let svg = s.to_svg().unwrap()
  let us = @clock.monotonic_clock_end(start)
  require(
    svg.contains("data-line=\"511\"") && svg.contains("data-arc=\"127\""),
    "SVG omitted geometry",
  )
  emit(
    sample,
    "large_svg",
    us,
    "variables=6 constraints=0 lines=512 arcs=128 utf16_units=\{svg.length()}",
  )
}

///|
fn main {
  for sample in 0..<=3 {
    arc_solve(sample, 16, false)
    arc_solve(sample, 8, true)
    redundancy(sample)
    lifecycle(sample)
    large_svg(sample)
  }
}
