///|
pub struct ArcId {
  index : Int32
  priv owner : Array[Unit]
} derive(Debug)

///|
pub(all) enum ArcDirection {
  CounterClockwise
  Clockwise
} derive(Debug, Eq)

///|
pub(all) enum ArcEndpoint {
  Start
  End
} derive(Debug, Eq)

///|
pub struct Arc {
  center : PointId
  start : PointId
  end : PointId
  direction : ArcDirection
} derive(Debug)

///|
pub struct ArcShape {
  center : Point
  start : Point
  end : Point
  direction : ArcDirection
} derive(Debug)

///|
fn Sketch::arc_slot(self : Sketch, id : ArcId) -> Int32? {
  if !physical_equal(self.owner, id.owner) {
    return None
  }
  for i, a in self.arc_ids {
    if a.index == id.index {
      return Some(i)
    }
  }
  None
}

///|
fn Sketch::valid_arc(self : Sketch, id : ArcId) -> Bool {
  self.arc_slot(id) is Some(_)
}

///|
fn arc_endpoint(a : Arc, endpoint : ArcEndpoint) -> PointId {
  match endpoint {
    Start => a.start
    End => a.end
  }
}

///|
fn directed_sweep(
  cx : Double,
  cy : Double,
  sx : Double,
  sy : Double,
  ex : Double,
  ey : Double,
  direction : ArcDirection,
) -> Double {
  let ax = sx - cx
  let ay = sy - cy
  let bx = ex - cx
  let by = ey - cy
  let na = @math.hypot(ax, ay)
  let nb = @math.hypot(bx, by)
  let ax = ax / na
  let ay = ay / na
  let bx = bx / nb
  let by = by / nb
  let t = @math.atan2(ax * by - ay * bx, ax * bx + ay * by)
  let t = if direction == Clockwise { -t } else { t }
  if t < 0.0 {
    t + 2.0 * @math.PI
  } else {
    t
  }
}

///|
fn Sketch::arc_definition_valid(self : Sketch, a : Arc) -> Bool {
  if !self.valid_point(a.center) ||
    !self.valid_point(a.start) ||
    !self.valid_point(a.end) {
    return false
  }
  let c = self.point(a.center).unwrap()
  let s = self.point(a.start).unwrap()
  let e = self.point(a.end).unwrap()
  bounded(c.x) &&
  bounded(c.y) &&
  bounded(s.x) &&
  bounded(s.y) &&
  bounded(e.x) &&
  bounded(e.y) &&
  (c.x != s.x || c.y != s.y) &&
  (c.x != e.x || c.y != e.y) &&
  (s.x != e.x || s.y != e.y) &&
  directed_sweep(c.x, c.y, s.x, s.y, e.x, e.y, a.direction) > 1.0e-12 &&
  directed_sweep(c.x, c.y, s.x, s.y, e.x, e.y, a.direction) <
  2.0 * @math.PI - 1.0e-12
}

///|
/// Create a finite directed arc. Its equal endpoint radii are an intrinsic solve
/// equation. Unequal initial radii may be solved; zero/full arcs are rejected.
/// ```mbt check
/// test {
///   let s = @sketch.Sketch::new()
///   let c = s.try_add_point(0.0, 0.0).unwrap()
///   let a = s.try_add_point(2.0, 0.0).unwrap()
///   let b = s.try_add_point(0.0, 2.0).unwrap()
///   let arc = s.try_add_arc(c, a, b, @sketch.CounterClockwise).unwrap()
///   assert_eq(s.arc_radius(arc).unwrap(), 2.0)
/// }
/// ```
pub fn Sketch::try_add_arc(
  self : Sketch,
  center : PointId,
  start : PointId,
  end : PointId,
  direction : ArcDirection,
) -> Result[ArcId, SketchError] {
  if self.arcs.length() >= 128 {
    return Err(ResourceLimit)
  }
  if self.next_geometry[3] == 2147483647 {
    return Err(IdentifierExhausted)
  }
  if !physical_equal(self.owner, center.owner) ||
    !physical_equal(self.owner, start.owner) ||
    !physical_equal(self.owner, end.owner) {
    return Err(ForeignHandle)
  }
  let a : Arc = { center, start, end, direction, }
  let id : ArcId = { index: self.next_geometry[3], owner: self.owner, }
  if !self.arc_definition_valid(a) {
    return Err(InvalidArc(id))
  }
  self.arcs.push(a)
  self.arc_ids.push(id)
  self.next_geometry[3] += 1
  Ok(id)
}

///|
pub fn Sketch::arc(self : Sketch, id : ArcId) -> Arc? {
  self.arc_slot(id).map(i => self.arcs[i])
}

///|
pub fn Sketch::try_set_arc(
  self : Sketch,
  id : ArcId,
  center : PointId,
  start : PointId,
  end : PointId,
  direction : ArcDirection,
) -> Result[Unit, SketchError] {
  if !physical_equal(self.owner, id.owner) ||
    !physical_equal(self.owner, center.owner) ||
    !physical_equal(self.owner, start.owner) ||
    !physical_equal(self.owner, end.owner) {
    return Err(ForeignHandle)
  }
  let i = match self.arc_slot(id) {
    Some(i) => i
    None => return Err(InvalidArc(id))
  }
  let a : Arc = { center, start, end, direction, }
  if !self.arc_definition_valid(a) {
    return Err(InvalidArc(id))
  }
  // Existing endpoint-tangent definitions must remain valid after replacement.
  let old = self.arcs[i]
  self.arcs[i] = a
  let valid = self.constraints.all(c => {
    if constraint_geometry(c).any(g => geometry_same(g, ArcGeometry(id))) {
      self.constraint_valid(c)
    } else {
      true
    }
  })
  self.arcs[i] = old
  if !valid {
    return Err(InvalidArc(id))
  }
  self.arcs[i] = a
  Ok(())
}

///|
pub fn Sketch::arc_radius(self : Sketch, id : ArcId) -> Double? {
  self
  .arc(id)
  .map(a => {
    let c = self.point(a.center).unwrap()
    let s = self.point(a.start).unwrap()
    @math.hypot(s.x - c.x, s.y - c.y)
  })
}

///|
pub fn Sketch::arc_sweep(self : Sketch, id : ArcId) -> Double? {
  self
  .arc(id)
  .map(a => {
    let c = self.point(a.center).unwrap()
    let s = self.point(a.start).unwrap()
    let e = self.point(a.end).unwrap()
    directed_sweep(c.x, c.y, s.x, s.y, e.x, e.y, a.direction)
  })
}

///|
/// Read the solve-time arc, even if its live geometry was later edited/deleted.
pub fn Solution::arc(self : Solution, id : ArcId) -> ArcShape? {
  if !physical_equal(self.owner, id.owner) {
    return None
  }
  for i, stored in self.arc_ids {
    if stored.index == id.index {
      let a = self.arcs[i]
      return Some({
        center: self.point(a.center).unwrap(),
        start: self.point(a.start).unwrap(),
        end: self.point(a.end).unwrap(),
        direction: a.direction,
      })
    }
  }
  None
}

///|
pub fn ArcShape::radius(self : ArcShape) -> Double {
  @math.hypot(self.start.x - self.center.x, self.start.y - self.center.y)
}

///|
pub fn ArcShape::sweep(self : ArcShape) -> Double {
  directed_sweep(
    self.center.x,
    self.center.y,
    self.start.x,
    self.start.y,
    self.end.x,
    self.end.y,
    self.direction,
  )
}

///|
pub extend ArcId with @debug.Debug::{to_repr}

///|
pub extend ArcDirection with @debug.Debug::{to_repr}

///|
pub extend ArcEndpoint with @debug.Debug::{to_repr}

///|
pub extend Arc with @debug.Debug::{to_repr}

///|
pub extend ArcShape with @debug.Debug::{to_repr}

///|
pub extend ArcDirection with Eq::{equal, not_equal}

///|
pub extend ArcEndpoint with Eq::{equal, not_equal}
