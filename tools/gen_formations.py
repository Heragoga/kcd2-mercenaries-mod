"""Regenerate data/AI/FormationDefinitions.xml.

RUN THIS AFTER EVERY GAME UPDATE.

FormationDefinitions.xml is not a patchable database table, so a mod cannot merge
into it - it can only replace the whole file. The output is therefore the vanilla
catalogue copied verbatim from references/AI/FormationDefinitions.xml with our
merc_* presets appended. Anything dropped from that copy stops existing game-wide
and breaks every vanilla quest that names it, so the vanilla half is never edited
by hand and this script asserts that all of it survived.

Coordinate convention: +x is the anchor's RIGHT, +y is BEHIND it, metres. The
anchor is the elected leader merc, who gets no <Spot> of his own.

Nothing is ever placed AHEAD of the anchor. The player walks at the head of the
squad with the leader just behind him; a spot forward of the leader ends up level
with or past the PLAYER, which reads as him being swallowed by his own squad.

    python tools/gen_formations.py
"""
import io, math, os, re

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
VANILLA = os.path.join(REPO, "references", "AI", "FormationDefinitions.xml")
OUT = os.path.join(REPO, "data", "AI", "FormationDefinitions.xml")

# Sizes emitted per shape. Lua picks the smallest that seats the squad - handing a
# 50-slot template to six mercs lets the engine drop them in any six of fifty spots
# and strings them out over the whole thing. Keep in step with
# mercenaries.FormationSizes in data/Scripts/mods/mercenaries_formation.lua.
SIZES = (6, 10, 14, 18, 24, 30, 40, 50)

# The numbers that decide whether a squad marches or mills about:
#   R        arrival tolerance. A follower inside it is "in place" and stops
#            correcting. Must stay STRICTLY under half the pitch or two neighbours'
#            discs overlap and ranks interleave. Vanilla uses 0.5 only for
#            formations of 5-8; its loose and mounted presets run 1-3.
#   PITCH    neighbour spacing; must clear an NPC footprint plus pathing slack.
#   STANDOFF gap in front of the first rank before the leader is folded in.
#   LEAD_GAP how far the leader rides ahead of shapes he is not seated into.
R = 0.9
R_LOOSE = 1.3
PITCH = 2.0
STANDOFF = 3.4
LINE_MAX_PER_RANK = 12
LEAD_GAP = 1.6
#   CIRCLE_PLAYER_AHEAD how far ahead of the anchor the circle's centre sits, i.e. the
#   leader's own follow standoff from the player. See ring_on_player.
CIRCLE_PLAYER_AHEAD = 3.0


def fmt(v):
    s = "%.2f" % v
    s = s.rstrip("0").rstrip(".")
    return s if s not in ("", "-0") else "0"


def spot(name, x, y, radius):
    return '        <Spot name="%s" radius="%s" x="%s" y="%s" />' % (
        name, fmt(radius), fmt(x), fmt(y))


def coords(s):
    return (float(re.search(r'x="(-?[\d.]+)"', s).group(1)),
            float(re.search(r'y="(-?[\d.]+)"', s).group(1)))


def shift(s, dx, dy):
    x, y = coords(s)
    s = re.sub(r'x="(-?[\d.]+)"', 'x="%s"' % fmt(x - dx), s)
    return re.sub(r'y="(-?[\d.]+)"', 'y="%s"' % fmt(y - dy), s)


def rows(n, per_row, y0, dy, pitch=PITCH, name_front=2):
    """n spots in centred rows of at most per_row, front rank at y0."""
    out, r = [], 0
    while len(out) < n:
        take = min(per_row, n - len(out))
        for i in range(take):
            x = (i - (take - 1) / 2.0) * pitch
            out.append(spot("front" if r < name_front else "back", x, y0 + r * dy, R))
        r += 1
    return out


def column(n):
    # A genuine column of twos: narrow, and deep as a consequence. The road and
    # forest-track option. Ranks are tighter than PITCH because the file spacing
    # already provides lateral clearance.
    return rows(n, 2, STANDOFF, 1.8, pitch=2.4)


def line_shape(n):
    # A battle LINE is shallow and wide, so the RANK COUNT is fixed and the width
    # follows the headcount. Capping the width instead made it converge on the
    # square - at 50 both resolved to 8 per rank and were byte-identical. A small
    # squad gets a single rank, because "two ranks of three" is equally a square.
    ranks = 1 if n <= 10 else (2 if n <= 24 else 3)
    # ...but never wider than LINE_MAX_PER_RANK abreast. The shape pivots with its
    # leader, so a man at the end of a rank sweeps half-width x turn-angle every time
    # the player turns: at 50 in three ranks that was 17 abreast, +-16 m, and the end
    # men could not keep up with any turn ("lost at the back", 2026-09-03). 12 abreast
    # caps that at +-11 m; 50 becomes five ranks, which is still wider than the square
    # (8 abreast) and unchanged for the two-rank line at 24 and under.
    ranks = max(ranks, int(math.ceil(n / float(LINE_MAX_PER_RANK))))
    return rows(n, int(math.ceil(n / float(ranks))), STANDOFF, 2.0)


def square_shape(n):
    # Actually square: width and depth both ~sqrt(n).
    return rows(n, max(2, int(math.ceil(math.sqrt(n)))), STANDOFF, 2.0)


def wedge_shape(n):
    # Filled arrowhead - each rank one wider than the last, so it reads as a wedge
    # from behind instead of two long arms trailing off into the distance.
    out, r = [], 0
    while len(out) < n:
        width = r + 2
        for i in range(min(width, n - len(out))):
            x = (i - (width - 1) / 2.0) * PITCH
            out.append(spot("front" if r < 2 else "back", x, STANDOFF + r * 1.8, R))
        r += 1
    return out[:n]


def circle_shape(n):
    # Radius derived from the headcount so neighbours keep ~2m of arc; past a dozen
    # it splits into two rings rather than becoming a shoulder-to-shoulder wall.
    def ring(count, radius, nm):
        return [spot(nm, radius * math.sin(2 * math.pi * i / count),
                     radius * math.cos(2 * math.pi * i / count), R_LOOSE)
                for i in range(count)]

    if n <= 12:
        return ring(n, max(3.5, min(6.0, n * PITCH / (2 * math.pi))), "inner")
    return ring(12, 4.2, "inner") + ring(n - 12, 7.0, "outer")


def escort_shape(n):
    # Two flanking files with the middle left open for the player to walk in.
    out = []
    for i in range((n + 1) // 2):
        y = 1.0 + i * PITCH
        out.append(spot("left", -4.0, y, R_LOOSE))
        if len(out) < n:
            out.append(spot("right", 4.0, y, R_LOOSE))
    return out[:n]


def mounted_shape(n):
    # The one mounted shape: a triple column. A horse is ~2.5m long and corners
    # wide, so files sit 3.5m apart with 4m ranks, and the arrival radius is 1.8 -
    # vanilla's mounted presets run 1-3 where its infantry ones run 0.5.
    out, rank = [], 0
    while len(out) < n:
        for f in (-1, 0, 1):
            if len(out) >= n:
                break
            out.append(spot("rank%d" % (rank + 1), f * 3.5, 5.0 + rank * 4.0, 1.8))
        rank += 1
    return out[:n]


def seat_the_leader(spots):
    """Fold the leader INTO the shape at its front-most central position.

    A formation anchors on the leader's transform and he never gets a <Spot>, so a
    shape authored as "everyone behind the origin" leaves him walking alone a
    standoff ahead of the front rank. Laying out n+1 bodies and translating his
    position onto the origin makes him a member of the front rank instead - and
    front-most, specifically, guarantees no spot is ever ahead of him.
    """
    pts = [coords(s) + (s,) for s in spots]
    lx, ly, lead = min(pts, key=lambda p: (p[1], abs(p[0])))
    return [shift(s, lx, ly) for x, y, s in pts if s is not lead]


def push_behind(spots):
    """Centre a shape laterally on the anchor and slide it fully behind him.

    For shapes the leader is not seated into (escort) - he stays off-lattice in the
    middle of the gap, LEAD_GAP ahead of the nearest rank.
    """
    pts = [coords(s) for s in spots]
    cx = sum(p[0] for p in pts) / float(len(pts))
    dy = min(p[1] for p in pts) - LEAD_GAP
    return [shift(s, cx, dy) for s in spots]


def ring_on_player(spots):
    """Centre a ring on the PLAYER, which for a circle is the whole point.

    Every other shape is laid out behind the anchor, and push_behind used to do the
    same to this one: merc_circle50 came out centred 8.6m BEHIND the leader, who is
    himself behind the player, so the ring enclosed nobody (2026-09-03).

    A formation is anchored on the leader, and the leader follows the player at
    roughly CIRCLE_PLAYER_AHEAD, so putting the ring's centre that far in FRONT of
    the anchor puts the player in the middle of it. That necessarily places spots
    ahead of the leader, which every other shape forbids - a follower standing in
    front of the anchor blocks the one NPC the shape hangs off. The circle is the
    documented exception to that rule and already is one elsewhere:
    TeleportGuardActive skips the same "keep behind the leader" guard for circle,
    "because it is defined by mercs standing all round the player".

    CIRCLE_PLAYER_AHEAD is the leader's follow standoff, which is CrimeFollower's
    own default and not a number this mod sets - so it is an estimate, and the one
    thing to adjust if the ring sits off-centre by eye.
    """
    pts = [coords(s) for s in spots]
    cx = sum(p[0] for p in pts) / float(len(pts))
    cy = sum(p[1] for p in pts) / float(len(pts))
    return [shift(s, cx, cy + CIRCLE_PLAYER_AHEAD) for s in spots]


# Keys MUST match mercenaries.FormationShapeOrder: Lua builds the preset name as
# "merc_" .. shape .. size, so a rename here breaks the lookup and MakeFormation is
# handed a name that does not exist - which silently drops the squad to the follow
# chain and looks exactly like the formation system being broken.
SHAPES = [
    ("column", column,       "column of twos - narrow, for roads and tracks"),
    ("line",   line_shape,   "ranks abreast - a battle line"),
    ("square", square_shape, "square block"),
    ("wedge",  wedge_shape,  "filled arrowhead"),
    ("circle", circle_shape, "ring"),
    ("escort", escort_shape, "two flanking files, middle left open"),
    ("mounted", mounted_shape, "triple column at horse spacing - the one mounted shape"),
]

# circle and escort are excluded: both are built AROUND the anchor rather than behind
# him - circle as the centre of the ring, escort as the open gap - and seating him into
# a file would shove the whole shape sideways. They are laid out differently from each
# other, though: escort is pushed behind the leader, the circle is centred on the
# player (ring_on_player), which is the only shape with spots ahead of the anchor.
SEAT_LEADER = {"column", "line", "square", "wedge", "mounted"}
AHEAD_OK = {"circle"}

blocks, report = [], []
for key, fn, desc in SHAPES:
    for n in SIZES:
        if key in SEAT_LEADER:
            spots = seat_the_leader(fn(n + 1))
        elif key in AHEAD_OK:
            spots = ring_on_player(fn(n))
        else:
            spots = push_behind(fn(n))
        assert len(spots) == n, (key, n, len(spots))
        if key not in AHEAD_OK:
            assert all(coords(s)[1] >= -0.01 for s in spots), "spot ahead of the anchor: %s%d" % (key, n)
        name = "merc_%s%d" % (key, n)
        blocks.append('    <!-- %s (%d) -->\n    <Formation name="%s">\n%s\n    </Formation>'
                      % (desc, n, name, "\n".join(spots)))
        xs = [coords(s)[0] for s in spots]
        ys = [coords(s)[1] for s in spots]
        report.append("  %-22s %2d spots  %5.1fm wide  %5.1fm deep"
                      % (name, n, max(xs) - min(xs), max(ys) - min(ys)))

src = io.open(VANILLA, encoding="utf-8", newline="").read()
head = src[:src.rindex("</FormationDefinitions>")].rstrip("\r\n")

BANNER = (
    "\n\n"
    "    <!-- ================================================================\n"
    "         MERCENARIES MOD - custom formations. GENERATED by\n"
    "         tools/gen_formations.py - do not hand-edit, re-run it instead.\n"
    "\n"
    "         Everything ABOVE this banner is vanilla, copied verbatim. It has to\n"
    "         be: FormationDefinitions.xml is not a patchable database table, so a\n"
    "         mod can only replace the whole file. Any vanilla formation dropped\n"
    "         from this list stops existing game-wide and breaks the quests that\n"
    "         name it. After a game update, re-run the generator so it re-copies\n"
    "         the current vanilla file and re-appends this block.\n"
    "\n"
    "         Convention: +x is the leader's RIGHT, +y is BEHIND him, metres. The\n"
    "         leader stands at the origin and gets no spot. Nothing is ever placed\n"
    "         ahead of him, so the player stays at the head of the squad.\n"
    "         ================================================================ -->\n\n"
)

out = head + BANNER + "\n\n".join(blocks) + "\n\n</FormationDefinitions>\n"
io.open(OUT, "w", encoding="utf-8", newline="\n").write(out)

names_in = re.findall(r'<Formation name="([^"]+)"', src)
names_out = re.findall(r'<Formation name="([^"]+)"', out)
missing = [n for n in names_in if n not in names_out]
assert not missing, "DROPPED VANILLA FORMATIONS: %s" % missing

print("wrote", OUT)
print("vanilla %d -> output %d (+%d), none dropped"
      % (len(names_in), len(names_out), len(names_out) - len(names_in)))
print("\n".join(report))
