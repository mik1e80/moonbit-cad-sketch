///|
/// Read-only reference dimensions. These never create solver equations.
#derive(Debug)
pub(all) enum Measurement {
  PointDistance(PointId, PointId)
  LineLength(LineId)
  CircleRadius(CircleId)
  CircleDiameter(CircleId)
  LineAngle(LineId, LineId)
  ArcRadiusValue(ArcId)
  ArcSweepValue(ArcId)
  ArcLengthValue(ArcId)
}

///|
fn measurement_geometry(m : Measurement) -> Array[GeometryId] {
  match m {
    PointDistance(a, b) => [PointGeometry(a), PointGeometry(b)]
    LineLength(l) => [LineGeometry(l)]
    CircleRadius(c) | CircleDiameter(c) => [CircleGeometry(c)]
    LineAngle(a, b) => [LineGeometry(a), LineGeometry(b)]
    ArcRadiusValue(a) | ArcSweepValue(a) | ArcLengthValue(a) => [ArcGeometry(a)]
  }
}

///|
fn measure_value(
  m : Measurement,
  point : (PointId) -> Point?,
  line : (LineId) -> (PointId, PointId)?,
  circle : (CircleId) -> Double?,
  arc : (ArcId) -> ArcShape?,
) -> Result[Double, SketchError] {
  let missing = InvalidGeometry("Missing or invalid measurement geometry")
  let value = match m {
    PointDistance(a, b) => {
      let a = match point(a) {
        Some(p) => p
        None => return Err(missing)
      }
      let b = match point(b) {
        Some(p) => p
        None => return Err(missing)
      }
      @math.hypot(b.x - a.x, b.y - a.y)
    }
    LineLength(l) => {
      let (a, b) = match line(l) {
        Some(x) => x
        None => return Err(missing)
      }
      let a = match point(a) {
        Some(p) => p
        None => return Err(missing)
      }
      let b = match point(b) {
        Some(p) => p
        None => return Err(missing)
      }
      let n = @math.hypot(b.x - a.x, b.y - a.y)
      if n <= 0.0 {
        return Err(DegenerateLine(l))
      }
      n
    }
    CircleRadius(c) | CircleDiameter(c) => {
      let r = match circle(c) {
        Some(r) => r
        None => return Err(missing)
      }
      if r <= 0.0 {
        return Err(InvalidRadius(c))
      }
      match m {
        CircleDiameter(_) => r * 2.0
        _ => r
      }
    }
    LineAngle(a, b) => {
      let (ap, aq) = match line(a) {
        Some(x) => x
        None => return Err(missing)
      }
      let (bp, bq) = match line(b) {
        Some(x) => x
        None => return Err(missing)
      }
      let ap = match point(ap) {
        Some(p) => p
        None => return Err(missing)
      }
      let aq = match point(aq) {
        Some(p) => p
        None => return Err(missing)
      }
      let bp = match point(bp) {
        Some(p) => p
        None => return Err(missing)
      }
      let bq = match point(bq) {
        Some(p) => p
        None => return Err(missing)
      }
      let an = @math.hypot(aq.x - ap.x, aq.y - ap.y)
      let bn = @math.hypot(bq.x - bp.x, bq.y - bp.y)
      if an <= 0.0 {
        return Err(DegenerateLine(a))
      }
      if bn <= 0.0 {
        return Err(DegenerateLine(b))
      }
      let ax = (aq.x - ap.x) / an
      let ay = (aq.y - ap.y) / an
      let bx = (bq.x - bp.x) / bn
      let by = (bq.y - bp.y) / bn
      @math.atan2(ax * by - ay * bx, ax * bx + ay * by)
    }
    ArcRadiusValue(a) | ArcSweepValue(a) | ArcLengthValue(a) => {
      let shape = match arc(a) {
        Some(s) => s
        None => return Err(missing)
      }
      let r = shape.radius()
      let t = shape.sweep()
      if r <= 0.0 || t <= 1.0e-12 || t >= 2.0 * @math.PI - 1.0e-12 {
        return Err(InvalidArc(a))
      }
      match m {
        ArcRadiusValue(_) => r
        ArcSweepValue(_) => t
        _ => r * t
      }
    }
  }
  if !finite(value) {
    Err(InvalidGeometry("Nonfinite measurement"))
  } else {
    Ok(value)
  }
}

///|
/// Measure current geometry without solving or adding a driving constraint.
/// ```mbt check
/// test {
///   let s = @sketch.Sketch::new()
///   let a = s.try_add_point(0.0, 0.0).unwrap()
///   let b = s.try_add_point(3.0, 4.0).unwrap()
///   assert_eq(s.measure(@sketch.PointDistance(a, b)).unwrap(), 5.0)
/// }
/// ```
pub fn Sketch::measure(
  self : Sketch,
  m : Measurement,
) -> Result[Double, SketchError] {
  if measurement_geometry(m).any(g => !self.geometry_owned(g)) {
    return Err(ForeignHandle)
  }
  measure_value(
    m,
    p => self.point(p),
    l => self.line_slot(l).map(i => (self.lines[i].a, self.lines[i].b)),
    c => self.radius(c),
    a => {
      self
      .arc(a)
      .map(g => {
        center: self.point(g.center).unwrap(),
        start: self.point(g.start).unwrap(),
        end: self.point(g.end).unwrap(),
        direction: g.direction,
      })
    },
  )
}

///|
/// Measure the solve-time snapshot, independently of subsequent live edits.
pub fn Solution::measure(
  self : Solution,
  m : Measurement,
) -> Result[Double, SketchError] {
  let owner = match m {
    PointDistance(a, _) => a.owner
    LineLength(l) | LineAngle(l, _) => l.owner
    CircleRadius(c) | CircleDiameter(c) => c.owner
    ArcRadiusValue(a) | ArcSweepValue(a) | ArcLengthValue(a) => a.owner
  }
  if !physical_equal(self.owner, owner) {
    return Err(ForeignHandle)
  }
  for g in measurement_geometry(m) {
    let owned = match g {
      PointGeometry(p) => physical_equal(self.owner, p.owner)
      LineGeometry(l) => physical_equal(self.owner, l.owner)
      CircleGeometry(c) => physical_equal(self.owner, c.owner)
      ArcGeometry(a) => physical_equal(self.owner, a.owner)
    }
    if !owned {
      return Err(ForeignHandle)
    }
  }
  measure_value(
    m,
    p => self.point(p),
    l => {
      if !physical_equal(self.owner, l.owner) {
        None
      } else {
        let mut found = None
        for i, stored in self.line_ids {
          if stored.index == l.index {
            found = Some((self.lines[i].a, self.lines[i].b))
          }
        }
        found
      }
    },
    c => self.radius(c),
    a => self.arc(a),
  )
}

///|
#derive(Debug)
pub struct Rectangle {
  corners : Array[PointId]
  edges : Array[LineId]
}

///|
/// Axis-aligned rectangle geometry only. Add driving constraints explicitly.
pub fn Sketch::try_add_rectangle(
  self : Sketch,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
) -> Result[Rectangle, SketchError] {
  if !bounded(x) ||
    !bounded(y) ||
    !bounded(width) ||
    !bounded(height) ||
    width <= 0.0 ||
    height <= 0.0 ||
    !bounded(x + width) ||
    !bounded(y + height) ||
    x + width == x ||
    y + height == y {
    return Err(
      InvalidGeometry(
        "Rectangle requires representable finite corners and positive dimensions",
      ),
    )
  }
  if self.points.length() * 2 + self.circles.length() > 248 ||
    self.lines.length() > 508 {
    return Err(ResourceLimit)
  }
  if self.next_geometry[0] > 2147483643 || self.next_geometry[1] > 2147483643 {
    return Err(IdentifierExhausted)
  }
  let a = self.add_point(x, y)
  let b = self.add_point(x + width, y)
  let c = self.add_point(x + width, y + height)
  let d = self.add_point(x, y + height)
  Ok({
    corners: [a, b, c, d],
    edges: [
      self.add_line(a, b),
      self.add_line(b, c),
      self.add_line(c, d),
      self.add_line(d, a),
    ],
  })
}

///|
pub extend Measurement with @debug.Debug::{to_repr}

///|
pub extend Rectangle with @debug.Debug::{to_repr}
