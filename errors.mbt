///|
/// Recoverable input, resource or numerical errors. Nonconvergence is reported
/// by SolveStatus inside Ok(Solution), rather than by this enum.
#derive(Debug)
pub(all) enum SketchError {
  InvalidGeometry(String)
  InvalidConstraint(ConstraintId)
  ForeignHandle
  DegenerateLine(LineId)
  InvalidRadius(CircleId)
  InvalidArc(ArcId)
  GeometryInUse(GeometryId)
  ResourceLimit
  IdentifierExhausted
  InvalidOptions(String)
  NumericalFailure(String)
}

///|
pub extend SketchError with @debug.Debug::{to_repr}

///|
/// Human-readable context for logs. Match the variants for programmatic handling;
/// message wording is not a stable machine-readable interface.
pub fn SketchError::message(self : SketchError) -> String {
  match self {
    InvalidGeometry(message)
    | InvalidOptions(message)
    | NumericalFailure(message) => message
    InvalidConstraint(id) =>
      "Invalid constraint at index \{id.index}: bad reference, dimension or geometry domain"
    ForeignHandle => "Handle belongs to another sketch"
    InvalidArc(id) =>
      "Arc at index \{id.index}: invalid, missing or degenerate finite arc"
    GeometryInUse(_) =>
      "Geometry is referenced; remove relations and dependent geometry explicitly first"
    DegenerateLine(id) =>
      "Line at index \{id.index}: zero-length or too short relative to sketch scale"
    InvalidRadius(id) =>
      "Circle at index \{id.index}: radius must be finite, positive and nondegenerate relative to sketch scale"
    ResourceLimit =>
      "Small-sketch limit: at most 256 variables, 512 lines, 128 arcs, and 512 constraints"
    IdentifierExhausted =>
      "Geometry or constraint identifier space exhausted; create a new sketch"
  }
}
