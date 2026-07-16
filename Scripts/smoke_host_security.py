#!/usr/bin/env python3
"""Route-level security smoke for VeqralHost.

Uses an isolated Host home, file-backed test secret store, and dynamic port. It
never opens or mutates the user's login Keychain and never executes the high-risk
fixture run.
"""
import base64
import datetime as dt
import hashlib
import hmac
import json
import os
from pathlib import Path
import socket
import stat
import subprocess
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid

ROOT = Path(__file__).resolve().parents[1]
BINARY = ROOT / "MacHost/.build/debug/VeqralHost"


def request(url, method="GET", payload=None, headers=None):
    body = b"" if payload is None else json.dumps(payload, separators=(",", ":")).encode()
    req = urllib.request.Request(url, data=body if method != "GET" else None, method=method)
    req.add_header("Content-Type", "application/json")
    for key, value in (headers or {}).items():
        req.add_header(key, value)
    try:
        with urllib.request.urlopen(req, timeout=8) as response:
            raw = response.read()
            return response.status, json.loads(raw) if raw else {}
    except urllib.error.HTTPError as exc:
        raw = exc.read()
        return exc.code, json.loads(raw) if raw else {}


def auth_headers(device, token, method, path, payload, nonce=None):
    timestamp = dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")
    body = b"" if payload is None else json.dumps(payload, separators=(",", ":")).encode()
    body_hash = hashlib.sha256(body).hexdigest()
    canonical = "\n".join([
        "VEQRAL-REQUEST-AUTH",
        "2",
        device,
        method.upper(),
        path,
        timestamp,
        nonce or "",
        body_hash,
    ])
    signature = base64.b64encode(hmac.new(token.encode(), canonical.encode(), hashlib.sha256).digest()).decode()
    headers = {
        "X-Veqral-Auth-Version": "2",
        "X-Veqral-Device": device,
        "X-Veqral-Timestamp": timestamp,
        "X-Veqral-Signature": signature,
    }
    if nonce:
        headers["X-Veqral-Nonce"] = nonce
    return headers


def unique_nonce(label):
    return f"security-smoke-{label}-{uuid.uuid4()}"


def main():
    if not BINARY.exists():
        raise SystemExit(f"Build VeqralHost first: missing {BINARY}")

    host = None
    device = None
    token = None
    base = None
    try:
        with socket.socket() as sock:
            sock.bind(("127.0.0.1", 0))
            port = sock.getsockname()[1]
        with tempfile.TemporaryDirectory(prefix="veqral-security-host-") as home:
            secret_store = Path(home) / "test-secrets.json"
            env = os.environ.copy()
            env.update({
                "VEQRAL_HOST_HOME": home,
                "VEQRAL_HOST_PORT": str(port),
                "VEQRAL_HOST_WORKING_DIRECTORY": str(ROOT),
                "VEQRAL_TEST_MODE": "1",
                "VEQRAL_TEST_SECRET_STORE_PATH": str(secret_store),
                "VEQRAL_DISABLE_DISCORD_WEBHOOK": "1",
                "VEQRAL_PUSH_ENABLED": "0",
            })
            host = subprocess.Popen([str(BINARY)], env=env, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
            base = f"http://127.0.0.1:{port}"
            for _ in range(100):
                try:
                    status, pairing = request(base + "/v1/pairing")
                    if status == 200:
                        break
                except Exception:
                    pass
                time.sleep(0.1)
            else:
                raise AssertionError("isolated Host did not become ready")

            params = urllib.parse.parse_qs(urllib.parse.urlparse(pairing["pairingURL"]).query)
            code, endpoint, pair_signature = (params[key][0] for key in ("code", "endpoint", "signature"))
            candidates = params["candidate"]
            auth_versions = [int(value) for value in params["auth"]]
            capabilities = params["cap"]
            proof = params["proof"][0]

            status, error = request(base + "/v1/pair", "POST", {"deviceName": "security-smoke", "pairingCode": code})
            assert status == 401 and "Signed pairing URL" in error.get("error", ""), (status, error)

            pair_body = {
                "deviceName": "security-smoke",
                "pairingCode": code,
                "pairingEndpoint": endpoint,
                "pairingSignature": pair_signature,
                "clientStableID": "security-smoke-client",
                "pairingProtocolVersion": 2,
                "apiProtocolVersion": 2,
                "requestAuthVersions": auth_versions,
                "capabilities": capabilities,
                "pairingEndpoints": candidates,
                "pairingProof": proof,
                "selectedEndpoint": candidates[0],
            }
            tampered = dict(pair_body)
            tampered["pairingEndpoints"] = candidates + ["http://127.0.0.1:65534"]
            status, error = request(base + "/v1/pair", "POST", tampered)
            assert status == 401 and "proof" in error.get("error", "").lower(), (status, error)

            status, paired = request(base + "/v1/pair", "POST", pair_body)
            assert status == 200 and paired.get("minimumAuthVersion") == 2, (status, paired)
            device, token = paired["deviceID"], paired["token"]

            missing_path = "/v1/runs/does-not-exist/input"
            missing_body = {"text": "safe-smoke", "submit": True}
            status, error = request(base + missing_path, "POST", missing_body,
                                    auth_headers(device, token, "POST", missing_path, missing_body))
            assert status == 401 and "nonce" in error.get("error", "").lower(), (status, error)

            replay_nonce = unique_nonce("replay")
            replay_headers = auth_headers(device, token, "POST", missing_path, missing_body, replay_nonce)
            status, error = request(base + missing_path, "POST", missing_body, replay_headers)
            assert status == 404 and error.get("error") == "Run not found", (status, error)
            status, error = request(base + missing_path, "POST", missing_body, replay_headers)
            assert status == 401 and error.get("error") == "Replayed request", (status, error)

            host.terminate()
            host.wait(timeout=5)
            host = subprocess.Popen([str(BINARY)], env=env, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
            for _ in range(100):
                try:
                    status, health = request(base + "/v1/health")
                    if status == 200 and health.get("status") == "ok":
                        break
                except Exception:
                    pass
                time.sleep(0.1)
            else:
                raise AssertionError("isolated Host did not restart")
            status, error = request(base + missing_path, "POST", missing_body, replay_headers)
            assert status == 401 and error.get("error") == "Replayed request", (status, error)

            create_path = "/v1/runs"
            create_body = {
                "prompt": "printf '%s\\n' 'rm -rf /tmp/veqral-security-smoke-never-execute'",
                "workingDirectory": str(ROOT),
                "engine": "shell",
            }
            status, created = request(base + create_path, "POST", create_body,
                                      auth_headers(device, token, "POST", create_path, create_body, unique_nonce("create")))
            assert status == 200 and created.get("approvalRequired") is True, (status, created)
            run_id = created["runID"]

            resume_path = f"/v1/runs/{run_id}/resume"
            status, error = request(base + resume_path, "POST", None,
                                    auth_headers(device, token, "POST", resume_path, None, unique_nonce("resume")))
            assert status == 409 and "explicit approval" in error.get("error", ""), (status, error)

            snapshot_path = f"/v1/runs/{run_id}"
            status, snapshot = request(base + snapshot_path, "GET", None,
                                       auth_headers(device, token, "GET", snapshot_path, None))
            assert status == 200 and snapshot["run"]["status"] == "waitingApproval", (status, snapshot)

            cancel_path = f"/v1/runs/{run_id}/cancel"
            status, result = request(base + cancel_path, "POST", None,
                                     auth_headers(device, token, "POST", cancel_path, None, unique_nonce("cancel")))
            assert status == 200 and result.get("ok") is True, (status, result)

            status, snapshot = request(base + snapshot_path, "GET", None,
                                       auth_headers(device, token, "GET", snapshot_path, None))
            assert status == 200 and snapshot["run"]["status"] == "cancelled", (status, snapshot)

            status, error = request(base + resume_path, "POST", None,
                                    auth_headers(device, token, "POST", resume_path, None, unique_nonce("cancel-resume")))
            assert status == 409 and "explicit approval" in error.get("error", ""), (status, error)

            status, snapshot = request(base + snapshot_path, "GET", None,
                                       auth_headers(device, token, "GET", snapshot_path, None))
            assert status == 200 and snapshot["run"]["status"] == "waitingApproval", (status, snapshot)
            assert snapshot["run"]["approvalProvenance"]["state"] == "pending", snapshot

            approve_path = f"/v1/runs/{run_id}/approve"
            status, result = request(base + approve_path, "POST", None,
                                     auth_headers(device, token, "POST", approve_path, None, unique_nonce("approve")))
            assert status == 200 and result.get("ok") is True, (status, result)
            for _ in range(60):
                status, snapshot = request(base + snapshot_path, "GET", None,
                                           auth_headers(device, token, "GET", snapshot_path, None))
                if status == 200 and snapshot["run"]["status"] in {"complete", "failed"}:
                    break
                time.sleep(0.1)
            provenance = snapshot["run"].get("approvalProvenance") or {}
            assert snapshot["run"]["status"] == "complete", snapshot
            assert provenance.get("state") == "granted", provenance
            assert provenance.get("grantedByDeviceID") == device, provenance
            assert provenance.get("grantedAt"), provenance

            revoke_path = f"/v1/devices/{device}/revoke"
            status, result = request(base + revoke_path, "POST", None,
                                     auth_headers(device, token, "POST", revoke_path, None, unique_nonce("revoke")))
            assert status == 200 and result.get("ok") is True, (status, result)
            device = None
            token = None

            assert secret_store.is_file(), secret_store
            assert stat.S_IMODE(secret_store.stat().st_mode) == 0o600, oct(stat.S_IMODE(secret_store.stat().st_mode))
            assert secret_store.resolve().is_relative_to(Path(home).resolve()), secret_store

            print("PASS: security guards signed-pair=1 nonce=1 replay=1 restart-replay=1 approval-resume-bypass=0 cancel-resume-bypass=0 isolated-secret-store=1 cleanup=1")
    finally:
        if base is not None and device is not None and token is not None:
            revoke_path = f"/v1/devices/{device}/revoke"
            try:
                request(base + revoke_path, "POST", None,
                        auth_headers(device, token, "POST", revoke_path, None, unique_nonce("cleanup")))
            except Exception:
                pass
        if host is not None:
            host.terminate()
            try:
                host.wait(timeout=5)
            except subprocess.TimeoutExpired:
                host.kill()



if __name__ == "__main__":
    main()
