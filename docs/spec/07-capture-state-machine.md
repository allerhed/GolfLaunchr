## 7. Capture state machine and navigation

| State | Trigger | Next state / action |
|---|---|---|
| Idle | Start with permission/entitlement | Qualifying |
| Qualifying | Profile/format/environment pass | Calibrating |
| Qualifying | Unsupported/denied | Blocked with recoverable action |
| Calibrating | Geometry passes | SeekingBall |
| SeekingBall | Stationary ball and valid pose | Ready |
| Ready | Candidate movement/strike | Capturing |
| Capturing | Window gathered | Processing |
| Processing | Quality sufficient | Committing |
| Processing | Invalid | Rejected → SeekingBall |
| Committing | Durable receipt | Result → SeekingBall |
| Committing | Storage/entitlement conflict | Paused with preserved diagnostics |
| Any active state | Device moved/format changed | Calibrating after safe cancellation |
| Any active state | Background/thermal/interruption | Paused |
| Paused | Resume | Qualifying |
| Any session state | End | Summary / recovered history |

No background process promotes an incomplete candidate. UI state mirrors the pipeline state, not a timer-based approximation. Simulator send and speech are downstream of commit. Club selection is snapshotted before Ready; future selection may be queued while processing but cannot alter the in-flight shot.

Home offers Practice, Bag and Progress, with mode chooser for QuickShot, target, ladder, range and courses. Settings/entitlements are reachable from Home. History leads to session, then shot, then replay. Original screen composition is intentionally left to the design team; interaction and failure behaviours above are normative.
