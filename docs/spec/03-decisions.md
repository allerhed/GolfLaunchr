## 3. Original product decisions

| Area | Default decision | Consequence |
|---|---|---|
| Platform | Native Swift/SwiftUI, minimum iOS 18 | Recheck current SDK and deployment requirements at implementation kickoff. |
| Devices | Candidate pool iPhone 11 and newer; certify by model/camera/format | Marketing support list is generated only from passing physical tests. |
| Capture | Built-in rear camera, side-on view from the opposite side of the ball to the golfer | Phone is beside the target line, aimed across it at the ball/impact region; never a behind-ball/downrange capture geometry. Exact lens/format/offset/height come from validated device profiles. |
| Swing handedness | Explicit Right-handed / Left-handed setting, chosen during onboarding and editable in Settings/setup | Both are mandatory; mirror golfer/phone placement while preserving target coordinates; recalibrate after changes. |
| Screen orientation | Landscape mandatory for camera capture; browsing, history/review and settings adapt to portrait/landscape | Portrait capture shows Rotate your iPhone guidance and cannot arm; rotation/device movement pauses arming and requires landscape geometry requalification. |
| Identity | Guest-first, local data; no login required for core use | No backend dependency for measurement or local history. |
| Network | Core practice works offline after installation/entitlement provisioning | Purchases and external integration can require connectivity. |
| Units | Independent distance m/yd and speed m/s, km/h, mph | Store SI; never mutate raw measurements on unit changes. |
| Language | Multilingual from the first release; complete English (`en`) and Swedish (`sv`) | Both are mandatory launch scope, with architecture ready for additional locales; see F25. |
| Ball | Regulation-size real golf ball initially | Foam balls and putting remain unsupported until separately validated. |
| Free allowance | 50 introductory accepted persisted shots, then 10 shots per calendar month starting the following month | No subscription enrolment required; invalid captures do not spend credit; no rollover; deleting a shot does not refund it. |
| Monetisation | Complimentary partner Pro via Apple free offer codes (F19a), plus Free + one Pro tier: 49 SEK/month or 499 SEK/year, Swedish consumer prices including VAT | Monthly and annual grant identical Pro access; annual billed upfront; no lifetime product at launch; localise actual prices from StoreKit. |
| Historical data | Read and export retained data after entitlement expiry | Expiry returns capture to the Free allowance; stored records remain readable/exportable. |
| Replay | Automatically save an impact still, chronological club/ball composite and original impact frame sequence for every accepted shot | Durable shot media is retained until explicit deletion; 1 GB applies only to regenerable preview cache. Save failures are visible; never claim missing media was saved. |
| Courses | Original fictional courses; no borrowed famous-course assets | Famous venues require separate legitimate content rights. |
| Simulator | Documented approved protocol only | Unknown provider behaviour is a blocking integration dependency. |
| AI | Optional future explanatory assistant | Generative models must not fabricate sensor results or diagnose swing faults. |

These defaults resolve product choices for the agents. They do not prove camera feasibility, name availability, or provider integration access.
