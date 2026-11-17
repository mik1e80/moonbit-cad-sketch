///|
priv struct Row {
  jet : Jet
  slot : Int32
  angular : Bool
}

///|
fn Sketch::point_jets(
  self : Sketch,
  p : PointId,
  vars : Array[Jet],
) -> (Jet, Jet) {
  (
    vars[self.point_slot(p).unwrap() * 2],
    vars[self.point_slot(p).unwrap() * 2 + 1],
  )
}

///|
fn Sketch::line_jets(
  self : Sketch,
  l : LineId,
  vars : Array[Jet],
) -> (Jet, Jet) {
  let line = self.lines[self.line_slot(l).unwrap()]
  let (ax, ay) = self.point_jets(line.a, vars)
  let (bx, by) = self.point_jets(line.b, vars)
  (bx.minus(ax), by.minus(ay))
}

///|
fn Sketch::circle_jets(
  self : Sketch,
  c : CircleId,
  vars : Array[Jet],
) -> (Jet, Jet, Jet) {
  let (x, y) = self.point_jets(
    self.circles[self.circle_slot(c).unwrap()].center,
    vars,
  )
  (x, y, vars[self.points.length() * 2 + self.circle_slot(c).unwrap()])
}

///|
fn push_rows(
  out : Array[Row],
  jets : Array[Jet],
  slot : Int32,
  angular : Bool,
) -> Unit {
  for jet in jets {
    out.push({ jet, slot, angular, })
  }
}

///|
/// Signed perpendicular distance; positive is to the left of the directed line.
fn Sketch::signed_line_distance(
  self : Sketch,
  p : PointId,
  l : LineId,
  vars : Array[Jet],
) -> Jet {
  let (px, py) = self.point_jets(p, vars)
  let (ax, ay) = self.point_jets(self.lines[self.line_slot(l).unwrap()].a, vars)
  let (dx, dy) = self.line_jets(l, vars)
  let length = jet_norm(dx, dy)
  jet_cross(dx.divide(length), dy.divide(length), px.minus(ax), py.minus(ay))
}

///|
/// The returned residuals use normalized length units (or radians / unitless
/// direction error for angular constraints). Tolerance weighting happens later.
fn Sketch::evaluate(
  self : Sketch,
  x : Array[Double],
  frame : Frame,
  geometry_scale~ : Double = 1.0,
) -> Result[Array[Row], SketchError] {
  if x.any(v => !finite(v)) {
    return Err(NumericalFailure("Nonfinite parameter during evaluation"))
  }
  for i = self.points.length() * 2; i < x.length(); i = i + 1 {
    if x[i] <= geometry_scale * 1.0e-14 {
      let circle = i - self.points.length() * 2
      return Err(InvalidRadius(self.circle_id(circle)))
    }
  }
  let vars = Array::makei(x.length(), i => variable(x[i], i, x.length()))
  for i = 0; i < self.lines.length(); i = i + 1 {
    let (dx, dy) = self.line_jets(self.line_id(i), vars)
    if @math.hypot(dx.v, dy.v) <= geometry_scale * 1.0e-12 {
      return Err(DegenerateLine(self.line_id(i)))
    }
  }
  let out = match self.arc_intrinsic_rows(vars, geometry_scale) {
    Ok(rows) => rows
    Err(e) => return Err(e)
  }
  for i, c in self.constraints {
    if !self.enabled[i] {
      continue
    }
    let mut angular = false
    let jets = match c {
      Fix(p, x, y) => {
        let (px, py) = self.point_jets(p, vars)
        [
          px.offset(-(x - frame.x) / frame.scale),
          py.offset(-(y - frame.y) / frame.scale),
        ]
      }
      Coincident(a, b) => {
        let (ax, ay) = self.point_jets(a, vars)
        let (bx, by) = self.point_jets(b, vars)
        [bx.minus(ax), by.minus(ay)]
      }
      Symmetric(a, b, center) => {
        let (ax, ay) = self.point_jets(a, vars)
        let (bx, by) = self.point_jets(b, vars)
        let (cx, cy) = self.point_jets(center, vars)
        [ax.plus(bx).minus(cx.scale(2.0)), ay.plus(by).minus(cy.scale(2.0))]
      }
      Mirror(a, b, axis) => {
        let (ax, ay) = self.point_jets(a, vars)
        let (bx, by) = self.point_jets(b, vars)
        let (ox, oy) = self.point_jets(
          self.lines[self.line_slot(axis).unwrap()].a,
          vars,
        )
        let (dx, dy) = self.line_jets(axis, vars)
        let length = jet_norm(dx, dy)
        let ux = dx.divide(length)
        let uy = dy.divide(length)
        // Tangential coordinates agree; signed normal distances sum to zero.
        // Both rows are lengths, including when the points coincide on the axis.
        [
          jet_dot(bx.minus(ax), by.minus(ay), ux, uy),
          jet_cross(
            ux,
            uy,
            ax.minus(ox).plus(bx.minus(ox)).scale(0.5),
            ay.minus(oy).plus(by.minus(oy)).scale(0.5),
          ),
        ]
      }
      Horizontal(l) => {
        let (_, dy) = self.line_jets(l, vars)
        [dy]
      }
      Vertical(l) => {
        let (dx, _) = self.line_jets(l, vars)
        [dx]
      }
      Distance(a, b, d) => {
        let (ax, ay) = self.point_jets(a, vars)
        let (bx, by) = self.point_jets(b, vars)
        if d == 0.0 {
          [bx.minus(ax), by.minus(ay)]
        } else {
          [jet_norm(bx.minus(ax), by.minus(ay)).offset(-d / frame.scale)]
        }
      }
      DistanceX(a, b, d) => {
        let (ax, _) = self.point_jets(a, vars)
        let (bx, _) = self.point_jets(b, vars)
        [bx.minus(ax).offset(-d / frame.scale)]
      }
      DistanceY(a, b, d) => {
        let (_, ay) = self.point_jets(a, vars)
        let (_, by) = self.point_jets(b, vars)
        [by.minus(ay).offset(-d / frame.scale)]
      }
      Parallel(a, b) | Perpendicular(a, b) | Angle(a, b, _) => {
        angular = true
        let (ax, ay) = self.line_jets(a, vars)
        let (bx, by) = self.line_jets(b, vars)
        let na = jet_norm(ax, ay)
        let nb = jet_norm(bx, by)
        let ax = ax.divide(na)
        let ay = ay.divide(na)
        let bx = bx.divide(nb)
        let by = by.divide(nb)
        let cross = jet_cross(ax, ay, bx, by)
        let dot = jet_dot(ax, ay, bx, by)
        match c {
          Parallel(_, _) => [cross]
          Perpendicular(_, _) => [dot]
          Angle(_, _, t) => {
            // Rotate the unit pair by -t before atan2: principal wrapped error.
            let y = cross.scale(@math.cos(t)).minus(dot.scale(@math.sin(t)))
            let x = dot.scale(@math.cos(t)).plus(cross.scale(@math.sin(t)))
            [jet_angle(y, x)]
          }
          _ => []
        }
      }
      EqualLength(a, b) => {
        let (ax, ay) = self.line_jets(a, vars)
        let (bx, by) = self.line_jets(b, vars)
        [jet_norm(ax, ay).minus(jet_norm(bx, by))]
      }
      LengthRatio(a, b, ratio) => {
        let (ax, ay) = self.line_jets(a, vars)
        let (bx, by) = self.line_jets(b, vars)
        [jet_norm(ax, ay).minus(jet_norm(bx, by).scale(ratio))]
      }
      Midpoint(p, l) => {
        let (px, py) = self.point_jets(p, vars)
        let line = self.lines[self.line_slot(l).unwrap()]
        let (ax, ay) = self.point_jets(line.a, vars)
        let (bx, by) = self.point_jets(line.b, vars)
        [px.minus(ax.plus(bx).scale(0.5)), py.minus(ay.plus(by).scale(0.5))]
      }
      PointOnLine(p, l) => [self.signed_line_distance(p, l, vars)]
      DistanceToLine(p, l, d) =>
        [self.signed_line_distance(p, l, vars).offset(-d / frame.scale)]
      Radius(c, r) => {
        let (_, _, radius) = self.circle_jets(c, vars)
        [radius.offset(-r / frame.scale)]
      }
      EqualRadius(a, b) => {
        let (_, _, ar) = self.circle_jets(a, vars)
        let (_, _, br) = self.circle_jets(b, vars)
        [ar.minus(br)]
      }
      Concentric(a, b) => {
        let (ax, ay, _) = self.circle_jets(a, vars)
        let (bx, by, _) = self.circle_jets(b, vars)
        [bx.minus(ax), by.minus(ay)]
      }
      PointOnCircle(p, c) => {
        let (px, py) = self.point_jets(p, vars)
        let (cx, cy, r) = self.circle_jets(c, vars)
        [jet_norm(px.minus(cx), py.minus(cy)).minus(r)]
      }
      Tangent(l, c) => {
        let (_, _, r) = self.circle_jets(c, vars)
        let distance = self.signed_line_distance(
          self.circles[self.circle_slot(c).unwrap()].center,
          l,
          vars,
        )
        let sign = if distance.v < 0.0 { -1.0 } else { 1.0 }
        [distance.scale(sign).minus(r)]
      }
      ExternalTangent(a, b) => {
        let (ax, ay, ar) = self.circle_jets(a, vars)
        let (bx, by, br) = self.circle_jets(b, vars)
        [jet_norm(bx.minus(ax), by.minus(ay)).minus(ar.plus(br))]
      }
      InternalTangent(outer, inner) => {
        let (ax, ay, ar) = self.circle_jets(outer, vars)
        let (bx, by, br) = self.circle_jets(inner, vars)
        let difference = ar.minus(br)
        // Equal coincident circles have infinitely many contacts, not an
        // isolated tangency. Keep the caller's outer/inner branch explicit.
        if difference.v <= geometry_scale * 1.0e-12 {
          return Err(InvalidConstraint(self.constraint_ids[i]))
        }
        [jet_norm(bx.minus(ax), by.minus(ay)).minus(difference)]
      }
      Diameter(c, d) => {
        let (_, _, radius) = self.circle_jets(c, vars)
        [radius.scale(2.0).offset(-d / frame.scale)]
      }
      ArcRadius(a, r) => [self.arc_radius_jet(a, vars).offset(-r / frame.scale)]
      ArcDiameter(a, d) =>
        [self.arc_radius_jet(a, vars).scale(2.0).offset(-d / frame.scale)]
      ArcSweep(a, t) => {
        angular = true
        [self.arc_sweep_jet(a, vars).offset(-t)]
      }
      ArcLength(a, l) =>
        [
          self
          .arc_radius_jet(a, vars)
          .times(self.arc_sweep_jet(a, vars))
          .offset(-l / frame.scale),
        ]
      EqualArcRadius(a, b) =>
        [self.arc_radius_jet(a, vars).minus(self.arc_radius_jet(b, vars))]
      EqualCircleArcRadius(c, a) => {
        let (_, _, r) = self.circle_jets(c, vars)
        [r.minus(self.arc_radius_jet(a, vars))]
      }
      ArcConcentric(a, b) => {
        let (ax, ay) = self.point_jets(self.arc(a).unwrap().center, vars)
        let (bx, by) = self.point_jets(self.arc(b).unwrap().center, vars)
        [ax.minus(bx), ay.minus(by)]
      }
      CircleArcConcentric(c, a) => {
        let (cx, cy, _) = self.circle_jets(c, vars)
        let (ax, ay) = self.point_jets(self.arc(a).unwrap().center, vars)
        [ax.minus(cx), ay.minus(cy)]
      }
      ArcTangentAt(l, a, e) => {
        angular = true
        let (lx, ly) = self.line_jets(l, vars)
        let (rx, ry) = self.arc_endpoint_vector(a, e, vars)
        let ln = jet_norm(lx, ly)
        let rn = jet_norm(rx, ry)
        [jet_dot(lx.divide(ln), ly.divide(ln), rx.divide(rn), ry.divide(rn))]
      }
      ArcArcTangentAt(a, ae, b, be) => {
        angular = true
        let (ax, ay) = self.arc_endpoint_vector(a, ae, vars)
        let (bx, by) = self.arc_endpoint_vector(b, be, vars)
        [normalized_cross(ax, ay, bx, by)]
      }
      ArcCircleTangentAt(a, e, c) => {
        let (px, py) = self.point_jets(
          arc_endpoint(self.arc(a).unwrap(), e),
          vars,
        )
        let (cx, cy, r) = self.circle_jets(c, vars)
        let vx = px.minus(cx)
        let vy = py.minus(cy)
        if jet_norm(vx, vy).v <= geometry_scale * 1.0e-12 {
          return Err(InvalidConstraint(self.constraint_ids[i]))
        }
        let (ax, ay) = self.arc_endpoint_vector(a, e, vars)
        push_rows(out, [normalized_cross(ax, ay, vx, vy)], i, true)
        [jet_norm(vx, vy).minus(r)]
      }
      PointOnArc(p, a) => {
        let arc = self.arc(a).unwrap()
        let (cx, cy) = self.point_jets(arc.center, vars)
        let (px, py) = self.point_jets(p, vars)
        let vx = px.minus(cx)
        let vy = py.minus(cy)
        if jet_norm(vx, vy).v <= geometry_scale * 1.0e-12 {
          return Err(InvalidConstraint(self.constraint_ids[i]))
        }
        let (sx, sy, ex, ey) = self.arc_vectors(a, vars)
        let angle = positive_jet_angle(sx, sy, vx, vy, arc.direction)
        let sweep = self.arc_sweep_jet(a, vars)
        let (qx, qy) = if angle.v <= sweep.v {
          (vx, vy)
        } else if angle.v - sweep.v <= 2.0 * @math.PI - angle.v {
          (ex, ey)
        } else {
          (sx, sy)
        }
        let qn = jet_norm(qx, qy)
        let r = self.arc_radius_jet(a, vars)
        [vx.minus(qx.divide(qn).times(r)), vy.minus(qy.divide(qn).times(r))]
      }
    }
    push_rows(out, jets, i, angular)
  }
  for row in out {
    if !finite(row.jet.v) || row.jet.d.any(v => !finite(v)) {
      return Err(
        NumericalFailure(
          "Nonfinite user or intrinsic geometry residual/derivative",
        ),
      )
    }
  }
  Ok(out)
}
