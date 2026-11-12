"""Serve the dashboard page and the reviewer's state files on localhost only."""
import http.server
import os
import pathlib
import subprocess

HERE = pathlib.Path(__file__).resolve().parent
STATE = pathlib.Path(os.environ.get("STATE_DIR", pathlib.Path.home() / ".local/state/pr-autoreview"))
PORT = int(os.environ.get("DASHBOARD_PORT", "8787"))
FILES = {
    "/": (HERE / "index.html", "text/html; charset=utf-8"),
    "/status.json": (STATE / "status.json", "application/json"),
    "/events.jsonl": (STATE / "events.jsonl", "text/plain; charset=utf-8"),
}


class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        path, ctype = FILES.get(self.path.split("?")[0], (None, None))
        if path is None:
            return self.send_error(404)
        body = path.read_bytes() if path.exists() else b""
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
