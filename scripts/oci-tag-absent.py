#!/usr/bin/env python3
"""Fail closed before wkg publication; wkg cannot reject existing OCI tags."""
import base64
import json
import os
import sys
from urllib.error import HTTPError
from urllib.parse import urlencode
from urllib.request import Request, urlopen

reference = sys.argv[1]
registry, package = reference.split("/", 1)
repository, tag = package.rsplit(":", 1)
if registry != "ghcr.io" or not tag:
    raise SystemExit("Expected a versioned ghcr.io OCI reference")
credentials = base64.b64encode((os.environ["GITHUB_ACTOR"] + ":" + os.environ["GH_TOKEN"]).encode()).decode()
query = urlencode({"service": registry, "scope": f"repository:{repository}:pull"})
request = Request(f"https://{registry}/token?{query}", headers={"Authorization": "Basic " + credentials})
with urlopen(request, timeout=30) as response:
    token = json.load(response)["token"]
request = Request(f"https://{registry}/v2/{repository}/manifests/{tag}", headers={
    "Authorization": "Bearer " + token,
    "Accept": "application/vnd.oci.image.manifest.v1+json, application/vnd.oci.image.index.v1+json",
})
try:
    with urlopen(request, timeout=30):
        raise SystemExit("Refusing to overwrite existing OCI tag: " + reference)
except HTTPError as error:
    if error.code != 404:
        raise
    body = json.load(error)
    codes = {item["code"] for item in body["errors"]}
    if not codes or not codes.issubset({"MANIFEST_UNKNOWN", "NAME_UNKNOWN"}):
        raise SystemExit("Registry did not confirm that the tag is absent")
print("OCI tag is absent: " + reference)
