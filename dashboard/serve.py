"""Serve the dashboard page and the reviewer's state files on localhost only."""
import http.server
import os
import pathlib
import shlex
import subprocess

HERE = pathlib.Path(__file__).resolve().parent
STATE = pathlib.Path(os.environ.get("STATE_DIR", pathlib.Path.home() / ".local/state/pr-autoreview"))
PORT = int(os.environ.get("DASHBOARD_PORT", "8787"))
FILES = {
    "/": (HERE / "index.html", "text/html; charset=utf-8"),
    "/status.json": (STATE / "status.json", "application/json"),
    "/events.jsonl": (None, "text/plain; charset=utf-8"),
}
MYSQL = ["mysql", *shlex.split(os.environ.get("MYSQL_ARGS", "-uroot")), "-N", "-B", "-r", "pr_autoreview"]


def events_jsonl():
    """Every event as one JSON line, oldest first, the format index.html reads."""
    return subprocess.run([*MYSQL, "-e", "SELECT data FROM events ORDER BY id"],
                          capture_output=True, check=True).stdout


class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        route = self.path.split("?")[0]
        if route not in FILES:
            return self.send_error(404)
        path, ctype = FILES[route]
        try:
            body = events_jsonl() if path is None else path.read_bytes() if path.exists() else b""
        except subprocess.CalledProcessError as e:
            print(f"mysql failed: {e.stderr.decode()[:300]}", flush=True)
            return self.send_error(503, "MySQL unavailable")
        self.send_response(200)
        self.send_header("Content-Type", ctype)
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def do_POST(self):
        # Only accept same-origin requests so other sites can't trigger runs.
        origin = self.headers.get("Origin", "")
        if self.path != "/run" or origin not in (f"http://localhost:{PORT}", f"http://127.0.0.1:{PORT}"):
            return self.send_error(403)
        uid = os.getuid()
        ok = subprocess.run(["launchctl", "kickstart", f"gui/{uid}/local.pr-autoreview"]).returncode == 0
        self.send_response(204 if ok else 500)
        self.end_headers()

    def log_message(self, *args):
        pass


if __name__ == "__main__":
    print(f"pr-autoreview dashboard on http://localhost:{PORT}", flush=True)
    http.server.ThreadingHTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
