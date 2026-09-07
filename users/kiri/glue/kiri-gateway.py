#!/usr/bin/env python3
"""
kiri-gateway.py — Always-on Telegram long-polling gateway for Kiri.

Long-polls Telegram Bot API, authenticates users, dispatches to wake_kiri.sh,
manages session files, lock file, and queue.

Dependencies: Python standard library only (urllib, json, threading, subprocess, etc.)
"""

import json
import logging
import os
import signal
import subprocess
import sys
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime
from pathlib import Path

# ─── Paths ────────────────────────────────────────────────────────────────────
HOME = Path("/home/kiri")
GLUE_DIR = HOME / "glue"
SESSION_DIR = HOME / "sessions"
QUEUE_DIR = HOME / "queue"
LOG_DIR = HOME / "logs"
LOCK_DIR = HOME  # lock files live here as .kiri.lock.{chat_id}
CONFIG_FILE = GLUE_DIR / "config.json"
ENV_FILE = HOME / ".env"
GATEWAY_LOG = LOG_DIR / "gateway.log"
GATEWAY_LOG_BACKUP = LOG_DIR / "gateway.log.1"
LOG_MAX_BYTES = 10 * 1024 * 1024  # 10 MB

# ─── Globals ──────────────────────────────────────────────────────────────────
shutdown_event = threading.Event()
last_wake_time: dict[str, float] = {}  # chat_id -> last wake timestamp

# ─── Logging ──────────────────────────────────────────────────────────────────

def setup_logging():
    """Set up logging to file and stderr."""
    LOG_DIR.mkdir(parents=True, exist_ok=True)

    class RotatingFileHandler(logging.FileHandler):
        def emit(self, record):
            # Rotate if oversized
            try:
                if GATEWAY_LOG.exists() and GATEWAY_LOG.stat().st_size > LOG_MAX_BYTES:
                    self.close()
                    if GATEWAY_LOG_BACKUP.exists():
                        GATEWAY_LOG_BACKUP.unlink()
                    GATEWAY_LOG.rename(GATEWAY_LOG_BACKUP)
                    self.baseFilename = str(GATEWAY_LOG)
                    self.stream = self._open()
            except Exception:
                pass
            super().emit(record)

    logger = logging.getLogger("kiri-gateway")
    logger.setLevel(logging.DEBUG)

    fmt = logging.Formatter("[%(asctime)s] %(levelname)s %(message)s", datefmt="%Y-%m-%d %H:%M:%S")

    fh = RotatingFileHandler(str(GATEWAY_LOG), mode="a", encoding="utf-8")
    fh.setFormatter(fmt)
    logger.addHandler(fh)

    sh = logging.StreamHandler(sys.stderr)
    sh.setFormatter(fmt)
    logger.addHandler(sh)

    return logger


log = setup_logging()

# ─── Environment ──────────────────────────────────────────────────────────────

def load_env():
    """Source /home/kiri/.env and set environment variables."""
    if not ENV_FILE.exists():
        log.warning(f".env file not found at {ENV_FILE}")
        return
    with open(ENV_FILE) as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            if "=" in line:
                key, _, val = line.partition("=")
                key = key.strip()
                val = val.strip().strip('"').strip("'")
                os.environ[key] = val


def load_config():
    """Load config.json."""
    with open(CONFIG_FILE) as f:
        return json.load(f)


# ─── Telegram API ─────────────────────────────────────────────────────────────

class TelegramAPI:
    def __init__(self, token: str):
        self.token = token
        self.base = f"https://api.telegram.org/bot{token}"

    def _request(self, method: str, data: dict = None, retries: int = 5) -> dict:
        """Make a Telegram API call with exponential backoff retry."""
        url = f"{self.base}/{method}"
        delay = 1
        last_exc = None

        for attempt in range(retries):
            try:
                if data:
                    encoded = urllib.parse.urlencode(data).encode()
                    req = urllib.request.Request(url, data=encoded)
                else:
                    req = urllib.request.Request(url)

                with urllib.request.urlopen(req, timeout=60) as resp:
                    body = resp.read().decode("utf-8")
                    result = json.loads(body)
                    if not result.get("ok"):
                        log.warning(f"Telegram API error ({method}): {result.get('description', 'unknown')}")
                    return result
            except urllib.error.URLError as e:
                last_exc = e
                if attempt < retries - 1:
                    log.warning(f"Telegram {method} failed (attempt {attempt+1}): {e}. Retrying in {delay}s...")
                    time.sleep(min(delay, 30))
                    delay = min(delay * 2, 30)
            except Exception as e:
                last_exc = e
                log.error(f"Unexpected error calling Telegram {method}: {e}")
                if attempt < retries - 1:
                    time.sleep(min(delay, 30))
                    delay = min(delay * 2, 30)

        log.error(f"Telegram {method} failed after {retries} attempts: {last_exc}")
        return {"ok": False}

    def get_updates(self, offset: int, timeout: int = 30) -> dict:
        """Long-poll for updates."""
        return self._request("getUpdates", {"offset": offset, "timeout": timeout}, retries=3)

    def send_message(self, chat_id, text: str, parse_mode: str = None) -> dict:
        """Send a message, splitting at 4096 chars if needed."""
        results = []
        while text:
            if len(text) <= 4096:
                chunk = text
                text = ""
            else:
                # Try to split at a newline before 4096
                candidate = text[:4096]
                last_nl = candidate.rfind("\n", 2048, 4096)
                if last_nl != -1:
                    chunk = text[:last_nl]
                    text = text[last_nl + 1:]
                else:
                    chunk = text[:4096]
                    text = text[4096:]

            data = {"chat_id": str(chat_id), "text": chunk}
            if parse_mode:
                data["parse_mode"] = parse_mode

            result = self._request("sendMessage", data)
            results.append(result)

            if text:
                time.sleep(0.5)

        return results[-1] if results else {"ok": False}

    def send_chat_action(self, chat_id, action: str = "typing") -> dict:
        return self._request("sendChatAction", {"chat_id": str(chat_id), "action": action})


# ─── Typing Thread ────────────────────────────────────────────────────────────

class TypingThread(threading.Thread):
    """Repeatedly sends 'typing' indicator until stopped."""

    def __init__(self, tg: TelegramAPI, chat_id, interval: int = 4):
        super().__init__(daemon=True)
        self.tg = tg
        self.chat_id = chat_id
        self.interval = interval
        self._stop = threading.Event()

    def run(self):
        while not self._stop.is_set():
            try:
                self.tg.send_chat_action(self.chat_id)
            except Exception as e:
                log.debug(f"Typing indicator error: {e}")
            self._stop.wait(self.interval)

    def stop(self):
        self._stop.set()


# ─── Lock File Utilities ───────────────────────────────────────────────────────

def lock_file(chat_id) -> Path:
    return LOCK_DIR / f".kiri.lock.{chat_id}"


def is_locked(chat_id) -> bool:
    """Return True if a valid per-chat lock file exists with a running PID."""
    lf = lock_file(chat_id)
    if not lf.exists():
        return False
    try:
        pid = int(lf.read_text().strip())
        # Check if process is alive
        os.kill(pid, 0)
        return True
    except (ValueError, ProcessLookupError, PermissionError):
        # Stale lock
        log.warning(f"Removing stale lock file for chat_id={chat_id} (PID no longer running)")
        lf.unlink(missing_ok=True)
        return False


# ─── Session & Queue Utilities ────────────────────────────────────────────────

def session_file(chat_id) -> Path:
    return SESSION_DIR / f"telegram_{chat_id}.txt"


def queue_file(chat_id) -> Path:
    return QUEUE_DIR / f"{chat_id}.txt"


def append_to_session(chat_id, sender: str, text: str):
    """Append a message line to the session file."""
    SESSION_DIR.mkdir(parents=True, exist_ok=True)
    sf = session_file(chat_id)
    ts = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    line = f"[{ts}] {sender}: {text}\n"
    with open(sf, "a", encoding="utf-8") as f:
        f.write(line)


def append_to_queue(chat_id, sender: str, text: str):
    """Append a message to the queue file."""
    QUEUE_DIR.mkdir(parents=True, exist_ok=True)
    qf = queue_file(chat_id)
    ts = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    line = f"[{ts}] {sender}: {text}\n"
    with open(qf, "a", encoding="utf-8") as f:
        f.write(line)


def drain_queue(chat_id) -> str:
    """Read and delete the queue file. Returns queued content or ''."""
    qf = queue_file(chat_id)
    if not qf.exists() or qf.stat().st_size == 0:
        return ""
    content = qf.read_text(encoding="utf-8")
    qf.unlink(missing_ok=True)
    return content


# ─── Wake Kiri ────────────────────────────────────────────────────────────────

def wake_kiri(chat_id, sender_name: str, message: str, wake_type: str = "message") -> tuple[str, int]:
    """
    Run wake_kiri.sh with the given parameters.
    Returns (response_text, exit_code).
    """
    env = os.environ.copy()
    env["CHANNEL_ID"] = str(chat_id)
    env["SENDER_NAME"] = sender_name
    env["MESSAGE"] = message
    env["WAKE_TYPE"] = wake_type
    env["HOME"] = "/home/kiri"

    log.info(f"Waking Kiri: chat_id={chat_id}, sender={sender_name}, type={wake_type}")

    try:
        result = subprocess.run(
            ["/home/kiri/glue/wake_kiri.sh"],
            env=env,
            capture_output=True,
            text=True,
            timeout=600,  # 10 minute max
        )
        if result.returncode != 0:
            log.error(f"wake_kiri.sh exited {result.returncode}: {result.stderr[:500]}")
            return ("sorry, something went wrong waking me up. check ~/logs/ for details", result.returncode)
        response = result.stdout.strip()
        log.info(f"Kiri responded ({len(response)} chars)")
        return (response, 0)
    except subprocess.TimeoutExpired:
        log.error("wake_kiri.sh timed out after 10 minutes")
        return ("sorry, i timed out thinking about that one. try again?", 1)
    except Exception as e:
        log.error(f"Error running wake_kiri.sh: {e}")
        return (f"sorry, something went wrong waking me up. check ~/logs/ for details", 1)


# ─── Dispatch ─────────────────────────────────────────────────────────────────

def dispatch_message(tg: TelegramAPI, chat_id, sender_name: str, message: str, config: dict):
    """
    Full dispatch cycle:
    1. Send typing
    2. Wake Kiri
    3. Send response
    4. Append Kiri's response to session
    5. Drain queue if any
    """
    typing_interval = config.get("telegram", {}).get("typing_interval", 4)
    typer = TypingThread(tg, chat_id, typing_interval)
    typer.start()

    try:
        response, exit_code = wake_kiri(chat_id, sender_name, message)
    finally:
        typer.stop()
        typer.join(timeout=2)

    # Send response
    if response:
        tg.send_message(chat_id, response)
        # Append Kiri's response to session
        append_to_session(chat_id, "kiri", response)
    else:
        log.warning(f"Empty response from wake_kiri.sh for chat_id={chat_id}")

    # Drain queue
    queued = drain_queue(chat_id)
    if queued:
        log.info(f"Processing {len(queued)} chars of queued messages for chat_id={chat_id}")
        # Append queued messages to session
        sf = session_file(chat_id)
        with open(sf, "a", encoding="utf-8") as f:
            f.write(queued)
        # Wake Kiri again for the queued content
        dispatch_message(tg, chat_id, "queue", "[queued messages — see session]", config)


# ─── Command Handlers ─────────────────────────────────────────────────────────

def handle_start(tg: TelegramAPI, chat_id, user_id, user_name: str):
    msg = (
        f"hi! i'm kiri.\n\n"
        f"i don't know you yet — ask aenri to add your telegram ID to my config. "
        f"your ID is: {user_id}\n\n"
        f"(if you're aenri, add {user_id} to allowed_users in ~/glue/config.json)"
    )
    log.info(f"/start from user_id={user_id} name={user_name!r} chat_id={chat_id}")
    tg.send_message(chat_id, msg)


def handle_status(tg: TelegramAPI, chat_id):
    locked = is_locked(chat_id)
    sf = session_file(chat_id)
    size = sf.stat().st_size if sf.exists() else 0
    last_mod = ""
    if sf.exists():
        ts = sf.stat().st_mtime
        last_mod = datetime.fromtimestamp(ts).strftime("%Y-%m-%d %H:%M:%S")

    status = (
        f"status:\n"
        f"• kiri awake: {'yes (busy)' if locked else 'no (available)'}\n"
        f"• session size: {size} bytes\n"
        f"• last activity: {last_mod or 'no session yet'}"
    )
    tg.send_message(chat_id, status)


def handle_newsession(tg: TelegramAPI, chat_id, config: dict):
    log.info(f"/newsession for chat_id={chat_id}")
    sf = session_file(chat_id)
    if not sf.exists() or sf.stat().st_size == 0:
        tg.send_message(chat_id, "no active session to close!")
        return

    tg.send_message(chat_id, "ok, let me read through our conversation and save what matters...")
    typer = TypingThread(tg, chat_id, config.get("telegram", {}).get("typing_interval", 4))
    typer.start()

    try:
        result = subprocess.run(
            ["/home/kiri/glue/newsession.sh", str(chat_id)],
            capture_output=True,
            text=True,
            timeout=300,
        )
        response = result.stdout.strip()
    except Exception as e:
        log.error(f"newsession.sh error: {e}")
        response = "something went wrong during session extraction. the session was not cleared."
    finally:
        typer.stop()
        typer.join(timeout=2)

    tg.send_message(chat_id, response or "session saved and cleared. fresh start!")


def handle_remember(tg: TelegramAPI, chat_id, text: str):
    """Save a memory fragment immediately via memory_store.py."""
    if not text.strip():
        tg.send_message(chat_id, "usage: /remember <text to save>")
        return
    try:
        result = subprocess.run(
            ["python3", "/home/kiri/glue/memory_store.py", "write", text.strip()],
            capture_output=True,
            text=True,
            timeout=30,
        )
        if result.returncode == 0:
            tg.send_message(chat_id, "got it, saved that to memory.")
            log.info(f"Memory saved via /remember: {text[:80]!r}")
        else:
            tg.send_message(chat_id, f"something went wrong saving that. {result.stderr[:200]}")
            log.error(f"/remember failed: {result.stderr}")
    except Exception as e:
        tg.send_message(chat_id, f"something went wrong: {e}")
        log.error(f"/remember exception: {e}")


def handle_ping(tg: TelegramAPI, chat_id):
    tg.send_message(chat_id, "pong!")


# ─── Message Loop ─────────────────────────────────────────────────────────────

def process_update(tg: TelegramAPI, update: dict, config: dict):
    """Process a single Telegram update."""
    message = update.get("message") or update.get("edited_message")
    if not message:
        return  # ignore non-message updates (inline queries, etc.)

    chat_id = message["chat"]["id"]
    user = message.get("from", {})
    user_id = user.get("id")
    user_name = user.get("first_name", "") or user.get("username", "") or str(user_id)
    text = message.get("text", "")

    if not text:
        return  # ignore non-text messages (photos, stickers, etc.)

    allowed_users = config.get("telegram", {}).get("allowed_users", [])
    min_seconds = config.get("rate_limit", {}).get("min_seconds_between_wakes", 5)

    log.info(f"Update: chat_id={chat_id} user_id={user_id} name={user_name!r} text={text[:80]!r}")

    # ── Commands ──────────────────────────────────────────────────────────────
    if text.startswith("/ping"):
        handle_ping(tg, chat_id)
        return

    if text.startswith("/start"):
        handle_start(tg, chat_id, user_id, user_name)
        return

    if text.startswith("/status"):
        handle_status(tg, chat_id)
        return

    if text.startswith("/newsession"):
        if user_id not in allowed_users:
            tg.send_message(chat_id,
                f"hi! i'm kiri. i don't know you yet — ask aenri to add your telegram ID to my config. "
                f"your ID is: {user_id}")
            return
        handle_newsession(tg, chat_id, config)
        return

    if text.startswith("/remember"):
        if user_id not in allowed_users:
            tg.send_message(chat_id,
                f"hi! i'm kiri. i don't know you yet — ask aenri to add your telegram ID to my config. "
                f"your ID is: {user_id}")
            return
        remember_text = text[len("/remember"):].strip()
        handle_remember(tg, chat_id, remember_text)
        return

    # ── Auth check ────────────────────────────────────────────────────────────
    if user_id not in allowed_users:
        tg.send_message(chat_id,
            f"hi! i'm kiri. i don't know you yet — ask aenri to add your telegram ID to my config. "
            f"your ID is: {user_id}")
        return

    # ── Append to session ─────────────────────────────────────────────────────
    append_to_session(chat_id, user_name, text)

    # ── Rate limit ────────────────────────────────────────────────────────────
    now = time.time()
    last = last_wake_time.get(str(chat_id), 0)
    if now - last < min_seconds:
        log.info(f"Rate limiting wake for chat_id={chat_id}")
        time.sleep(min_seconds - (now - last))

    # ── Lock check ────────────────────────────────────────────────────────────
    if is_locked(chat_id):
        qf = queue_file(chat_id)
        # Only send the "i'm busy" message once per queue buildup
        already_queued = qf.exists() and qf.stat().st_size > 0
        append_to_queue(chat_id, user_name, text)
        if not already_queued:
            tg.send_message(chat_id, "i'm thinking about something else rn, one sec!")
        log.info(f"Queued message for chat_id={chat_id} (Kiri is locked)")
        return

    # ── Dispatch ──────────────────────────────────────────────────────────────
    last_wake_time[str(chat_id)] = time.time()

    # Run dispatch in a thread so we can process other updates
    t = threading.Thread(
        target=dispatch_message,
        args=(tg, chat_id, user_name, text, config),
        daemon=True,
    )
    t.start()


# ─── Main Loop ────────────────────────────────────────────────────────────────

def main():
    # Load env + config
    load_env()

    token = os.environ.get("KIRI_BOT_TOKEN", "")
    if not token:
        log.error("KIRI_BOT_TOKEN not set. Cannot start gateway.")
        sys.exit(1)

    config = load_config()
    poll_timeout = config.get("telegram", {}).get("poll_timeout", 30)

    tg = TelegramAPI(token)

    log.info("=" * 60)
    log.info("kiri-gateway starting up")
    log.info(f"Config loaded from {CONFIG_FILE}")
    log.info(f"Allowed users: {config.get('telegram', {}).get('allowed_users', [])}")
    log.info("Beginning long-poll loop...")

    # Signal handlers
    def _shutdown(signum, frame):
        log.info(f"Received signal {signum}, shutting down...")
        shutdown_event.set()

    signal.signal(signal.SIGTERM, _shutdown)
    signal.signal(signal.SIGINT, _shutdown)

    offset = 0

    while not shutdown_event.is_set():
        try:
            # Reload config on each iteration (allows live updates to allowed_users)
            try:
                config = load_config()
            except Exception as e:
                log.warning(f"Failed to reload config: {e}")

            result = tg.get_updates(offset=offset, timeout=poll_timeout)

            if not result.get("ok"):
                log.warning(f"getUpdates not ok: {result}")
                time.sleep(5)
                continue

            updates = result.get("result", [])
            for update in updates:
                update_id = update.get("update_id", 0)
                offset = max(offset, update_id + 1)

                try:
                    process_update(tg, update, config)
                except Exception as e:
                    log.error(f"Error processing update {update_id}: {e}", exc_info=True)

        except Exception as e:
            if not shutdown_event.is_set():
                log.error(f"Error in main poll loop: {e}", exc_info=True)
                time.sleep(5)

    log.info("kiri-gateway shut down cleanly.")


if __name__ == "__main__":
    main()
