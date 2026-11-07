///|
test "checked identifier exhaustion is atomic and never reuses an ID" {
  let s = Sketch::new()
  let p = s.add_point(0.0, 0.0)
  s.next_constraint[0] = 2147483646
  let last = s.try_constrain(Fix(p, 0.0, 0.0)).unwrap()
  assert_eq(last.index(), 2147483646)
  assert_true(s.try_constrain(Fix(p, 0.0, 0.0)) is Err(IdentifierExhausted))
  assert_eq(s.constraints.length(), 1)
  assert_eq(s.enabled.length(), 1)
  assert_eq(s.constraint_ids.length(), 1)
  assert_eq(s.next_constraint[0], 2147483647)
  assert_true(s.remove_constraint(last))
  assert_true(s.try_constrain(Fix(p, 0.0, 0.0)) is Err(IdentifierExhausted))
}

///|
test "line capacity check is atomic and validation remains defense in depth" {
  let s = Sketch::new()
  let a = s.add_point(0.0, 0.0)
  let b = s.add_point(1.0, 0.0)
  for _ in 0..<512 {
    s.try_add_line(a, b).unwrap() |> ignore
  }
  assert_true(s.try_add_line(a, b) is Err(ResourceLimit))
  assert_eq(s.lines.length(), 512)
  // Simulate an internally corrupted model, bypassing every public builder.
  s.lines.push({ a, b, })
  assert_true(s.solve() is Err(ResourceLimit))
}
