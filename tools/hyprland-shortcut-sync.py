from __future__ import annotations

import json
import os
import subprocess
import sys
import time

KEY = os.environ["KIMI_SHORTCUT_KEY"]
HYPRCTL = os.environ["HYPRCTL"]
APP_TAG = "kimi-desktop:"
POLL_SECONDS = 1
MODIFIERS = {
    "SHIFT": 1,
    "CAPS": 2,
    "CTRL": 4,
    "ALT": 8,
    "MOD2": 16,
    "MOD3": 32,
    "SUPER": 64,
    "MOD5": 128,
}


def hyprctl(*args: str) -> str:
    result = subprocess.run(
        [HYPRCTL, *args],
        check=False,
        capture_output=True,
        text=True,
        timeout=10,
    )
    if result.returncode != 0:
        raise RuntimeError(f"hyprctl {' '.join(args)}: {result.stderr.strip()}")
    return result.stdout


def registered_ids() -> list[str]:
    out = hyprctl("globalshortcuts")
    return [
        line.split("->", 1)[0].strip().removeprefix(APP_TAG)
        for line in out.splitlines()
        if line.startswith(APP_TAG)
    ]


def shortcut() -> tuple[int, str]:
    modifiers, separator, key = KEY.rpartition(",")
    if not separator:
        modifiers, key = "", KEY
    modmask = 0
    for modifier in modifiers.split("_"):
        if not modifier:
            continue
        try:
            modmask |= MODIFIERS[modifier.upper()]
        except KeyError as error:
            raise RuntimeError(f"unsupported modifier: {modifier}") from error
    if not key.strip():
        raise RuntimeError("shortcut key is empty")
    return modmask, key.strip()


def modifier_names(modmask: int) -> str:
    names = [name for name, bit in MODIFIERS.items() if modmask & bit]
    if sum(MODIFIERS.values()) & modmask != modmask:
        raise RuntimeError(f"unsupported modmask: {modmask}")
    return "_".join(names)


def is_managed(bind: dict) -> bool:
    return bind.get("dispatcher") == "global" and bind.get("arg", "").startswith(
        APP_TAG
    )


def combo(bind: dict) -> tuple[int, str]:
    return bind["modmask"], bind["key"]


def unbind(modmask: int, key: str) -> None:
    hyprctl("keyword", "unbind", f"{modifier_names(modmask)}, {key}")


def sync() -> list[str] | None:
    modmask, key = shortcut()
    wanted_ids = registered_ids()[-1:]
    binds = json.loads(hyprctl("-j", "binds"))
    managed = [bind for bind in binds if is_managed(bind)]
    wanted = (
        {
            "modmask": modmask,
            "key": key,
            "dispatcher": "global",
            "arg": f"{APP_TAG}{wanted_ids[0]}",
        }
        if wanted_ids
        else None
    )
    if (
        wanted is not None
        and len(managed) == 1
        and combo(managed[0]) == combo(wanted)
        and managed[0].get("arg") == wanted["arg"]
    ):
        return None
    if wanted is None and not managed:
        return None

    combos = {combo(bind) for bind in managed}
    if wanted is not None:
        combos.add(combo(wanted))
    for bind in binds:
        if combo(bind) in combos and not is_managed(bind):
            raise RuntimeError(
                f"shortcut conflict: {modifier_names(combo(bind)[0])}, {combo(bind)[1]}"
            )

    for old_combo in {combo(bind) for bind in managed}:
        unbind(*old_combo)
    if wanted is not None:
        hyprctl(
            "keyword",
            "bind",
            f"{modifier_names(modmask)}, {key}, global, {wanted['arg']}",
        )
    return wanted_ids


def log(message: str) -> None:
    print(f"{time.strftime('%Y-%m-%dT%H:%M:%S%z')} {message}", flush=True)


def main() -> None:
    log(f"daemon start (key={KEY})")
    while True:
        try:
            synced = sync()
            if synced is not None:
                log(f"bind synced: {synced}")
        except (RuntimeError, subprocess.TimeoutExpired, json.JSONDecodeError) as error:
            log(f"sync failed: {error}")
        time.sleep(POLL_SECONDS)


if __name__ == "__main__":
    if not KEY:
        sys.exit("KIMI_SHORTCUT_KEY is empty")
    main()
