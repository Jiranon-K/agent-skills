import argparse
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

SUPERSAMPLE = 2
PAPER = (244, 243, 238)
SURFACE = (255, 255, 255)
INK = (31, 30, 27)
MUTED = (111, 107, 98)
RULE = (177, 173, 161)
ACCENT = (193, 95, 60)

STATIONS = [
    ("TRIAGE", False),
    ("DESIGN", False),
    ("YOU: REVIEW", True),
    ("BUILD", False),
    ("VERDICT", False),
    ("YOU: MERGE", True),
]
STATS = [("23", "skills"), ("55", "agents"), ("8", "rules"), ("15", "loop scripts")]
LOOP_ROWS = [
    [
        ("/loop-start", "You start a round", False),
        ("loop-triage", "Routes and picks tasks", False),
        ("loop-design", "Proposes a spec and a sketch", False),
        ("/loop-design-review", "You approve the design", True),
    ],
    [
        ("loop-work", "Builds by task type, opens the MR", False),
        ("loop-verifier", "Runs each criterion: PASS or FAIL", False),
        ("loop-watch", "READY, WAITING or BLOCKED", False),
        ("/merge-approved", "You merge a passed patch", True),
    ],
]


class Canvas:
    def __init__(self, width, height, fonts):
        self.size = (width, height)
        self.fonts = fonts
        self.image = Image.new("RGB", (width * SUPERSAMPLE, height * SUPERSAMPLE), PAPER)
        self.draw = ImageDraw.Draw(self.image)

    def font(self, name, size):
        return ImageFont.truetype(str(self.fonts / name), size * SUPERSAMPLE)

    def box(self, points):
        return [value * SUPERSAMPLE for value in points]

    def text(self, xy, value, name, size, fill, anchor="ls"):
        self.draw.text(self.box(xy), value, font=self.font(name, size), fill=fill, anchor=anchor)

    def line(self, points, fill, width):
        self.draw.line(self.box(points), fill=fill, width=width * SUPERSAMPLE, joint="curve")

    def circle(self, center, radius, fill=None, outline=None, width=1):
        x, y = center
        bounds = self.box([x - radius, y - radius, x + radius, y + radius])
        self.draw.ellipse(bounds, fill=fill, outline=outline, width=width * SUPERSAMPLE)

    def arc(self, center, radius, start, end, fill, width):
        x, y = center
        bounds = self.box([x - radius, y - radius, x + radius, y + radius])
        self.draw.arc(bounds, start, end, fill=fill, width=width * SUPERSAMPLE)

    def panel(self, bounds, fill, outline, radius=18):
        self.draw.rounded_rectangle(
            self.box(bounds), radius=radius * SUPERSAMPLE, fill=fill, outline=outline, width=2 * SUPERSAMPLE
        )

    def save(self, path):
        self.image.resize(self.size, Image.LANCZOS).save(path, optimize=True)


def on_circle(center, radius, degrees):
    angle = math.radians(degrees)
    return (center[0] + radius * math.cos(angle), center[1] + radius * math.sin(angle))


def draw_rings(canvas, center):
    for index, radius in enumerate((100, 145, 190)):
        canvas.circle(center, radius, outline=RULE, width=1)
        count = 40 * (index + 2)
        for step in range(count):
            if (step * 7 + index) % 5 == 0:
                continue
            canvas.circle(on_circle(center, radius, step * 360 / count), 2, fill=RULE)
    for degrees in range(0, 360, 3):
        outer = 282 if degrees % 15 == 0 else 272
        canvas.line([*on_circle(center, 262, degrees), *on_circle(center, outer, degrees)], RULE, 1)


def draw_orbit(canvas, center):
    canvas.arc(center, 235, -90, 210, ACCENT, 5)
    for degrees in range(214, 270, 6):
        canvas.circle(on_circle(center, 235, degrees), 2, fill=RULE)
    for index, (label, is_gate) in enumerate(STATIONS):
        degrees = -90 + index * 60
        draw_station(canvas, on_circle(center, 235, degrees), is_gate)
        draw_station_label(canvas, on_circle(center, 318, degrees), degrees, label, is_gate)
    canvas.text(center, "loop", "InstrumentSerif-Italic.ttf", 64, INK, "mm")


def draw_station(canvas, point, is_gate):
    if is_gate:
        canvas.circle(point, 22, fill=PAPER, outline=ACCENT, width=2)
        canvas.circle(point, 12, fill=ACCENT)
        return
    canvas.circle(point, 11, fill=SURFACE, outline=INK, width=3)


def draw_station_label(canvas, point, degrees, label, is_gate):
    horizontal = math.cos(math.radians(degrees))
    anchor = "lm" if horizontal > 0.3 else "rm" if horizontal < -0.3 else "mm"
    canvas.text(point, label, "GeistMono-Regular.ttf", 22, ACCENT if is_gate else INK, anchor)


def draw_banner(fonts, path):
    canvas = Canvas(2400, 840, fonts)
    center = (1840, 420)
    draw_rings(canvas, center)
    draw_orbit(canvas, center)
    canvas.text((100, 170), "CLAUDE CODE SETUP  ·  ONE REPO  ·  ONE INSTALL SCRIPT", "GeistMono-Regular.ttf", 24, MUTED)
    canvas.text((92, 390), "agent-skills", "InstrumentSerif-Regular.ttf", 210, INK)
    canvas.text((100, 516), "Skills, agents, rules, and the Loop that takes", "InstrumentSans-Regular.ttf", 40, MUTED)
    canvas.text((100, 570), "a ticket to a verified merge request.", "InstrumentSans-Regular.ttf", 40, MUTED)
    canvas.line([100, 636, 1180, 636], RULE, 1)
    for index, (number, label) in enumerate(STATS):
        left = 100 + index * 270
        canvas.text((left, 730), number, "InstrumentSerif-Regular.ttf", 84, ACCENT if index == 0 else INK)
        canvas.text((left, 768), label.upper(), "GeistMono-Regular.ttf", 22, MUTED)
    canvas.save(path)


def draw_step(canvas, bounds, step):
    name, caption, is_gate = step
    left, top, right, bottom = bounds
    middle = (left + right) / 2
    canvas.panel(bounds, ACCENT if is_gate else SURFACE, ACCENT if is_gate else RULE)
    canvas.text((middle, top + 62), name, "GeistMono-Bold.ttf", 34, SURFACE if is_gate else INK, "mm")
    canvas.text((middle, bottom + 46), caption, "InstrumentSans-Regular.ttf", 27, ACCENT if is_gate else MUTED, "mm")


def draw_arrow(canvas, start, end, fill=INK):
    canvas.line([*start, *end], fill, 3)
    x, y = end
    direction = 1 if end[0] >= start[0] else -1
    canvas.draw.polygon(canvas.box([x, y, x - 18 * direction, y - 10, x - 18 * direction, y + 10]), fill=fill)


def step_bounds(row, column):
    left = 80 + column * 590
    top = 190 + row * 330
    return (left, top, left + 470, top + 124)


def draw_loop(fonts, path):
    canvas = Canvas(2400, 900, fonts)
    canvas.text((80, 104), "Loop Engineering", "InstrumentSerif-Regular.ttf", 76, INK)
    canvas.text((2320, 98), "ONE TASK, FROM CARD TO MERGE", "GeistMono-Regular.ttf", 24, MUTED, "rs")
    for row, steps in enumerate(LOOP_ROWS):
        for column, step in enumerate(steps):
            bounds = step_bounds(row, column)
            draw_step(canvas, bounds, step)
            if column < 3:
                draw_arrow(canvas, (bounds[2] + 14, bounds[1] + 62), (bounds[2] + 106, bounds[1] + 62))
    draw_row_turn(canvas)
    draw_fail_return(canvas)
    canvas.circle((92, 828), 12, fill=ACCENT)
    canvas.text((120, 838), "The two steps only you take", "InstrumentSans-Regular.ttf", 27, MUTED)
    canvas.save(path)


def draw_row_turn(canvas):
    first = step_bounds(0, 3)
    second = step_bounds(1, 0)
    turn = 444
    start_x = first[2] - 24
    canvas.line([start_x, first[3] + 4, start_x, turn, 40, turn, 40, second[1] + 62], INK, 3)
    draw_arrow(canvas, (40, second[1] + 62), (second[0] - 8, second[1] + 62))
    canvas.text((1200, turn - 14), "approved spec", "GeistMono-Regular.ttf", 22, MUTED, "ms")


def draw_fail_return(canvas):
    work = step_bounds(1, 0)
    verifier = step_bounds(1, 1)
    low = verifier[3] + 100
    start_x = (verifier[0] + verifier[2]) / 2
    end_x = (work[0] + work[2]) / 2
    canvas.line([start_x, verifier[3] + 78, start_x, low, end_x, low, end_x, work[3] + 96], ACCENT, 3)
    canvas.draw.polygon(canvas.box([end_x, work[3] + 78, end_x - 10, work[3] + 96, end_x + 10, work[3] + 96]), fill=ACCENT)
    canvas.text(((start_x + end_x) / 2, low + 34), "FAIL: fix, push, verify again", "GeistMono-Regular.ttf", 22, ACCENT, "ms")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--fonts", type=Path, required=True)
    parser.add_argument("--out", type=Path, default=Path(__file__).resolve().parent.parent / "docs" / "assets")
    args = parser.parse_args()
    draw_banner(args.fonts, args.out / "banner.png")
    draw_loop(args.fonts, args.out / "loop.png")


if __name__ == "__main__":
    main()
