///|
fn Sketch::arc_vectors(
  self : Sketch,
  id : ArcId,
  vars : Array[Jet],
) -> (Jet, Jet, Jet, Jet) {
  let a = self.arc(id).unwrap()
  let (cx, cy) = self.point_jets(a.center, vars)
  let (sx, sy) = self.point_jets(a.start, vars)
  let (ex, ey) = self.point_jets(a.end, vars)
  (sx.minus(cx), sy.minus(cy), ex.minus(cx), ey.minus(cy))
}

///|
fn positive_jet_angle(
  ax : Jet,
  ay : Jet,
  bx : Jet,
  by : Jet,
  direction : ArcDirection,
) -> Jet {
  let na = jet_norm(ax, ay)
  let nb = jet_norm(bx, by)
  let ax = ax.divide(na)
  let ay = ay.divide(na)
  let bx = bx.divide(nb)
  let by = by.divide(nb)
  let angle = jet_angle(jet_cross(ax, ay, bx, by), jet_dot(ax, ay, bx, by))
  let angle = if direction == Clockwise { angle.scale(-1.0) } else { angle }
  if angle.v < 0.0 {
    angle.offset(2.0 * @math.PI)
  } else {
    angle
  }
}

///|
fn Sketch::arc_radius_jet(self : Sketch, id : ArcId, vars : Array[Jet]) -> Jet {
  let (x, y, _, _) = self.arc_vectors(id, vars)
  jet_norm(x, y)
}

///|
fn Sketch::arc_sweep_jet(self : Sketch, id : ArcId, vars : Array[Jet]) -> Jet {
  let (ax, ay, bx, by) = self.arc_vectors(id, vars)
  positive_jet_angle(ax, ay, bx, by, self.arc(id).unwrap().direction)
}

///|
fn Sketch::arc_endpoint_vector(
  self : Sketch,
  id : ArcId,
  e : ArcEndpoint,
  vars : Array[Jet],
) -> (Jet, Jet) {
  let (ax, ay, bx, by) = self.arc_vectors(id, vars)
  match e {
    Start => (ax, ay)
    End => (bx, by)
  }
}

///|
fn normalized_cross(ax : Jet, ay : Jet, bx : Jet, by : Jet) -> Jet {
  let a = jet_norm(ax, ay)
  let b = jet_norm(bx, by)
  jet_cross(ax.divide(a), ay.divide(a), bx.divide(b), by.divide(b))
}

///|
fn Sketch::arc_intrinsic_rows(
  self : Sketch,
  vars : Array[Jet],
  geometry_scale : Double,
) -> Result[Array[Row], SketchError] {
  let rows = []
  for i, id in self.arc_ids {
    let (ax, ay, bx, by) = self.arc_vectors(id, vars)
    let radius = jet_norm(ax, ay)
    let other = jet_norm(bx, by)
    if radius.v <= geometry_scale * 1.0e-12 ||
      other.v <= geometry_scale * 1.0e-12 ||
      @math.hypot(ax.v - bx.v, ay.v - by.v) <= geometry_scale * 1.0e-12 {
      return Err(InvalidArc(id))
    }
    let sweep = self.arc_sweep_jet(id, vars)
    if sweep.v <= 1.0e-12 || sweep.v >= 2.0 * @math.PI - 1.0e-12 {
      return Err(InvalidArc(id))
    }
    push_rows(rows, [radius.minus(other)], -i - 1, false)
  }
  Ok(rows)
}
