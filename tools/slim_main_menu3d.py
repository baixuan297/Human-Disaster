# Rebuilds Scene/menu/main_menu3d.tscn: spaceship = instanced scene; keeps only SubResources
# needed by UI + Camera/FishMan/alien tail (dependency closure from backup).
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "Scene/menu/main_menu3d.tscn"
BAK = ROOT / "Scene/menu/main_menu3d_huge_embedded_backup.tscn"

SUB_REF = re.compile(r'SubResource\("([^"]+)"\)')

# 1-based line numbers in BAK (main_menu3d_huge_embedded_backup.tscn)
EXT_LINE_FIRST = 3
EXT_LINE_LAST_UI_TEX = 17
EXT_LINE_SCRIPT_LO = 62
EXT_LINE_SCRIPT_HI = 63
NODE_MAIN_MENU = 42275
NODE_AFTER_UI = 42438
NODE_FIRST_CAMERA = 44232


def parse_subresource_blocks(lines: list[str], end_index: int) -> tuple[dict[str, list[str]], list[str]]:
    blocks: dict[str, list[str]] = {}
    order: list[str] = []
    i = 0
    while i < end_index:
        line = lines[i]
        if line.startswith("[sub_resource "):
            m = re.search(r'id="([^"]+)"', line)
            if not m:
                i += 1
                continue
            rid = m.group(1)
            start = i
            i += 1
            while i < end_index:
                nxt = lines[i]
                if nxt.startswith(("[sub_resource ", "[ext_resource ", "[node ", "[connection")):
                    break
                i += 1
            blocks[rid] = lines[start:i]
            order.append(rid)
        else:
            i += 1
    return blocks, order


def collect_needed_sub_ids(blocks: dict[str, list[str]], seed_text: str) -> set[str]:
    needed: set[str] = set()
    queue: list[str] = list(SUB_REF.findall(seed_text))
    while queue:
        rid = queue.pop()
        if rid in needed:
            continue
        needed.add(rid)
        body = blocks.get(rid)
        if not body:
            continue
        for ref in SUB_REF.findall("".join(body)):
            if ref not in needed:
                queue.append(ref)
    return needed


def main() -> None:
    if not BAK.exists():
        raise SystemExit(f"Missing backup: {BAK}")

    lines = BAK.read_text(encoding="utf-8-sig").splitlines(True)
    node0 = next(i for i, l in enumerate(lines) if l.startswith("[node "))
    blocks, order = parse_subresource_blocks(lines, node0)

    i_ui0 = NODE_MAIN_MENU - 1
    i_ui1 = NODE_AFTER_UI
    i_tail0 = NODE_FIRST_CAMERA - 1
    ui_block = "".join(lines[i_ui0:i_ui1])
    tail_block = "".join(lines[i_tail0:])

    needed = collect_needed_sub_ids(blocks, ui_block + tail_block)

    ext_chunk = lines[EXT_LINE_FIRST - 1 : EXT_LINE_LAST_UI_TEX]
    scripts_chunk = lines[EXT_LINE_SCRIPT_LO - 1 : EXT_LINE_SCRIPT_HI]
    packed = (
        '[ext_resource type="PackedScene" uid="uid://bogws08hl6auq" '
        'path="res://Scene/spaceships/spaceship_interior_1.tscn" id="62_interior"]\n\n'
    )

    sub_out: list[str] = []
    for rid in order:
        if rid in needed:
            sub_out.extend(blocks[rid])
            sub_out.append("\n")

    ext_count = len(ext_chunk) + 1 + len(scripts_chunk)
    sub_count = sum(1 for rid in order if rid in needed)
    load_steps = ext_count + sub_count + 1

    out: list[str] = [
        f'[gd_scene load_steps={load_steps} format=4 uid="uid://iywcvhbsdr66"]\n\n',
    ]
    out.extend(ext_chunk)
    out.append(packed)
    out.extend(scripts_chunk)
    out.append("\n")
    out.extend(sub_out)
    out.extend(lines[i_ui0:i_ui1])
    out.append(
        '[node name="spaceship_interior1" parent="." instance=ExtResource("62_interior")]\n\n'
    )
    out.extend(lines[i_tail0:])

    OUT.write_text("".join(out), encoding="utf-8")
    print("Wrote", OUT)
    print("Size (bytes):", OUT.stat().st_size)
    print("Ext resources:", ext_count, "Sub resources kept:", sub_count)


if __name__ == "__main__":
    main()
