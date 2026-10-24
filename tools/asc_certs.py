"""Prints the distribution certificates of the developer account, as the App filing (工信部 App 备案) asks for them:
the public key (the RSA modulus, in hex, as Keychain shows it) and the SHA-1 fingerprint, plus the serial and expiry.
Reads the App Store Connect API key from the environment (ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_P8) and writes GitHub
notices. Usage (CI): python3 tools/asc_certs.py
"""
import base64, json, os, subprocess, sys, tempfile, time, urllib.request
import jwt  # PyJWT, with cryptography

kid, iss, p8 = os.environ["ASC_KEY_ID"], os.environ["ASC_ISSUER_ID"], os.environ["ASC_KEY_P8"]
token = jwt.encode({"iss": iss, "iat": int(time.time()), "exp": int(time.time()) + 600, "aud": "appstoreconnect-v1"}, p8,
                   algorithm="ES256", headers={"kid": kid, "typ": "JWT"})
req = urllib.request.Request("https://api.appstoreconnect.apple.com/v1/certificates?limit=50", headers={"Authorization": f"Bearer {token}"})
try:
    data = json.load(urllib.request.urlopen(req))["data"]
except Exception as e:
    print(f"::warning title=备案证书::could not list certificates ({e})"); sys.exit(0)
shown = 0
for c in data:
    a = c["attributes"]
    if a.get("certificateType") not in ("DISTRIBUTION", "IOS_DISTRIBUTION") or not a.get("certificateContent"):
        continue
    der = base64.b64decode(a["certificateContent"])
    with tempfile.NamedTemporaryFile(suffix=".cer", delete=False) as f: f.write(der); path = f.name
    run = lambda *x: subprocess.run(["openssl", "x509", "-inform", "der", "-in", path, "-noout", *x], capture_output=True, text=True).stdout.strip()
    sha1 = run("-fingerprint", "-sha1").split("=", 1)[-1]
    modulus = run("-modulus").split("=", 1)[-1]
    name = a.get("displayName") or a.get("name") or ""
    print(f"::notice title=备案证书 {name} · 到期 {a.get('expirationDate', '')[:10]}::SHA-1 {sha1}")
    print(f"::notice title=备案证书 {name} · 公钥（RSA 模数，十六进制）::{modulus}")
    shown += 1
if not shown:
    print("::warning title=备案证书::no distribution certificate with downloadable content was listed (a cloud-managed certificate may not be exposed); create an Apple Distribution certificate in the developer portal")
