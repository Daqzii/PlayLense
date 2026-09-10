#!/usr/bin/env python3
"""Übungsbibliothek: prüfen, anlegen, auflisten, bündeln.

Aufrufe (aus dem Repo-Root):
  python3 tools/exercises.py validate            alle Dateien in content/exercises prüfen
  python3 tools/exercises.py list [--tag X] [--goal Y]
  python3 tools/exercises.py stats              Abdeckung je Ziel, Form-Tag, Animation
  python3 tools/exercises.py new <slug> [--file 99-eigene.json]
                                               neue Übung aus der Vorlage anlegen
  python3 tools/exercises.py bundle             content/exercises.seed.json für die App erzeugen

Keine Abhängigkeiten außer der Python-Standardbibliothek.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
import uuid
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CONTENT = ROOT / "content"
EXERCISES_DIR = CONTENT / "exercises"
TEMPLATE = CONTENT / "TEMPLATE.exercise.json"
BUNDLE = CONTENT / "exercises.seed.json"
SWIFT_RESOURCE = ROOT / "PlayLenseCore" / "Sources" / "PlayLenseCore" / "Resources" / "exercises.seed.json"

# Stabiler Namensraum: id = uuid5(NAMESPACE, slug). Gleicher Slug → gleiche ID, auch nach Re-Import.
NAMESPACE = uuid.UUID("7d0a2c2e-4d3b-4a5e-9c1f-3e2f9b6a1d10")

SLUG_RE = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
REQUIRED = {
    "slug": str, "name": str, "goal_primary": str, "goals_secondary": list,
    "players_min": int, "players_max": int, "duration_min": int, "duration_max": int,
    "intensity": int, "field_width_m": int, "field_length_m": int, "material": list,
    "description": str, "procedure": str, "coaching_points": list, "variations": dict,
    "tags": list,
}
OPTIONAL = {"animation": (dict, type(None)), "source": str, "notes": str}
ZONE_KINDS = {"zone", "line", "text"}
TOKEN_KINDS = {"player", "neutral", "cone", "minigoal", "goal", "pole", "hurdle"}


def load_vocab() -> tuple[dict, dict, set]:
    goals = {g["key"]: g for g in json.loads((CONTENT / "goals.json").read_text())["goals"]}
    tags = {t["key"]: t for t in json.loads((CONTENT / "tags.json").read_text())["tags"]}
    material = {m["key"] for m in json.loads((CONTENT / "material.json").read_text())["material"]}
    return goals, tags, material


def exercise_files() -> list[Path]:
    return sorted(p for p in EXERCISES_DIR.glob("*.json") if not p.name.startswith("_"))


def load_all() -> list[tuple[Path, int, dict]]:
    out = []
    for path in exercise_files():
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except json.JSONDecodeError as e:
            print(f"FEHLER {path.name}: kein gültiges JSON ({e})")
            sys.exit(2)
        if not isinstance(data, list):
            print(f"FEHLER {path.name}: Datei muss eine JSON-Liste von Übungen sein")
            sys.exit(2)
        for i, ex in enumerate(data):
            out.append((path, i, ex))
    return out


def validate_animation(anim: dict, where: str, errors: list[str]) -> None:
    if anim.get("version") != 1:
        errors.append(f"{where}: animation.version muss 1 sein")
    pitch = anim.get("pitch", {})
    for k in ("width_m", "length_m"):
        if not isinstance(pitch.get(k), (int, float)) or pitch[k] <= 0:
            errors.append(f"{where}: animation.pitch.{k} fehlt oder ungültig")
    tokens = anim.get("tokens", [])
    ids = [t.get("id") for t in tokens]
    if len(ids) != len(set(ids)):
        errors.append(f"{where}: animation.tokens enthält doppelte ids")
    for t in tokens:
        if t.get("kind") not in TOKEN_KINDS:
            errors.append(f"{where}: token {t.get('id')} hat unbekannte kind '{t.get('kind')}'")
        if t.get("kind") == "player" and t.get("team") not in {"own", "opp"}:
            errors.append(f"{where}: player-token {t.get('id')} braucht team own/opp")
    known = set(ids)
    for s in anim.get("static", []):
        if s.get("kind") not in ZONE_KINDS:
            errors.append(f"{where}: static-element mit unbekannter kind '{s.get('kind')}'")
    frames = anim.get("keyframes", [])
    if len(frames) < 2:
        errors.append(f"{where}: animation braucht mindestens 2 keyframes")
    last_t = -1.0
    placed: set[str] = set()
    for n, f in enumerate(frames):
        t = f.get("t")
        if not isinstance(t, (int, float)) or t <= last_t:
            errors.append(f"{where}: keyframe {n} hat kein aufsteigendes t")
        else:
            last_t = t
        for tid, pos in f.get("positions", {}).items():
            if tid not in known:
                errors.append(f"{where}: keyframe {n} positioniert unbekanntes token '{tid}'")
            if not (isinstance(pos, list) and len(pos) == 2 and all(isinstance(v, (int, float)) for v in pos)):
                errors.append(f"{where}: keyframe {n} position von '{tid}' muss [x, y] sein")
            placed.add(tid)
        ball = f.get("ball", {})
        holder = ball.get("holder")
        if holder is not None and holder not in known:
            errors.append(f"{where}: keyframe {n} ball.holder '{holder}' unbekannt")
        if holder is None and "at_m" not in ball:
            errors.append(f"{where}: keyframe {n} braucht ball.holder oder ball.at_m")
        tr = f.get("transition", {})
        if "pass" in tr:
            p = tr["pass"]
            if not (isinstance(p, list) and len(p) == 2 and all(x in known for x in p)):
                errors.append(f"{where}: keyframe {n} transition.pass muss [von, zu] mit bekannten ids sein")
    if frames:
        missing = known - set(frames[0].get("positions", {}).keys())
        if missing:
            errors.append(f"{where}: keyframe 0 muss alle tokens positionieren, fehlt: {sorted(missing)}")


def validate(verbose: bool = True) -> int:
    goals, tags, material = load_vocab()
    template = json.loads(TEMPLATE.read_text(encoding="utf-8"))
    items = load_all()
    errors: list[str] = []
    slugs: Counter = Counter()
    for path, i, ex in items:
        where = f"{path.name}[{i}] {ex.get('slug', '?')}"
        for key, typ in REQUIRED.items():
            if key not in ex:
                errors.append(f"{where}: Pflichtfeld '{key}' fehlt")
            elif not isinstance(ex[key], typ) or (typ is int and isinstance(ex[key], bool)):
                errors.append(f"{where}: Feld '{key}' hat falschen Typ (erwartet {typ.__name__})")
        for key, typ in OPTIONAL.items():
            if key in ex and not isinstance(ex[key], typ):
                errors.append(f"{where}: Feld '{key}' hat falschen Typ")
        extra = set(ex) - set(REQUIRED) - set(OPTIONAL)
        if extra:
            errors.append(f"{where}: unbekannte Felder {sorted(extra)}")
        if any(k not in ex for k in REQUIRED):
            continue
        slug = ex["slug"]
        slugs[slug] += 1
        if not SLUG_RE.match(slug):
            errors.append(f"{where}: slug nur kleinbuchstaben, ziffern, bindestrich")
        if ex["goal_primary"] not in goals:
            errors.append(f"{where}: goal_primary '{ex['goal_primary']}' nicht in goals.json")
        for g in ex["goals_secondary"]:
            if g not in goals:
                errors.append(f"{where}: goals_secondary '{g}' nicht in goals.json")
            if g == ex["goal_primary"]:
                errors.append(f"{where}: goal_primary darf nicht auch in goals_secondary stehen")
        if not (1 <= ex["players_min"] <= ex["players_max"] <= 30):
            errors.append(f"{where}: players_min/max ungültig")
        if not (3 <= ex["duration_min"] <= ex["duration_max"] <= 60):
            errors.append(f"{where}: duration_min/max ungültig (3..60)")
        if not (1 <= ex["intensity"] <= 5):
            errors.append(f"{where}: intensity muss 1..5 sein")
        if not (5 <= ex["field_width_m"] <= 75 and 5 <= ex["field_length_m"] <= 110):
            errors.append(f"{where}: Feldmaße unplausibel")
        for m in ex["material"]:
            if not isinstance(m, dict) or m.get("item") not in material or not isinstance(m.get("count"), int) or m["count"] < 1:
                errors.append(f"{where}: material-Eintrag ungültig: {m}")
        if len(ex["coaching_points"]) < 3:
            errors.append(f"{where}: mindestens 3 coaching_points")
        if set(ex["variations"]) != {"easier", "harder"} or not all(isinstance(v, list) for v in ex["variations"].values()):
            errors.append(f"{where}: variations braucht genau die Listen 'easier' und 'harder'")
        elif not ex["variations"]["easier"] or not ex["variations"]["harder"]:
            errors.append(f"{where}: je mindestens eine Variation easier und harder")
        form_tags = 0
        for t in ex["tags"]:
            if t not in tags:
                errors.append(f"{where}: tag '{t}' nicht in tags.json")
            elif tags[t]["category"] == "form":
                form_tags += 1
        if form_tags == 0:
            errors.append(f"{where}: mindestens ein Tag der Kategorie 'form'")
        if len(ex["tags"]) != len(set(ex["tags"])):
            errors.append(f"{where}: doppelte tags")
        if len(ex["description"]) < 30 or len(ex["procedure"]) < 60:
            errors.append(f"{where}: description (≥30 Zeichen) oder procedure (≥60 Zeichen) zu kurz")
        for key in ("name", "description", "procedure"):
            if ex[key] == template.get(key):
                errors.append(f"{where}: Feld '{key}' enthält noch den Platzhalter aus der Vorlage")
        if ex["coaching_points"] == template.get("coaching_points") or ex["variations"] == template.get("variations"):
            errors.append(f"{where}: coaching_points oder variations enthalten noch die Vorlage")
        if ex.get("animation"):
            validate_animation(ex["animation"], where, errors)
    for slug, n in slugs.items():
        if n > 1:
            errors.append(f"slug '{slug}' kommt {n}× vor")
    if errors:
        for e in errors:
            print("FEHLER", e)
        print(f"\n{len(errors)} Fehler in {len(items)} Übungen")
        return 1
    if verbose:
        print(f"OK: {len(items)} Übungen in {len(exercise_files())} Dateien, keine Fehler")
    return 0


def cmd_list(args) -> int:
    for path, _, ex in load_all():
        if args.tag and args.tag not in ex.get("tags", []):
            continue
        if args.goal and args.goal != ex.get("goal_primary") and args.goal not in ex.get("goals_secondary", []):
            continue
        anim = "🎞" if ex.get("animation") else "  "
        print(f"{anim} {ex['slug']:<40} {ex['goal_primary']:<24} {ex['players_min']:>2}-{ex['players_max']:<2} Sp. "
              f"{ex['duration_min']:>2}-{ex['duration_max']:<2} min  I{ex['intensity']}  ({path.name})")
    return 0


def cmd_stats(_args) -> int:
    goals, tags, _ = load_vocab()
    items = [ex for _, _, ex in load_all()]
    print(f"Übungen gesamt: {len(items)}   mit Animation: {sum(1 for e in items if e.get('animation'))}\n")
    print("Je Hauptziel:")
    c = Counter(e["goal_primary"] for e in items)
    cs = Counter(g for e in items for g in e["goals_secondary"])
    for key, g in goals.items():
        print(f"  {g['label']:<38} primär {c[key]:>2}   sekundär {cs[key]:>2}")
    print("\nJe Form-Tag:")
    ct = Counter(t for e in items for t in e["tags"])
    for key, t in tags.items():
        if t["category"] == "form":
            print(f"  {t['label']:<28} {ct[key]:>2}")
    print("\nIntensität:", dict(sorted(Counter(e["intensity"] for e in items).items())))
    return 0


def cmd_new(args) -> int:
    if not SLUG_RE.match(args.slug):
        print("slug nur kleinbuchstaben, ziffern, bindestrich")
        return 1
    if any(ex.get("slug") == args.slug for _, _, ex in load_all()):
        print(f"slug '{args.slug}' existiert bereits")
        return 1
    template = json.loads(TEMPLATE.read_text(encoding="utf-8"))
    template["slug"] = args.slug
    template["name"] = args.slug.replace("-", " ").title()
    target = EXERCISES_DIR / args.file
    data = json.loads(target.read_text(encoding="utf-8")) if target.exists() else []
    data.append(template)
    target.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Vorlage angehängt an {target.relative_to(ROOT)} (Eintrag {len(data)}). Jetzt ausfüllen und 'validate' laufen lassen.")
    return 0


def cmd_bundle(_args) -> int:
    if validate(verbose=False) != 0:
        return 1
    goals, tags, material = load_vocab()
    out = []
    for path, _, ex in load_all():
        item = dict(ex)
        item["id"] = str(uuid.uuid5(NAMESPACE, ex["slug"]))
        item.setdefault("animation", None)
        item.setdefault("source", "seed")
        item["_file"] = path.name
        out.append(item)
    bundle = {
        "schema_version": 1,
        "goals": list(goals.values()),
        "tags": list(tags.values()),
        "material": sorted(material),
        "exercises": out,
    }
    text = json.dumps(bundle, ensure_ascii=False, indent=1) + "\n"
    BUNDLE.write_text(text, encoding="utf-8")
    print(f"{BUNDLE.relative_to(ROOT)} geschrieben: {len(out)} Übungen")
    if SWIFT_RESOURCE.parent.is_dir():
        SWIFT_RESOURCE.write_text(text, encoding="utf-8")
        print(f"{SWIFT_RESOURCE.relative_to(ROOT)} aktualisiert")
    return 0


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="cmd", required=True)
    sub.add_parser("validate")
    l = sub.add_parser("list"); l.add_argument("--tag"); l.add_argument("--goal")
    sub.add_parser("stats")
    n = sub.add_parser("new"); n.add_argument("slug"); n.add_argument("--file", default="99-eigene.json")
    sub.add_parser("bundle")
    args = p.parse_args()
    return {"validate": lambda a: validate(), "list": cmd_list, "stats": cmd_stats, "new": cmd_new, "bundle": cmd_bundle}[args.cmd](args)


if __name__ == "__main__":
    sys.exit(main())
