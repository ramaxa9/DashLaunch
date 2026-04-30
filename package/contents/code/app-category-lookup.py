#!/usr/bin/env python3

from __future__ import annotations

import os
import re
import sys
from pathlib import Path


APP_DIRS = [
    Path.home() / ".local/share/applications",
    Path("/usr/local/share/applications"),
    Path("/usr/share/applications"),
]

GENERIC_PREFIXES = ("Qt", "KDE", "GNOME", "GTK", "XFCE", "X-")


def normalize_text(value: str) -> str:
    return "".join(character for character in value.casefold() if character.isalnum())


def tokenize(value: str) -> list[str]:
    return [token for token in re.split(r"[^0-9A-Za-z]+", value.casefold()) if token]


def parse_desktop_file(path: Path) -> dict[str, object] | None:
    try:
        lines = path.read_text(encoding="utf-8", errors="ignore").splitlines()
    except OSError:
        return None

    names: list[str] = []
    icon = ""
    startup_wm_class = ""
    categories: list[str] = []

    for line in lines:
        if not line or line.startswith("#") or "=" not in line:
            continue

        key, value = line.split("=", 1)
        if key == "Icon":
            icon = value.strip()
        elif key == "StartupWMClass":
            startup_wm_class = value.strip()
        elif key == "Categories":
            categories = [item for item in value.split(";") if item]
        elif key == "Name" or key.startswith("Name["):
            stripped = value.strip()
            if stripped:
                names.append(stripped)

    return {
        "path": path,
        "base_name": path.stem,
        "names": names,
        "icon": icon,
        "startup_wm_class": startup_wm_class,
        "categories": categories,
    }


def iter_desktop_entries():
    for root in APP_DIRS:
        if not root.is_dir():
            continue
        for path in root.rglob("*.desktop"):
            entry = parse_desktop_file(path)
            if entry:
                yield entry


def subset_score(lookup_tokens: set[str], candidate_tokens: set[str], base_score: int) -> int:
    if not lookup_tokens or not candidate_tokens:
        return 0
    if candidate_tokens.issubset(lookup_tokens):
        return base_score + len(candidate_tokens)
    if lookup_tokens.issubset(candidate_tokens):
        return base_score - 20 + len(lookup_tokens)
    return 0


def score_entry_for_name(entry: dict[str, object], lookup_name: str) -> int:
    normalized_lookup = normalize_text(lookup_name)
    if not normalized_lookup:
        return 0

    lookup_tokens = set(tokenize(lookup_name))
    base_name = str(entry["base_name"])
    normalized_base_name = normalize_text(base_name)
    if normalized_base_name == normalized_lookup:
        return 500

    score = 0

    for value in (str(entry["icon"]), str(entry["startup_wm_class"])):
        normalized_value = normalize_text(value)
        if not normalized_value:
            continue
        if normalized_value == normalized_lookup:
            score = max(score, 450)
        score = max(score, subset_score(lookup_tokens, set(tokenize(value)), 360))

    score = max(score, subset_score(lookup_tokens, set(tokenize(base_name)), 420))

    for name in entry["names"]:  # type: ignore[index]
        normalized_name = normalize_text(str(name))
        if normalized_name == normalized_lookup:
            score = max(score, 430)
            continue
        score = max(score, subset_score(lookup_tokens, set(tokenize(str(name))), 320))

    return score


def resolve_entry_from_lookup(lookup_key: str) -> dict[str, object] | None:
    if not lookup_key or lookup_key.startswith("preferred://"):
        return None

    lookup_key = lookup_key.split("?", 1)[0].split("#", 1)[0]

    if lookup_key.startswith("applications:"):
        lookup_key = lookup_key[len("applications:") :]

    if lookup_key.startswith("name:"):
        lookup_name = lookup_key[len("name:") :].strip()
        best_entry = None
        best_score = 0
        for entry in iter_desktop_entries():
            score = score_entry_for_name(entry, lookup_name)
            if score > best_score:
                best_entry = entry
                best_score = score
        return best_entry

    path = Path(lookup_key)
    if path.is_file():
        return parse_desktop_file(path)

    base_name = Path(lookup_key).name
    if not base_name.endswith(".desktop"):
        base_name += ".desktop"

    for root in APP_DIRS:
        if not root.is_dir():
            continue
        direct_path = root / base_name
        if direct_path.is_file():
            return parse_desktop_file(direct_path)
        for candidate in root.rglob(base_name):
            entry = parse_desktop_file(candidate)
            if entry:
                return entry

    return None


def map_category(categories: list[str]) -> str:
    category_map = {
        "AudioVideo": "Multimedia",
        "Audio": "Multimedia",
        "Video": "Multimedia",
        "Player": "Multimedia",
        "Recorder": "Multimedia",
        "DiscBurning": "Multimedia",
        "Midi": "Multimedia",
        "Mixer": "Multimedia",
        "Music": "Multimedia",
        "MusicPlayer": "Multimedia",
        "Tuner": "Multimedia",
        "TV": "Multimedia",
        "Network": "Internet",
        "WebBrowser": "Internet",
        "Email": "Internet",
        "InstantMessaging": "Internet",
        "IRCClient": "Internet",
        "Feed": "Internet",
        "FileTransfer": "Internet",
        "HamRadio": "Internet",
        "P2P": "Internet",
        "RemoteAccess": "Internet",
        "Telephony": "Internet",
        "VideoConference": "Internet",
        "Office": "Office",
        "WordProcessor": "Office",
        "Spreadsheet": "Office",
        "Presentation": "Office",
        "Database": "Office",
        "Calendar": "Office",
        "ContactManagement": "Office",
        "ProjectManagement": "Office",
        "Graphics": "Graphics",
        "2DGraphics": "Graphics",
        "3DGraphics": "Graphics",
        "RasterGraphics": "Graphics",
        "VectorGraphics": "Graphics",
        "Scanning": "Graphics",
        "Photography": "Graphics",
        "Viewer": "Graphics",
        "Development": "Development",
        "IDE": "Development",
        "GUIDesigner": "Development",
        "Profiling": "Development",
        "RevisionControl": "Development",
        "Building": "Development",
        "Debugger": "Development",
        "Education": "Education",
        "Languages": "Education",
        "ArtificialIntelligence": "Education",
        "Astronomy": "Education",
        "Biology": "Education",
        "Chemistry": "Education",
        "ComputerScience": "Education",
        "DataVisualization": "Education",
        "Economy": "Education",
        "Electricity": "Education",
        "Geography": "Education",
        "Geology": "Education",
        "History": "Education",
        "ImageProcessing": "Education",
        "Literature": "Education",
        "Math": "Education",
        "NumericalAnalysis": "Education",
        "MedicalSoftware": "Education",
        "Physics": "Education",
        "Robotics": "Education",
        "Sports": "Education",
        "Science": "Science",
        "Game": "Games",
        "ActionGame": "Games",
        "AdventureGame": "Games",
        "ArcadeGame": "Games",
        "BlocksGame": "Games",
        "BoardGame": "Games",
        "CardGame": "Games",
        "KidsGame": "Games",
        "LogicGame": "Games",
        "RolePlaying": "Games",
        "Shooter": "Games",
        "Simulation": "Games",
        "SportsGame": "Games",
        "StrategyGame": "Games",
        "Utility": "Utilities",
        "Calculator": "Utilities",
        "Clock": "Utilities",
        "Compression": "Utilities",
        "FileTools": "Utilities",
        "TextTools": "Utilities",
        "Settings": "Settings",
        "System": "System",
        "TerminalEmulator": "System",
        "FileManager": "System",
        "Monitor": "System",
        "Core": "System",
        "Documentation": "Help",
        "Help": "Help",
    }

    for category in categories:
        mapped = category_map.get(category)
        if mapped:
            return mapped

    for category in categories:
        if not category or category.startswith(GENERIC_PREFIXES):
            continue
        return category

    return ""


def main() -> int:
    lookup_key = sys.argv[1] if len(sys.argv) > 1 else ""
    entry = resolve_entry_from_lookup(lookup_key)
    if not entry:
        return 0

    category = map_category(entry["categories"])  # type: ignore[arg-type]
    if category:
        sys.stdout.write(category)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())