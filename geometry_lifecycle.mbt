///|
#derive(Debug, Eq)
pub(all) enum GeometryRole {
  ModelGeometry
  ConstructionGeometry
}

///|
#derive(Debug)
pub(all) enum GeometryId {
  PointGeometry(PointId)
  LineGeometry(LineId)
  CircleGeometry(CircleId)
  ArcGeometry(ArcId)
}

///|
fn Sketch::point_slot(self : Sketch, id : PointId) -> Int32? {
  if !physical_equal(self.owner, id.owner) {
    return None
  }
  for i, p in self.point_ids {
    if p.index == id.index {
      return Some(i)
    }
  }
  None
}

///|
fn Sketch::line_slot(self : Sketch, id : LineId) -> Int32? {
  if !physical_equal(self.owner, id.owner) {
    return None
  }
  for i, p in self.line_ids {
    if p.index == id.index {
      return Some(i)
    }
  }
  None
}

///|
fn Sketch::circle_slot(self : Sketch, id : CircleId) -> Int32? {
  if !physical_equal(self.owner, id.owner) {
    return None
  }
  for i, p in self.circle_ids {
    if p.index == id.index {
      return Some(i)
    }
  }
  None
}

///|
fn geometry_same(a : GeometryId, b : GeometryId) -> Bool {
  match (a, b) {
    (PointGeometry(a), PointGeometry(b)) =>
      physical_equal(a.owner, b.owner) && a.index == b.index
    (LineGeometry(a), LineGeometry(b)) =>
      physical_equal(a.owner, b.owner) && a.index == b.index
    (CircleGeometry(a), CircleGeometry(b)) =>
      physical_equal(a.owner, b.owner) && a.index == b.index
    (ArcGeometry(a), ArcGeometry(b)) =>
      physical_equal(a.owner, b.owner) && a.index == b.index
    _ => false
  }
}

///|
fn geometry_key(g : GeometryId) -> String {
  match g {
    PointGeometry(p) => "p:\{p.index}"
    LineGeometry(l) => "l:\{l.index}"
    CircleGeometry(c) => "c:\{c.index}"
    ArcGeometry(a) => "a:\{a.index}"
  }
}

///|
fn Sketch::geometry_owned(self : Sketch, g : GeometryId) -> Bool {
  match g {
    PointGeometry(p) => physical_equal(self.owner, p.owner)
    LineGeometry(l) => physical_equal(self.owner, l.owner)
    CircleGeometry(c) => physical_equal(self.owner, c.owner)
    ArcGeometry(a) => physical_equal(self.owner, a.owner)
  }
}

///|
fn Sketch::geometry_exists(self : Sketch, g : GeometryId) -> Bool {
  match g {
    PointGeometry(p) => self.valid_point(p)
    LineGeometry(l) => self.valid_line(l)
    CircleGeometry(c) => self.valid_circle(c)
    ArcGeometry(a) => self.valid_arc(a)
  }
}

///|
fn constraint_geometry(c : Constraint) -> Array[GeometryId] {
  match c {
    Fix(p, _, _) => [PointGeometry(p)]
    Coincident(a, b)
    | Distance(a, b, _)
    | DistanceX(a, b, _)
    | DistanceY(a, b, _) => [PointGeometry(a), PointGeometry(b)]
    Symmetric(a, b, c) => [PointGeometry(a), PointGeometry(b), PointGeometry(c)]
    Mirror(a, b, l) => [PointGeometry(a), PointGeometry(b), LineGeometry(l)]
    Horizontal(l) | Vertical(l) => [LineGeometry(l)]
    Parallel(a, b)
    | Perpendicular(a, b)
    | Angle(a, b, _)
    | EqualLength(a, b)
    | LengthRatio(a, b, _) => [LineGeometry(a), LineGeometry(b)]
    Midpoint(p, l) | PointOnLine(p, l) | DistanceToLine(p, l, _) =>
      [PointGeometry(p), LineGeometry(l)]
    Radius(c, _) | Diameter(c, _) => [CircleGeometry(c)]
    EqualRadius(a, b)
    | Concentric(a, b)
    | ExternalTangent(a, b)
    | InternalTangent(a, b) => [CircleGeometry(a), CircleGeometry(b)]
    PointOnCircle(p, c) => [PointGeometry(p), CircleGeometry(c)]
    Tangent(l, c) => [LineGeometry(l), CircleGeometry(c)]
    ArcRadius(a, _) | ArcDiameter(a, _) | ArcSweep(a, _) | ArcLength(a, _) =>
      [ArcGeometry(a)]
    EqualArcRadius(a, b) | ArcConcentric(a, b) | ArcArcTangentAt(a, _, b, _) =>
      [ArcGeometry(a), ArcGeometry(b)]
    EqualCircleArcRadius(c, a)
    | CircleArcConcentric(c, a)
    | ArcCircleTangentAt(a, _, c) => [CircleGeometry(c), ArcGeometry(a)]
    ArcTangentAt(l, a, _) => [LineGeometry(l), ArcGeometry(a)]
    PointOnArc(p, a) => [PointGeometry(p), ArcGeometry(a)]
  }
}

///|
fn Sketch::geometry_in_use(self : Sketch, g : GeometryId) -> Bool {
  if self.constraints.any(c => {
      constraint_geometry(c).any(reference => geometry_same(reference, g))
    }) {
    return true
  }
  match g {
    PointGeometry(p) =>
      self.lines.any(l => {
        geometry_same(PointGeometry(l.a), g) ||
        geometry_same(PointGeometry(l.b), g)
      }) ||
      self.circles.any(c => geometry_same(PointGeometry(c.center), g)) ||
      self.arcs.any(a => {
        geometry_same(PointGeometry(a.center), PointGeometry(p)) ||
        geometry_same(PointGeometry(a.start), g) ||
        geometry_same(PointGeometry(a.end), g)
      })
    _ => false
  }
}

///|
/// Remove only unreferenced geometry. Disabled constraints still own references.
/// IDs are never reused; other IDs and old solution snapshots remain stable.
/// ```mbt check
/// test {
///   let s = @sketch.Sketch::new()
///   let p = s.try_add_point(0.0, 0.0).unwrap()
///   assert_true(s.remove_point(p).unwrap())
///   assert_true(s.point(p) is None)
/// }
/// ```
pub fn Sketch::remove_geometry(
  self : Sketch,
  g : GeometryId,
) -> Result[Bool, SketchError] {
  if !self.geometry_owned(g) {
    return Err(ForeignHandle)
  }
  if !self.geometry_exists(g) {
    return Ok(false)
  }
  if self.geometry_in_use(g) {
    return Err(GeometryInUse(g))
  }
  match g {
    PointGeometry(p) => {
      let i = self.point_slot(p).unwrap()
      self.points.remove(i) |> ignore
      self.point_ids.remove(i) |> ignore
    }
    LineGeometry(l) => {
      let i = self.line_slot(l).unwrap()
      self.lines.remove(i) |> ignore
      self.line_ids.remove(i) |> ignore
    }
    CircleGeometry(c) => {
      let i = self.circle_slot(c).unwrap()
      self.circles.remove(i) |> ignore
      self.circle_ids.remove(i) |> ignore
    }
    ArcGeometry(a) => {
      let i = self.arc_slot(a).unwrap()
      self.arcs.remove(i) |> ignore
      self.arc_ids.remove(i) |> ignore
    }
  }
  self.roles.remove(geometry_key(g)) |> ignore
  Ok(true)
}

///|
pub fn Sketch::remove_point(
  self : Sketch,
  p : PointId,
) -> Result[Bool, SketchError] {
  self.remove_geometry(PointGeometry(p))
}

///|
pub fn Sketch::remove_line(
  self : Sketch,
  l : LineId,
) -> Result[Bool, SketchError] {
  self.remove_geometry(LineGeometry(l))
}

///|
pub fn Sketch::remove_circle(
  self : Sketch,
  c : CircleId,
) -> Result[Bool, SketchError] {
  self.remove_geometry(CircleGeometry(c))
}

///|
pub fn Sketch::remove_arc(
  self : Sketch,
  a : ArcId,
) -> Result[Bool, SketchError] {
  self.remove_geometry(ArcGeometry(a))
}

///|
pub fn Sketch::geometry_role(
  self : Sketch,
  g : GeometryId,
) -> Result[GeometryRole, SketchError] {
  if !self.geometry_owned(g) {
    return Err(ForeignHandle)
  }
  if !self.geometry_exists(g) {
    return Err(InvalidGeometry("Missing geometry role target"))
  }
  Ok(self.roles.get(geometry_key(g)).unwrap_or(ModelGeometry))
}

///|
/// Construction geometry still participates in solving; SVG visibility is separate.
/// ```mbt check
/// test {
///   let s = @sketch.Sketch::new()
///   let p = s.try_add_point(0.0, 0.0).unwrap()
///   s
///   .set_geometry_role(@sketch.PointGeometry(p), @sketch.ConstructionGeometry)
///   .unwrap()
///   assert_true(
///     s.geometry_role(@sketch.PointGeometry(p)).unwrap() is ConstructionGeometry,
///   )
/// }
/// ```
pub fn Sketch::set_geometry_role(
  self : Sketch,
  g : GeometryId,
  role : GeometryRole,
) -> Result[Unit, SketchError] {
  match self.geometry_role(g) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  self.roles[geometry_key(g)] = role
  Ok(())
}

///|
fn Sketch::construction(self : Sketch, g : GeometryId) -> Bool {
  self.roles.get(geometry_key(g)) is Some(ConstructionGeometry)
}

///|
pub extend GeometryRole with @debug.Debug::{to_repr}

///|
pub extend GeometryId with @debug.Debug::{to_repr}

///|
pub extend GeometryRole with Eq::{equal, not_equal}
