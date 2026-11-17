///|
test "new arc residual derivatives match independent centered differences" {
  let s = Sketch::new()
  let c = s.try_add_point(0.1, 0.2).unwrap()
  let a = s.try_add_point(2.3, 0.5).unwrap()
  let shared = s.try_add_point(0.4, 2.6).unwrap()
  let c2 = s.try_add_point(0.6, 4.7).unwrap()
  let e2 = s.try_add_point(2.8, 4.9).unwrap()
  let inside = s.try_add_point(0.9, 1.1).unwrap()
  let outside = s.try_add_point(-1.8, 1.2).unwrap()
  let first = s.try_add_arc(c, a, shared, CounterClockwise).unwrap()
  let second = s.try_add_arc(c2, shared, e2, CounterClockwise).unwrap()
  let circle = s.try_add_circle(c2, 1.7).unwrap()
  let line = s.try_add_line(shared, e2).unwrap()
  for
    relation in [
      Diameter(circle, 3.4),
      ArcRadius(first, 2.0),
      ArcDiameter(first, 4.0),
      ArcSweep(first, 1.4),
      ArcLength(first, 3.0),
      EqualArcRadius(first, second),
      EqualCircleArcRadius(circle, first),
      ArcConcentric(first, second),
      CircleArcConcentric(circle, first),
      ArcTangentAt(line, first, End),
      ArcArcTangentAt(first, End, second, Start),
      ArcCircleTangentAt(first, End, circle),
      PointOnArc(inside, first),
      PointOnArc(outside, first),
    ] {
    s.try_constrain(relation).unwrap() |> ignore
  }
  let frame = s.frame()
  let x = s.parameters(frame)
  let rows = s.evaluate(x, frame).unwrap()
  for k in 0..<x.length() {
    let xp = x.copy()
    let xm = x.copy()
    let h = 1.0e-6
    xp[k] += h
    xm[k] -= h
    let plus = s.evaluate(xp, frame).unwrap()
    let minus = s.evaluate(xm, frame).unwrap()
    for i in 0..<rows.length() {
      let numeric = (plus[i].jet.v - minus[i].jet.v) / (2.0 * h)
      assert_true((rows[i].jet.d[k] - numeric).abs() < 2.0e-6)
    }
  }
}

///|
fn arc_oracle(shape : ArcShape, expected_direction : ArcDirection) -> Bool {
  let r1 = @math.hypot(
    shape.start.x - shape.center.x,
    shape.start.y - shape.center.y,
  )
  let r2 = @math.hypot(
    shape.end.x - shape.center.x,
    shape.end.y - shape.center.y,
  )
  let sign = if expected_direction == CounterClockwise { 1.0 } else { -1.0 }
  finite(r1) &&
  finite(r2) &&
  (r1 - 2.0).abs() < 1.0e-7 &&
  (r2 - 2.0).abs() < 1.0e-7 &&
  shape.direction == expected_direction &&
  shape.center.x.abs() < 1.0e-7 &&
  shape.center.y.abs() < 1.0e-7 &&
  (shape.start.x - 2.0).abs() < 1.0e-7 &&
  shape.start.y.abs() < 1.0e-7 &&
  shape.end.x.abs() < 1.0e-7 &&
  (shape.end.y - sign * 2.0).abs() < 1.0e-7
}

///|
test "arc checker rejects wrong direction, endpoint swap and inconsistent radius" {
  let shape : ArcShape = {
    center: { x: 0.0, y: 0.0, },
    start: { x: 2.0, y: 0.0, },
    end: { x: 0.0, y: 2.0, },
    direction: CounterClockwise,
  }
  assert_true(arc_oracle(shape, CounterClockwise))
  assert_false(arc_oracle({ ..shape, direction: Clockwise, }, CounterClockwise))
  assert_false(
    arc_oracle(
      { ..shape, start: shape.end, end: shape.start, },
      CounterClockwise,
    ),
  )
  assert_false(
    arc_oracle({ ..shape, end: { x: 0.0, y: 2.2, }, }, CounterClockwise),
  )
  assert_false(
    arc_oracle({ ..shape, start: { x: 0.0 / 0.0, y: 0.0, }, }, CounterClockwise),
  )
}

///|
test "geometry identifier exhaustion is recoverable without allocating storage" {
  let s = Sketch::new()
  s.next_geometry[0] = 2147483647
  assert_true(s.try_add_point(0.0, 0.0) is Err(IdentifierExhausted))
  assert_eq(s.points.length(), 0)
  s.next_geometry[0] = 0
  let c = s.try_add_point(0.0, 0.0).unwrap()
  let a = s.try_add_point(1.0, 0.0).unwrap()
  let b = s.try_add_point(0.0, 1.0).unwrap()
  s.next_geometry[1] = 2147483647
  s.next_geometry[2] = 2147483647
  s.next_geometry[3] = 2147483647
  assert_true(s.try_add_line(c, a) is Err(IdentifierExhausted))
  assert_true(s.try_add_circle(c, 1.0) is Err(IdentifierExhausted))
  assert_true(
    s.try_add_arc(c, a, b, CounterClockwise) is Err(IdentifierExhausted),
  )
  assert_eq(s.lines.length(), 0)
  assert_eq(s.circles.length(), 0)
  assert_eq(s.arcs.length(), 0)
}
