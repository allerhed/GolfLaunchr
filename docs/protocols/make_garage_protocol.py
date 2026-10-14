"""Builds docs/protocols/GolfLaunchr-garage-R10-protocol.pdf (A4).

Development tooling only (reportlab, BSD licence), never shipped in the app.
Run: python3 make_garage_protocol.py  (needs `pip install reportlab`)
"""

from pathlib import Path

from reportlab.graphics.shapes import Circle, Drawing, Line, Polygon, Rect, String
from reportlab.lib import colors
from reportlab.lib.enums import TA_LEFT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.platypus import (Flowable, KeepTogether, PageBreak, Paragraph, SimpleDocTemplate, Spacer, Table,
                                TableStyle)

OUT = Path(__file__).with_name("GolfLaunchr-garage-R10-protocol.pdf")
GREEN = colors.HexColor("#1B4D3E")
LIGHT = colors.HexColor("#EEF3EF")
AMBER = colors.HexColor("#FFF4E0")

ss = getSampleStyleSheet()
H1 = ParagraphStyle("H1", parent=ss["Heading1"], textColor=GREEN, fontSize=18, spaceAfter=6)
H2 = ParagraphStyle("H2", parent=ss["Heading2"], textColor=GREEN, fontSize=13.5, spaceBefore=10, spaceAfter=4)
BODY = ParagraphStyle("Body", parent=ss["BodyText"], fontSize=10, leading=13.5, alignment=TA_LEFT)
SMALL = ParagraphStyle("Small", parent=BODY, fontSize=8.5, leading=11, textColor=colors.HexColor("#444444"))
CELL = ParagraphStyle("Cell", parent=BODY, fontSize=9, leading=11.5)
CELLB = ParagraphStyle("CellB", parent=CELL, fontName="Helvetica-Bold")


def p(text, style=BODY):
    return Paragraph(text, style)


class TickBox(Flowable):
    """A small empty square to tick by hand."""

    def wrap(self, *_):
        return 4.2 * mm, 4.2 * mm

    def draw(self):
        self.canv.setLineWidth(0.8)
        self.canv.rect(0, 0, 4.2 * mm, 4.2 * mm)


def checklist(items):
    """Rows with an empty square to tick by hand."""
    rows = [[TickBox(), p(t, CELL)] for t in items]
    t = Table(rows, colWidths=[7 * mm, 163 * mm])
    t.setStyle(TableStyle([
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("TOPPADDING", (0, 0), (-1, -1), 3),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 3),
        ("LEFTPADDING", (1, 0), (1, -1), 6),
    ]))
    return t


def steps(items):
    rows = [[p(f"<b>{i}</b>", CELL), p(t, CELL)] for i, t in enumerate(items, 1)]
    t = Table(rows, colWidths=[8 * mm, 162 * mm])
    t.setStyle(TableStyle([("VALIGN", (0, 0), (-1, -1), "TOP"), ("TOPPADDING", (0, 0), (-1, -1), 2),
                           ("BOTTOMPADDING", (0, 0), (-1, -1), 2)]))
    return t


def table(header, rows, widths, shade=True):
    data = [[p(h, CELLB) for h in header]] + [[p(str(c), CELL) for c in r] for r in rows]
    t = Table(data, colWidths=widths, repeatRows=1)
    style = [("GRID", (0, 0), (-1, -1), 0.4, colors.HexColor("#999999")),
             ("BACKGROUND", (0, 0), (-1, 0), LIGHT), ("VALIGN", (0, 0), (-1, -1), "TOP"),
             ("TOPPADDING", (0, 0), (-1, -1), 3), ("BOTTOMPADDING", (0, 0), (-1, -1), 3)]
    t.setStyle(TableStyle(style))
    return t


def header_row():
    t = table(["Block", "Club", "Exposure", "Ball", "Golfer / hand"], [["", "", "", "", ""]], [34 * mm] * 5)
    t._argH[1] = 10 * mm  # room to write
    return t


def box(text, color=AMBER):
    t = Table([[p(text, CELL)]], colWidths=[170 * mm])
    t.setStyle(TableStyle([("BACKGROUND", (0, 0), (-1, -1), color), ("BOX", (0, 0), (-1, -1), 0.6, colors.HexColor("#C9A35B")),
                           ("TOPPADDING", (0, 0), (-1, -1), 6), ("BOTTOMPADDING", (0, 0), (-1, -1), 6),
                           ("LEFTPADDING", (0, 0), (-1, -1), 8)]))
    return t


def label(x, y, text, **kw):
    kw.setdefault("fontName", "Helvetica")
    return String(x, y, text, **kw)


def layout_diagram():
    """Top view, target to the right, right-handed golfer (left-handed: golfer and phone swap sides)."""
    d = Drawing(170 * mm, 78 * mm)
    s = mm
    # target line
    d.add(Line(8 * s, 40 * s, 162 * s, 40 * s, strokeColor=colors.HexColor("#888888"), strokeDashArray=[3, 3]))
    d.add(Polygon([162 * s, 40 * s, 155 * s, 43 * s, 155 * s, 37 * s], fillColor=GREEN, strokeColor=GREEN))
    d.add(label(143 * s, 44 * s, "target", fontSize=8, fillColor=GREEN))
    # net
    d.add(Line(140 * s, 22 * s, 140 * s, 58 * s, strokeColor=colors.black, strokeWidth=2))
    d.add(label(132 * s, 17 * s, "net: 3 m or more", fontSize=7.5))
    # ball
    d.add(Circle(80 * s, 40 * s, 1.6 * s, fillColor=colors.white, strokeColor=colors.black))
    d.add(label(76 * s, 34 * s, "ball", fontSize=7.5))
    # R10 behind ball on the target line
    d.add(Rect(36 * s, 37.5 * s, 7 * s, 5 * s, fillColor=colors.HexColor("#333333")))
    d.add(label(27 * s, 45 * s, "Garmin R10", fontSize=7.5))
    d.add(Line(43 * s, 33 * s, 78.4 * s, 33 * s, strokeColor=colors.HexColor("#555555")))
    d.add(label(50 * s, 29 * s, "2.0 m (1.8-2.4 m) behind the ball", fontSize=7))
    # golfer (right-handed) below the line
    d.add(Circle(80 * s, 22 * s, 4 * s, fillColor=colors.HexColor("#DDDDDD"), strokeColor=colors.black))
    d.add(label(87 * s, 20 * s, "golfer (right-handed)", fontSize=7.5))
    # phone above the line, looking at the ball
    d.add(Rect(77 * s, 64 * s, 6 * s, 3 * s, fillColor=GREEN))
    d.add(label(85 * s, 64.5 * s, "iPhone on tripod, landscape, camera facing the ball", fontSize=7.5))
    d.add(Line(80 * s, 63 * s, 80 * s, 42 * s, strokeColor=GREEN, strokeDashArray=[2, 2]))
    d.add(label(82 * s, 52 * s, "1.0 m lens to ball centre (measure)", fontSize=7, fillColor=GREEN))
    d.add(label(8 * s, 4 * s, "Top view, not to scale. The ball sits between golfer and phone; the phone looks across the target line (side-on).",
                 fontSize=7.5))
    return d


story = []

# ---------------------------------------------------------------- cover
story += [
    p("GolfLaunchr garage session with a Garmin R10", H1),
    p("Test protocol v1 for the weekend of 17-18 October 2026. Print it, tick the boxes, write on it.", BODY),
    Spacer(1, 6),
    box("<b>Goal of the weekend:</b> record many real strikes in good light with a reference monitor next to the phone, so we can "
        "(1) start labelling and training the ball and club detector, and (2) get first, rough comparisons of ball speed, launch "
        "angle, left/right direction and club speed. <b>Nothing recorded this weekend is a validated accuracy result</b>: the R10 is "
        "a consumer radar, and the formal accuracy test (G2) still needs the TrackMan bay.", LIGHT),
    Spacer(1, 8),
    p("What you will bring home", H2),
    table(["Item", "Target"], [
        ["Strike clips with an R10 reading", "about 180 on day 1 (the blocks) and 250 or more on day 2; more is welcome"],
        ["R10 export (CSV), one per block", "one file per block, named after the block (B1, B2, ...)"],
        ["Calibration clips", "scale stick, ball drop, empty background (block B0, each day)"],
        ["Negative clips", "10 minutes of practice swings, ball placement, walking past"],
        ["Paper shot log (Appendix A)", "one sheet per block, with misses and notes"],
        ["Photos of the setup", "from above and from the phone's side, with the tape measure visible"],
    ], [75 * mm, 95 * mm]),
    Spacer(1, 8),
    p("Time plan per day", H2),
    table(["Step", "What", "Time"], [
        ["0", "Setup, measurements, light check (section 2-4)", "60 min"],
        ["B0", "Calibration clips", "10 min"],
        ["B1-B3", "Exposure sweep, 7 iron, 15 shots each", "30 min"],
        ["B4-B6", "Wedge, 7 iron, driver at the best exposure, 30 each", "60 min"],
        ["B7-B8", "Distance variant and marked ball, 20 each", "30 min"],
        ["B9", "Negatives", "10 min"],
        ["End", "Copy everything to the Mac (section 8)", "30 min"],
    ], [18 * mm, 117 * mm, 35 * mm]),
    Spacer(1, 6),
    p("Reference quality: Garmin states +/-1 mph ball speed, +/-3 mph club speed, +/-1 degree launch angle and +/-1 degree launch "
      "direction. Indoors the R10 <b>calculates</b> spin, club path, carry and face-to-path from a model rather than measuring them, "
      "so we use those columns only as rough hints, never as truth.", SMALL),
    PageBreak(),
]

# ---------------------------------------------------------------- 1. before the weekend
story += [
    p("1. Before the weekend", H1),
    p("Phone and app", H2),
    checklist([
        "The new GolfLaunchr build is on the phone (installed 15 Oct; it opens the capture harness from Settings and shows "
        "<b>Session</b> fields: Block, Recording, Ball, Reference monitor). If not, connect the phone to the Mac and ask Claude to install it.",
        "Phone fully charged, charger and a long cable at the garage. Low Power Mode <b>off</b>, Focus / Do Not Disturb <b>on</b>.",
        "At least <b>30 GB free</b> (each clip is about 25 MB; 600 clips is about 15 GB). Settings &gt; General &gt; iPhone Storage.",
        "The Mac has room for the clips (30 GB) and Finder can see the phone (cable, \"Trust this computer\").",
    ]),
    p("Garmin R10", H2),
    checklist([
        "Garmin Golf app on a <b>second device</b> (iPad or another phone), not on the recording iPhone: the camera app must stay in front.",
        "R10 charged, paired, firmware updated. App units set to metres and km/h (note in the log if different).",
        "You know where the share/export icon is in a range session (it gives a CSV with one row per shot).",
    ]),
    p("Equipment", H2),
    checklist([
        "Sturdy tripod with a phone clamp, weighted (a bag of balls hanging under it). The phone must not move all day.",
        "Tape measure, a straight 1 m stick or ruler (scale bar), an alignment stick, masking tape for marks on the mat.",
        "Hitting mat, net at least 3 m in front of the ball (Garmin's minimum is 2.4 m), carpet or a mat over bare concrete in "
        "front of the R10 (concrete can disturb the radar), no fans or moving metal near the R10.",
        "20+ balls of <b>one</b> premium white model, plus 6 of the same balls marked with one thick black line all the way round "
        "(permanent marker), plus a few yellow balls if you have them.",
        "Clubs: a wedge (PW or SW), a 7 iron and a driver (driver only if the net and ceiling allow it).",
    ]),
    p("Light (the most important thing for the camera)", H2),
    p("The phone must use a very short shutter (1/2000 s) to freeze the ball. That needs much more light than a normal garage has.", BODY),
    checklist([
        "2-4 LED floodlights, <b>flicker-free</b> (look for \"flicker-free\" or a high-frequency driver; no dimmers). About "
        "10,000 lumen or more each.",
        "Aim them at the ball and the area 1 m in front of it, from above and from the phone's side, but never straight into the lens.",
        "Turn off fluorescent tubes and other lamps that flicker; keep the background behind the ball plain if you can.",
    ]),
    p("If anyone else hits", H2),
    checklist([
        "They sign the short consent text in Appendix B first. Give them a pseudonym (g2, g3, ...); never write names in the app.",
    ]),
    PageBreak(),
]

# ---------------------------------------------------------------- 2. layout
story += [
    p("2. Set up the hitting area", H1),
    layout_diagram(),
    Spacer(1, 4),
    steps([
        "Lay the alignment stick on the mat along the target line, pointing at the middle of the net.",
        "Mark the ball position with a small tape cross. <b>Every ball goes on exactly this spot all weekend</b> (the camera "
        "distance must stay the same).",
        "Place the R10 on the target line <b>2.0 m behind the ball</b> (Garmin allows 1.8-2.4 m), level with or a little higher "
        "than the mat, red line aimed down the target line.",
        "Put the phone on the tripod on the <b>opposite side of the ball from the golfer</b> (right-handed golfer: phone on the far "
        "side). Landscape, camera lens facing the ball squarely, across the target line.",
        "Lens height about <b>0.20 m</b> above the mat; distance from the lens to the ball centre <b>1.0 m</b>. Measure both with the "
        "tape and write them down; type the measured values into the app (section 3).",
        "Check the swing: take a few slow practice swings and make sure the club cannot reach the tripod. Move the phone back a "
        "little if needed and re-measure.",
        "Take the two setup photos (from above and from the phone's side, tape visible).",
    ]),
    Spacer(1, 6),
    table(["Write down (also on the log sheet)", "Value"], [
        ["Lens to ball centre (m)", ""], ["Lens height above mat (m)", ""], ["R10 to ball (m)", ""], ["Ball to net (m)", ""],
        ["Lights (number, type)", ""], ["Golfer id, handedness", ""],
    ], [100 * mm, 70 * mm]),
    PageBreak(),
]

# ---------------------------------------------------------------- 3. app
story += [
    p("3. Set up the app (capture harness)", H1),
    steps([
        "Open GolfLaunchr, tap the <b>gear</b> (Settings), scroll down and tap <b>Open capture harness (DEBUG)</b>.",
        "<b>Format</b>: choose <b>ultraWide 1920x1080 @240</b>.",
        "<b>Trigger</b>: <b>motion</b> (hands-free: every strike saves a clip by itself). Motion threshold: leave at 6 to start.",
        "<b>Exposure</b>: as the block says (1/1000, 1/2000 or 1/4000).",
        "<b>Session</b>: Block <b>B1</b> (use <b>Next block</b> to step to B2, B3, ...), Recording <b>strike</b>, Ball <b>white</b>, "
        "Reference monitor <b>Garmin Approach R10</b>.",
        "<b>Setup</b>: handedness, club, Lighting <b>garage LED</b>, Location <b>garage</b>, Distance and Camera height = <b>your "
        "measured values</b> (not the defaults), Golfer id.",
        "Tap <b>Start</b>. The preview shows a box like <b>\"B1 strike next #1\"</b>: that number is the shot you are about to hit.",
        "Check the <b>Live</b> section: FPS about 240, dropped/missing frames small and not climbing, Exposure shows what you chose, "
        "Thermal nominal or fair, Storage enough.",
    ]),
    Spacer(1, 6),
    box("Every saved clip makes a short <b>\"tink\"</b> sound and the box shows <b>\"Saved B1 strike #1\"</b>. Clips, a JSON file "
        "per clip and a <b>session-log.csv</b> are stored in the app's G1 folder."),
    Spacer(1, 10),
    p("4. Light check (before the first block, 10 minutes)", H1),
    steps([
        "Exposure <b>1/2000</b>, Start, ball on the spot.",
        "Look at the preview: the ball must look clearly <b>white and sharp</b>, not grey. Look at the Live <b>Exposure plan</b> line: if it "
        "says <b>\"stops darker than auto: ISO limit\"</b> with more than 1 stop, add light or move the lights closer, then try again.",
        "Look for slow dark bands rolling through the picture. If you see them a lamp flickers: switch that lamp off or replace it.",
        "Hit 3 shots and listen for the tink after each one; check that the R10 shows each shot.",
    ]),
    PageBreak(),
]

# ---------------------------------------------------------------- 5. routine
story += [
    p("5. The routine for every shot", H1),
    steps([
        "Put the ball on the tape cross. Step back and stand still for <b>2 seconds</b> (walking and waggles near the ball also "
        "trigger clips).",
        "Address and hit.",
        "Listen for the <b>tink</b> from the phone and check that the R10 app shows a new shot.",
        "If the R10 shows nothing, or you mis-hit badly (top, shank), write the shot number and \"R10 miss\" or \"mis-hit\" on the "
        "log sheet. Do <b>not</b> walk to the phone during a block; Claude matches the clips afterwards.",
        "No tink? The phone missed it: write \"no clip\" on the sheet. (The shot number on the sheet is your own count. The phone's "
        "number can run ahead when movement near the ball saves extra clips; that is expected and sorted out afterwards.)",
        "Every 30 shots glance at the phone: Thermal not \"serious\", Storage OK, missing frames not climbing.",
    ]),
    Spacer(1, 4),
    box("<b>One block = one R10 range session.</b> When you start a new block in the app (Next block), also start a new "
        "range session in the Garmin Golf app. At the end of each block export the R10 CSV (share icon) and name the file with "
        "the block, e.g. <b>B4-wedge.csv</b>. This is how clips and R10 shots are paired: block by block, in order."),
    Spacer(1, 6),
    p("Stop and fix if", H2),
    table(["You see", "Do this"], [
        ["FPS below about 235, or missing frames keep climbing", "Stop, close other apps, let the phone cool, restart the harness"],
        ["The Exposure or Exposure plan line does not show the shutter you chose", "Stop and Start again; note it on the sheet"],
        ["Thermal \"serious\"", "Pause 10 minutes, take the phone off the charger, make sure no lamp shines straight on the phone"],
        ["R10 misses more than about 1 in 10 shots", "Re-align the R10 on the target line and check the 1.8-2.4 m distance"],
        ["The ball spot or the tripod moved", "Put them back, re-measure, start a new block"],
    ], [85 * mm, 85 * mm]),
    PageBreak(),
]

# ---------------------------------------------------------------- 6. blocks
story += [
    p("6. The blocks (do them in this order)", H1),
    table(["Block", "Recording", "Club", "Exposure", "Shots", "Notes"], [
        ["B0", "scale / background", "-", "1/2000", "-",
         "Trigger <b>manual</b>. (a) Lay the 1 m stick on the mat through the ball spot along the target line: tap "
         "<b>Save last 2 s now</b> twice (Recording: scale). (b) Hold a ball 1 m above the spot, drop it, and tap Save within a second (the clip holds the last 2 s; a helper makes this easier): Recording scale. "
         "(c) Empty hitting area, nobody in view: save 3 times (Recording: background)."],
        ["B1", "strike", "7 iron", "1/1000", "15", "Normal full shots. Trigger back to <b>motion</b>."],
        ["B2", "strike", "7 iron", "1/2000", "15", "Same shots, only the shutter changes."],
        ["B3", "strike", "7 iron", "1/4000", "15", "If the picture gets too dark, note it and skip to B4."],
        ["B4", "strike", "Wedge", "best", "30", "\"best\" = the shortest shutter that still looked bright and sharp in B1-B3."],
        ["B5", "strike", "7 iron", "best", "30", ""],
        ["B6", "strike", "Driver", "best", "30", "Only if the net and ceiling allow it. Otherwise a hybrid or 5 iron."],
        ["B7", "strike", "7 iron", "best", "20", "Move the phone to <b>0.75 m</b>, re-measure, type the new distance in."],
        ["B8", "strike", "7 iron", "best", "20", "Phone back to 1.0 m. <b>Marked balls</b> (Ball: marked), line facing the phone, "
         "running straight up-down."],
        ["B9", "negative", "-", "best", "10 min", "No balls hit: practice swings, placing balls, walking past, a waggle at address."],
    ], [14 * mm, 24 * mm, 15 * mm, 19 * mm, 14 * mm, 84 * mm]),
    Spacer(1, 6),
    p("Day 2", H2),
    p("Repeat B0, then B4, B5 and B6 with more shots (50 each) and, if possible, other golfers (consent first, own golfer id) and "
      "a left-handed golfer (phone moves to the other side of the ball: it always stands opposite the golfer). A block of yellow "
      "balls (Ball: yellow) is a bonus.", BODY),
    PageBreak(),
]

# ---------------------------------------------------------------- 7-8. end of day
story += [
    p("7. End of each block", H1),
    checklist([
        "Export the R10 CSV for the block (share icon in the range session) and save it as <b>B&lt;n&gt;-&lt;club&gt;.csv</b>.",
        "On the log sheet: total shots, R10 misses, mis-hits, anything odd.",
    ]),
    p("8. End of each day: copy everything to the Mac", H1),
    steps([
        "Tap <b>Stop</b> in the harness.",
        "Connect the iPhone to the Mac with the cable. In Finder select the iPhone, open the <b>Files</b> tab, open "
        "<b>GolfLaunchr</b>.",
        "Drag the <b>G1</b> folder to a new Mac folder named <b>Garage-2026-10-17</b> (Day 2: Garage-2026-10-18). It contains "
        "the clips (.mov), one .json per clip and session-log.csv.",
        "Put the R10 CSV files, the setup photos and a photo of each log sheet in the same folder.",
        "Check on the Mac that the folder has as many .mov files as .json files and that the clips play. Only then delete clips "
        "on the phone (Day 1 evening, if you need the space for Day 2).",
        "Tell Claude the folder path. Nothing is uploaded anywhere.",
    ]),
    Spacer(1, 8),
    p("What happens afterwards (no action for you)", H2),
    p("Claude pairs every strike clip with its R10 row (block by block, in order, checked against the speeds), builds the first "
      "labelled set, runs the no-machine-learning baseline (plan milestone M1) and reports the first rough comparison against the "
      "R10. The TrackMan bay visit remains the source for the formal accuracy test.", BODY),
    PageBreak(),
]

# ---------------------------------------------------------------- appendix A: log sheet
rows = [[str(i), "", "", "", ""] for i in range(1, 31)]
story += [
    p("Appendix A. Shot log sheet (copy one per block; blocks over 30 shots use two sheets)", H1),
    header_row(),
    Spacer(1, 4),
    table(["Shot #", "R10 OK?", "Clip tink?", "Mis-hit?", "Notes"], rows, [16 * mm, 20 * mm, 20 * mm, 20 * mm, 94 * mm]),
    PageBreak(),
]

# ---------------------------------------------------------------- appendix B: consent
story += [
    p("Appendix B. Consent for recording (one per golfer)", H1),
    p("I agree that high-speed video of my golf shots recorded on this date may be used to develop and test the GolfLaunchr app: "
      "to train and evaluate its ball and club detection, and to compare its measurements with a reference launch monitor.", BODY),
    Spacer(1, 4),
    steps([
        "The video stays on the developer's own computers. It is not uploaded to cloud services or shared with others.",
        "I am identified only by a code (for example g2), never by name, in the recordings and notes.",
        "The video is not published, and I do not appear in marketing or screenshots.",
        "I can withdraw at any time; my clips and their labels are then deleted and are not used for later models.",
    ]),
    Spacer(1, 14),
    table(["Golfer code", "Name (kept on paper only)", "Date", "Signature"], [["", "", "", ""], ["", "", "", ""], ["", "", "", ""]],
          [28 * mm, 62 * mm, 28 * mm, 52 * mm]),
]


def footer(canvas, doc):
    canvas.saveState()
    canvas.setFont("Helvetica", 8)
    canvas.setFillColor(colors.HexColor("#666666"))
    canvas.drawString(20 * mm, 10 * mm, "GolfLaunchr garage protocol v1 (R10), 2026-10-15")
    canvas.drawRightString(190 * mm, 10 * mm, f"Page {doc.page}")
    canvas.restoreState()


doc = SimpleDocTemplate(str(OUT), pagesize=A4, leftMargin=20 * mm, rightMargin=20 * mm, topMargin=16 * mm, bottomMargin=18 * mm,
                        title="GolfLaunchr garage session with a Garmin R10", author="GolfLaunchr")
doc.build(story, onFirstPage=footer, onLaterPages=footer)
print(OUT)
