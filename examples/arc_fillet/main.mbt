///|
fn verify(
  s : @sketch.Sketch,
  start : @sketch.PointId,
  end : @sketch.PointId,
  inlet : @sketch.PointId,
  outlet : @sketch.PointId,
  r : Double,
) -> Unit {
  let a = s.point(start).unwrap()
  let b = s.point(end).unwrap()
  let p = s.point(inlet).unwrap()
  let q = s.point(outlet).unwrap()
  if (a.x - r).abs() > 2.0e-6 ||
    a.y.abs() > 2.0e-6 ||
    b.x.abs() > 2.0e-6 ||
    (b.y - r).abs() > 2.0e-6 ||
    (p.x - r).abs() > 2.0e-6 ||
    (p.y + 3.0).abs() > 2.0e-6 ||
    (q.x - 4.0).abs() > 2.0e-6 ||
    (q.y - r).abs() > 2.0e-6 {
    abort("Independent arc/segment coordinate oracle failed")
  }
}

///|
fn emit_svg(s : @sketch.Sketch, stage : String) -> Unit {
  let svg = s
    .to_svg(
      options={
        ..@sketch.SvgOptions::default(),
        title: "Arc radius editing: \{stage}",
        show_points: false,
        bounds: Some({ min_x: -4.0, min_y: -5.0, max_x: 7.0, max_y: 7.0, }),
      },
      show_construction=false,
    )
    .unwrap()
  println("\{stage}_SVG")
  println(svg)
  println("END_SVG")
}

///|
fn main {
  let s = @sketch.Sketch::new()
  let c = s.try_add_point(0.0, 0.0).unwrap()
  let a = s.try_add_point(2.0, 0.0).unwrap()
  let b = s.try_add_point(0.0, 2.0).unwrap()
  let inlet = s.try_add_point(2.0, -3.0).unwrap()
  let outlet = s.try_add_point(4.0, 2.0).unwrap()
  let axis = s.try_add_line(c, a).unwrap()
  let incoming = s.try_add_line(inlet, a).unwrap()
  let outgoing = s.try_add_line(b, outlet).unwrap()
  let arc = s.try_add_arc(c, a, b, @sketch.CounterClockwise).unwrap()
  s
  .set_geometry_role(@sketch.LineGeometry(axis), @sketch.ConstructionGeometry)
  .unwrap()
  s.try_constrain(Fix(c, 0.0, 0.0)).unwrap() |> ignore
  s.try_constrain(Horizontal(axis)).unwrap() |> ignore
  let radius = s.try_constrain(ArcRadius(arc, 2.0)).unwrap()
  s.try_constrain(ArcSweep(arc, 1.5707963267948966)).unwrap() |> ignore
  s.try_constrain(ArcTangentAt(incoming, arc, @sketch.Start)).unwrap() |> ignore
  s.try_constrain(ArcTangentAt(outgoing, arc, @sketch.End)).unwrap() |> ignore
  s.try_constrain(Distance(inlet, a, 3.0)).unwrap() |> ignore
  s.try_constrain(Distance(b, outlet, 4.0)).unwrap() |> ignore
  let before = s.solve_and_apply().unwrap()
  if !before.report.is_satisfied() {
    abort("Initial arc did not solve")
  }
  verify(s, a, b, inlet, outlet, 2.0)
  emit_svg(s, "BEFORE")
  s.try_set_constraint(radius, ArcRadius(arc, 3.0)).unwrap()
  let after = s.solve_and_apply().unwrap()
  if !after.report.is_satisfied() {
    abort("Edited arc did not solve")
  }
  verify(s, a, b, inlet, outlet, 3.0)
  emit_svg(s, "AFTER")
  let conflict = s.try_constrain(ArcRadius(arc, 5.0)).unwrap()
  let failure = s.solve_and_apply().unwrap()
  if failure.report.is_satisfied() {
    abort("Expected conflicting radii")
  }
  verify(s, a, b, inlet, outlet, 3.0)
  emit_svg(s, "CONFLICT")
  let diagnosis = s.analyze_conflicts(max_subset_solves=16).unwrap()
  println(
    "DIAGNOSTIC subset_solves=\{diagnosis.subset_solves} QR_charged=\{diagnosis.charged_linear_solves} exhausted=\{diagnosis.budget_exhausted}",
  )
  if !s.remove_constraint(conflict) {
    abort("Conflict relation missing")
  }
  if !s.solve_and_apply().unwrap().report.is_satisfied() {
    abort("Recovery failed")
  }
  println(
    "Arc showcase verified: radius 2 -> 3, shared endpoint tangency, conflict preservation and recovery",
  )
}
