"""Read-only public API preflight; never accepts keys or fetches catalog/media.

Usage: python tools/probe_metadata_apis.py [--local-stash]
Checks documentation availability and the deployed StashDB query contract.
A pass does NOT verify registration, credentials, search results or playback.
"""
import argparse
import datetime
import json
import urllib.error
import urllib.request

MAX_BYTES = 2 * 1024 * 1024
CATALOG_CONTRACT = r"""query CatalogContract($term:String!){
  searchScene(term:$term,limit:20) @skip(if:true){
    id title release_date deleted studio{name} performers{performer{name}}
  }
}"""


def request_json(url, payload=None):
    data = None if payload is None else json.dumps(payload).encode()
    request = urllib.request.Request(url, data=data, headers={
        "Accept": "application/json", "Content-Type": "application/json",
        "User-Agent": "Zanzibarr-public-contract-preflight/1.26",
    })
    with urllib.request.urlopen(request, timeout=15) as response:
        body = response.read(MAX_BYTES + 1)
        if len(body) > MAX_BYTES:
            raise ValueError("Response exceeds bound")
        return response.status, json.loads(body)


def checked(name, operation):
    try:
        return {"check": name, **operation()}
    except urllib.error.HTTPError as error:
        return {"check": name, "passed": False, "status": error.code}
    except (urllib.error.URLError, TimeoutError, OSError):
        return {"check": name, "passed": False, "failure": "connection_or_tls"}
    except (ValueError, TypeError, KeyError, AttributeError):
        return {"check": name, "passed": False, "failure": "unexpected_response"}


def tpdb_contract():
    status, body = request_json("https://api.theporndb.net/specs?openapi.json")
    routes = body.get("paths", {})
    return {"passed": all("get" in routes.get(route, {}) for route in ("/scenes", "/movies")),
            "status": status, "specVersion": body.get("info", {}).get("version")}


def stashdb_contract():
    # Validation runs before directives. The skipped field never resolves and
    # therefore fetches no scene data, even if the server permits public reads.
    status, body = request_json("https://stashdb.org/graphql", {
        "query": CATALOG_CONTRACT, "variables": {"term": "contract-check"},
    })
    return {"passed": body.get("data") == {} and not body.get("errors"),
            "status": status, "graphqlErrors": len(body.get("errors", []))}


def local_stash_transport():
    status, body = request_json("http://127.0.0.1:9999/graphql", {
        "query": "query { __typename }",
    })
    return {"passed": bool(body.get("data")) and not body.get("errors"), "status": status}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--local-stash", action="store_true",
                        help="Also probe the default loopback Stash endpoint (no credentials).")
    args = parser.parse_args()
    checks = [checked("tpdb_public_contract", tpdb_contract),
              checked("stashdb_deployed_contract", stashdb_contract)]
    if args.local_stash:
        checks.append(checked("optional_local_stash_transport", local_stash_transport))
    print(json.dumps({"checkedAt": datetime.datetime.now(datetime.timezone.utc).isoformat(),
                      "scope": "public_contract_only_not_authenticated_search_or_playback",
                      "checks": checks}, indent=2))
    # A missing optional local server is not a hosted-provider outage.
    return 0 if all(check["passed"] for check in checks[:2]) else 1


if __name__ == "__main__":
    raise SystemExit(main())
