## 13. UI design direction and screen flow — version 1.2

User direction: a modern, fluid, easy-to-use iPhone interface that works in both portrait and landscape, from launch through practice and settings. This supersedes the earlier portrait-shell default. English and Swedish remain mandatory.

### Visual foundation

Use forest green (#103A2D), warm ivory (#F6F5EE), a restrained mint/lime accent (#BFE77B), dark readable type, large metric numerals, generous spacing, rounded cards and subtle translucent navigation surfaces. Validate actual colour contrast in implementation; a generated concept cannot certify accessibility. Use native iOS-feeling controls and motion that respects Reduce Motion. Select a single original golf-ball/flight-arc logo after design review.

Primary navigation is Home, Bag and Progress; Settings is reachable by a gear or more menu. Generated concepts may show a fourth Settings item for exploration; implementation must choose one consistent navigation pattern rather than mixing them.

### Main flow and layout contract

| Screen | Main action | Portrait | Landscape |
|---|---|---|---|
| Launch | Automatically reach welcome/home | Centred brand mark, no artificial loading delay | Centred mark, same visual treatment |
| Welcome | Start as guest; choose English/Svenska | Benefit illustration, language choice, bottom CTA | Illustration on one side; benefits and actions on the other |
| Home | Start practice / select mode | Dominant practice card and mode shortcuts | Navigation rail; practice/action area beside recent activity |
| Setup | Qualify physical capture | Guidance then preview/readiness controls | Large preview beside concise checks and capture CTA |
| Live practice | Strike, receive result, pause/end | Rotate your iPhone guidance; capture cannot arm | Dominant side-on camera pane, slim header, side metrics, saved-impact thumbnail and pause/end |
| Shot detail/replay | Review captured frames | Video then playback/metric cards | Video and controls left; metrics and actions right |
| Session summary | Review shots or finish | Aggregate cards and plots | Summary column beside plot/table |
| Activity history | Select session or inspect trends | Filtered cards | Session master list and selected detail |
| My Bag | Select/map club | Club list and mapping CTA | Club master list and profile pane |
| Target drill | Complete configured attempts | Target feedback and progress | Target visualization beside outcomes/actions |
| Virtual golf | Continue fictional course round | Course map then club/round controls | Map beside metrics/lie/score controls |
| Settings | Edit language, units and preferences | Grouped rows and language picker | Category list beside selected preference form |

Additional required production screens remain in F22: mode chooser, club edit/map progress, ladder configuration/run/results, challenge configuration/results, skill trends, course chooser, simulator setup, membership/paywall, support and all error/empty/permission/interruption states. The first visual concept set illustrates the main flow; it does not replace those functional requirements.

### Interaction and orientation rules

* Reserve comfortable touch areas and safe areas; avoid controls beneath camera cutouts or the home indicator.
* Keep a stable primary action within reach; separate destructive End/Delete actions from ordinary capture/next controls.
* Transition smoothly between cards/panes, but never animate fake live measurements. Values in concept art are illustrative.
* Rotation preserves selected club, session, drill/round progression, filters and replay position. Capture geometry is requalified before another strike; visual rotation alone is not proof of a valid physical setup.
* Setup illustrations must show the phone opposite the golfer across the ball, perpendicular to the target line, with a side-on camera view. Mirror for left/right swings and preserve the target direction. Behind-ball illustrations and downrange camera previews are superseded. Exact distances/heights and capture limits require independently validated profiles.
* Speech and metric labels preserve Measured/Estimated/Unavailable in both languages.
* Courses use original fictional assets. No concept copy may promise famous/real courses or unproven accuracy.
* Onboarding remains guest-first. If two start buttons appear in an exploratory mockup, consolidate them into a clear primary 'Get started' guest path; account creation is not a prerequisite.
* Screen concepts are generated raster references, not interactive or device-tested UI. Implementers must verify both orientations, small/large supported iPhones, Dynamic Type, VoiceOver and English/Swedish text expansion.

### Visual review and completion boundary

Review generated concepts for text, scientific claims, brand/navigation consistency, camera guidance and legibility. Correct invented placement instructions or accuracy claims before presenting them as normative. Physical touch behaviour, contrast, rotation recovery and measurement validity require implementation tests. Screen concept delivery must never be reported as completion of the app or of its full UI-state catalogue.
