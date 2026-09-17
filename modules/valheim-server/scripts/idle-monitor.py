#!/usr/bin/env python3
"""
Idle monitor for the Valheim server VM.

Runs as a systemd oneshot service (triggered by a timer) roughly every 5
minutes. Queries the local Valheim server via the Steam A2S_INFO protocol
for the current player count. If nobody has been connected for
IDLE_TIMEOUT_MINUTES, it gracefully stops the game container (which saves
the world), syncs the world save to Cloud Storage, and shuts down the
guest OS - GCE detects this and stops the instance, so no
compute.instances.stop IAM permission is ever needed by this VM.
"""
import os
import socket
import subprocess
import sys
import time
from typing import Optional

STATE_FILE = "/opt/valheim/last_active"
QUERY_HOST = "127.0.0.1"
QUERY_PORT = int(os.environ.get("QUERY_PORT", "2457"))
CONTAINER_NAME = os.environ.get("CONTAINER_NAME", "valheim")
WORLD_DIR = os.environ.get("WORLD_DIR", "/opt/valheim/config/worlds_local")
BACKUP_BUCKET = os.environ.get("BACKUP_BUCKET")
IDLE_TIMEOUT_MINUTES = float(os.environ.get("IDLE_TIMEOUT_MINUTES", "30"))

A2S_INFO_REQUEST = b"\xFF\xFF\xFF\xFF" + b"TSource Engine Query\x00"


def log(msg: str) -> None:
    print(f"[idle-monitor] {time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())} {msg}", flush=True)


def query_player_count(timeout: float = 5.0) -> Optional[int]:
    """Returns the current player count via Steam A2S_INFO, or None if the
    server didn't respond (e.g. still starting up)."""
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
            sock.settimeout(timeout)
            sock.sendto(A2S_INFO_REQUEST, (QUERY_HOST, QUERY_PORT))
            data, _ = sock.recvfrom(4096)

            kind = data[4:5]
            if kind == b"A":
                # Server wants a challenge round-trip (post-2020 A2S_INFO).
                challenge = data[5:9]
                sock.sendto(A2S_INFO_REQUEST + challenge, (QUERY_HOST, QUERY_PORT))
                data, _ = sock.recvfrom(4096)
                kind = data[4:5]

            if kind != b"I":
                log(f"unexpected A2S response type {kind!r}")
                return None

            payload = data[5:]
            # Skip: byte protocol, then 4 null-terminated strings (name,
            # map, folder, game), then a short appid.
            idx = 1
            for _ in range(4):
                end = payload.index(b"\x00", idx)
                idx = end + 1
            idx += 2
            return payload[idx]
    except (socket.timeout, OSError, ValueError, IndexError) as exc:
        log(f"A2S query failed: {exc}")
        return None


def read_last_active() -> Optional[float]:
    try:
        with open(STATE_FILE) as f:
            return float(f.read().strip())
    except (FileNotFoundError, ValueError):
        return None


def write_last_active(ts: float) -> None:
    with open(STATE_FILE, "w") as f:
        f.write(str(ts))


def shut_down() -> None:
    log(f"idle timeout reached ({IDLE_TIMEOUT_MINUTES} min) - stopping container, backing up world, shutting down")

    subprocess.run(["docker", "stop", "-t", "60", CONTAINER_NAME], check=False)

    if BACKUP_BUCKET:
        dest = f"gs://{BACKUP_BUCKET}/worlds_local"
        log(f"syncing {WORLD_DIR} -> {dest}")
        result = subprocess.run(
            ["gcloud", "storage", "rsync", "-r", WORLD_DIR, dest],
            capture_output=True, text=True,
        )
        if result.returncode != 0:
            log(f"WARNING: world backup failed, shutting down anyway: {result.stderr.strip()}")
        else:
            log("world backup complete")
    else:
        log("WARNING: BACKUP_BUCKET not set, skipping backup")

    log("shutting down guest OS (GCE will report the instance as stopped)")
    subprocess.run(["shutdown", "-h", "now"], check=False)


def main() -> None:
    now = time.time()
    players = query_player_count()

    if players is None:
        log("no A2S response (server may still be starting) - skipping this check")
        return

    log(f"players connected: {players}")

    if players > 0:
        write_last_active(now)
        return

    last_active = read_last_active()
    if last_active is None:
        # First run with nobody connected yet - start the idle clock now
        # rather than assuming it's already been idle forever.
        log("no prior activity timestamp - starting idle clock now")
        write_last_active(now)
        return

    idle_minutes = (now - last_active) / 60
    log(f"idle for {idle_minutes:.1f} minutes (threshold {IDLE_TIMEOUT_MINUTES})")

    if idle_minutes >= IDLE_TIMEOUT_MINUTES:
        shut_down()


if __name__ == "__main__":
    sys.exit(main())
