#!/usr/bin/env python3
"""Load / list / delete the transformation-example dashboards via the Grafana API.

Usage:  python3 apply.py {load|list|delete}
Env:    GRAFANA_URL  (default http://localhost:13000)
        GRAFANA_AUTH (default admin:admin, "user:pass" — or a "Bearer <token>")
"""
import base64, glob, json, os, sys, urllib.request, urllib.error

URL = os.environ.get("GRAFANA_URL", "http://localhost:13000").rstrip("/")
AUTH = os.environ.get("GRAFANA_AUTH", "admin:admin")
HERE = os.path.dirname(os.path.abspath(__file__))

def hdr():
    h = {"Content-Type": "application/json"}
    if AUTH.lower().startswith("bearer "):
        h["Authorization"] = AUTH
    else:
        h["Authorization"] = "Basic " + base64.b64encode(AUTH.encode()).decode()
    return h

def call(method, path, body=None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(URL + path, data=data, headers=hdr(), method=method)
    try:
        return json.load(urllib.request.urlopen(req, timeout=25))
    except urllib.error.HTTPError as e:
        return {"_http": e.code, "_body": e.read().decode()[:200]}

def load():
    ok = fail = 0
    for fn in sorted(glob.glob(os.path.join(HERE, "dashboards", "*.json"))):
        d = json.load(open(fn)); d.pop("id", None)
        r = call("POST", "/api/dashboards/db", {"dashboard": d, "overwrite": True})
        if r.get("status") == "success":
            print(f"  loaded {r['uid']:22} {os.path.basename(fn)}"); ok += 1
        else:
            print(f"  FAILED {os.path.basename(fn)}: {r}"); fail += 1
    print(f"\n{ok} loaded, {fail} failed  ->  {URL}")

def listing():
    r = call("GET", "/api/search?tag=transformations")
    if isinstance(r, list):
        for x in r:
            print(f"  {x['uid']:22} {x['title']}")
        print(f"\n{len(r)} transformation dashboards on {URL}")
    else:
        print(r)

def delete():
    n = 0
    for fn in sorted(glob.glob(os.path.join(HERE, "dashboards", "*.json"))):
        uid = json.load(open(fn))["uid"]
        r = call("DELETE", f"/api/dashboards/uid/{uid}")
        print(f"  deleted {uid}: {r.get('message', r)}"); n += 1
    print(f"\n{n} removed from {URL}")

if __name__ == "__main__":
    action = sys.argv[1] if len(sys.argv) > 1 else "load"
    {"load": load, "list": listing, "delete": delete}.get(action, load)()
