// SPDX-License-Identifier: Apache-2.0

///|
priv struct Dimensions {
  width : Double
  height : Double
  hole_pitch : Double
  corner_radius : Double
}

///|
priv struct Plate {
  sketch : @cad.Sketch
  origin : @cad.PointId
  right : @cad.PointId
  top : @cad.PointId
  arc_start : @cad.PointId
  arc_end : @cad.PointId
  arc : @cad.ArcId
  holes : @cad.LineId
  second_hole : @cad.PointId
  width : @cad.ConstraintId
  height : @cad.ConstraintId
  hole_pitch : @cad.ConstraintId
  radius : @cad.ConstraintId
}

///|
fn require(condition : Bool, message : String) -> Unit {
  if !condition {
    abort(message)
  }
}

///|
fn near(value : Double, expected : Double) -> Unit {
  require(
    (value - expected).abs() <= 1.0e-5,
    "Measured \{value}, expected \{expected}",
  )
}

///|
fn new_plate(p : Dimensions) -> Plate {
  let s = @cad.Sketch::new()
  let origin = s.try_add_point(0.0, 0.0).unwrap()
  let right = s.try_add_point(61.0, 0.2).unwrap()
  let arc_start = s.try_add_point(61.0, 35.0).unwrap()
  let arc_end = s.try_add_point(55.0, 41.0).unwrap()
  let top = s.try_add_point(0.2, 41.0).unwrap()
  let center = s.try_add_point(55.0, 35.0).unwrap()
  let first_hole = s.try_add_point(13.0, 17.0).unwrap()
  let second_hole = s.try_add_point(38.0, 17.0).unwrap()

  let bottom = s.try_add_line(origin, right).unwrap()
  let wall = s.try_add_line(right, arc_start).unwrap()
  let roof = s.try_add_line(arc_end, top).unwrap()
  let left = s.try_add_line(top, origin).unwrap()
  let arc = s.try_add_arc(center, arc_start, arc_end, CounterClockwise).unwrap()
  let holes = s.try_add_line(first_hole, second_hole).unwrap()
  s.set_geometry_role(LineGeometry(holes), ConstructionGeometry).unwrap()
  let hole_a = s.try_add_circle(first_hole, 3.0).unwrap()
  let hole_b = s.try_add_circle(second_hole, 3.0).unwrap()

  let relations : Array[@cad.Constraint] = [
    Fix(origin, 0.0, 0.0),
    Horizontal(bottom),
    Vertical(wall),
    Horizontal(roof),
    Vertical(left),
    ArcTangentAt(wall, arc, Start),
    ArcTangentAt(roof, arc, End),
    DistanceX(origin, first_hole, 12.0),
    DistanceY(origin, first_hole, 16.0),
    Horizontal(holes),
    Radius(hole_a, 3.0),
    EqualRadius(hole_a, hole_b),
  ]
  for relation in relations {
    s.try_constrain(relation).unwrap() |> ignore
  }

  {
    sketch: s,
    origin,
    right,
    top,
    arc_start,
    arc_end,
    arc,
    holes,
    second_hole,
    width: s.try_constrain(DistanceX(origin, right, p.width)).unwrap(),
    height: s.try_constrain(DistanceY(origin, top, p.height)).unwrap(),
    hole_pitch: s
    .try_constrain(LengthRatio(holes, bottom, p.hole_pitch / p.width))
    .unwrap(),
    radius: s.try_constrain(ArcRadius(arc, p.corner_radius)).unwrap(),
  }
}

///|
fn Plate::edit(self : Plate, p : Dimensions) -> Unit {
  let s = self.sketch
  s
  .try_set_constraint(self.width, DistanceX(self.origin, self.right, p.width))
  .unwrap()
  s
  .try_set_constraint(self.height, DistanceY(self.origin, self.top, p.height))
  .unwrap()
  // The construction line gives us the hole spacing as a reference measurement.
  let bottom = match s.constraint(self.hole_pitch) {
    Some(LengthRatio(_, line, _)) => line
    _ => abort("Missing hole pitch relation")
  }
  s
  .try_set_constraint(
    self.hole_pitch,
    LengthRatio(self.holes, bottom, p.hole_pitch / p.width),
  )
  .unwrap()
  s
  .try_set_constraint(self.radius, ArcRadius(self.arc, p.corner_radius))
  .unwrap()
}

///|
fn Plate::verify(self : Plate, p : Dimensions) -> Unit {
  let s = self.sketch
  let start = s.point(self.arc_start).unwrap()
  let end = s.point(self.arc_end).unwrap()
  let hole = s.point(self.second_hole).unwrap()
  near(s.point(self.right).unwrap().x, p.width)
  near(s.point(self.top).unwrap().y, p.height)
  near(start.x, p.width)
  near(start.y, p.height - p.corner_radius)
  near(end.x, p.width - p.corner_radius)
  near(end.y, p.height)
  near(hole.x, 12.0 + p.hole_pitch)
  near(hole.y, 16.0)
  near(s.measure(LineLength(self.holes)).unwrap(), p.hole_pitch)
  near(s.measure(ArcRadiusValue(self.arc)).unwrap(), p.corner_radius)
}

///|
fn Plate::solve(self : Plate, p : Dimensions) -> @cad.Solution {
  let solution = self.sketch.solve_and_apply().unwrap()
  require(solution.report.is_satisfied(), "Plate dimensions did not solve")
  self.verify(p)
  solution
}

///|
fn Plate::svg(self : Plate, title : String) -> String {
  self.sketch
  .to_svg(
    options={
      ..@cad.SvgOptions::default(),
      title,
      bounds: Some({ min_x: -5.0, min_y: -5.0, max_x: 90.0, max_y: 60.0, }),
      show_points: false,
    },
    show_construction=true,
  )
  .unwrap()
}

///|
fn emit(stage : String, svg : String, report : @cad.SolveReport) -> Unit {
  println(
    "\{stage} variables=\{report.variables} equations=\{report.equations} iterations=\{report.iterations} qr=\{report.linear_solves} satisfied=\{report.is_satisfied()} tolerance_ratio=\{report.max_tolerance_ratio}",
  )
  println(svg)
}

///|
fn run_plate(show_svg : Bool, sample : Int32) -> Unit {
  let initial = {
    width: 60.0,
    height: 40.0,
    hole_pitch: 25.0,
    corner_radius: 6.0,
  }
  let edited = {
    width: 76.0,
    height: 48.0,
    hole_pitch: 33.0,
    corner_radius: 9.0,
  }
  let plate = new_plate(initial)
  let before = plate.solve(initial)
  if show_svg {
    emit("before", plate.svg("Before"), before.report)
  }
  plate.edit(edited)
  let solve_start = @clock.monotonic_clock_start()
  let after = plate.sketch.solve_and_apply().unwrap()
  let solve_us = @clock.monotonic_clock_end(solve_start)
  require(after.report.is_satisfied(), "Edited dimensions did not solve")
  plate.verify(edited)
  let svg_start = @clock.monotonic_clock_start()
  let saved = plate.svg("After")
  let svg_us = @clock.monotonic_clock_end(svg_start)
  if show_svg {
    emit("after", saved, after.report)
  }
  near(
    before.measure(ArcRadiusValue(plate.arc)).unwrap(),
    initial.corner_radius,
  )

  let s = plate.sketch
  let extra = s.try_constrain(ArcRadius(plate.arc, 12.0)).unwrap()
  let failed = s.solve_and_apply().unwrap()
  require(
    !failed.report.is_satisfied(),
    "Incompatible radii both reported satisfied",
  )
  require(
    plate.svg("After") == saved,
    "Failed solve changed saved SVG geometry",
  )
  if show_svg {
    emit("conflict", plate.svg("Conflict: saved geometry"), failed.report)
  }

  let diagnosis_start = @clock.monotonic_clock_start()
  let diagnosis = s
    .analyze_conflicts(max_subset_solves=16, max_linear_solves=120)
    .unwrap()
  let diagnosis_us = @clock.monotonic_clock_end(diagnosis_start)
  require(!diagnosis.baseline.is_satisfied(), "Expected an unmet baseline")
  require(
    diagnosis.subset_solves > 0 && diagnosis.subset_solves <= 16,
    "Unexpected subset count",
  )
  require(
    diagnosis.charged_linear_solves <= 120,
    "Exceeded diagnostic QR budget",
  )
  require(
    s.constraint_enabled(extra) == Some(true),
    "Diagnosis changed an enabled constraint",
  )
  require(plate.svg("After") == saved, "Diagnosis changed saved SVG geometry")
  require(s.remove_constraint(extra), "Could not remove incompatible dimension")
  let recovered = plate.solve(edited)
  require(plate.svg("After") == saved, "Recovery changed saved SVG geometry")
  if show_svg {
    println(
      "diagnostic subset_solves=\{diagnosis.subset_solves} charged_qr=\{diagnosis.charged_linear_solves} exhausted=\{diagnosis.budget_exhausted}",
    )
    println("recovered=\{recovered.report.is_satisfied()}")
  }
  if sample > 0 {
    println(
      "sample=\{sample} solve_us=\{solve_us} svg_us=\{svg_us} diagnosis_us=\{diagnosis_us} variables=\{after.report.variables} equations=\{after.report.equations} iterations=\{after.report.iterations} qr=\{after.report.linear_solves} tolerance_ratio=\{after.report.max_tolerance_ratio} subset_solves=\{diagnosis.subset_solves} charged_qr=\{diagnosis.charged_linear_solves} exhausted=\{diagnosis.budget_exhausted}",
    )
  }
}

///|
fn main {
  if @env.args().contains("--benchmark") {
    run_plate(false, 0)
    for sample in 1..<=3 {
      run_plate(false, sample)
    }
  } else {
    run_plate(true, 0)
  }
}
