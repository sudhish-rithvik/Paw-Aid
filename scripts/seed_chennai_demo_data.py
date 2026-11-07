#!/usr/bin/env python3
"""
PAW AID - Cloud Firestore Demo Seeder for Chennai
Seeds:
- 2 NGOs (South Chennai & North Chennai)
- 2 Citizens (Karthik Raman & Priya Sundaram)
- 4 Animal Distress Cases with 100% cloud-stored Base64 images and complete injury descriptions
"""

import os
import io
import json
import base64
import urllib.request
import urllib.error
from PIL import Image

import os
import sys

# Load API key securely from environment variable or command line argument
API_KEY = os.environ.get("FIREBASE_API_KEY") or (sys.argv[1] if len(sys.argv) > 1 else "")
PROJECT_ID = "paw-aid-app"
IMAGES_DIR = r"C:\Users\Rithu\Downloads\sample data"

def get_auth_token(email, password, create_if_missing=True):
    auth_url = f"https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key={API_KEY}"
    payload = {"email": email, "password": password, "returnSecureToken": True}
    req = urllib.request.Request(auth_url, data=json.dumps(payload).encode("utf-8"), headers={"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            return data["idToken"], data["localId"]
    except urllib.error.HTTPError as e:
        err = json.loads(e.read().decode("utf-8"))
        code = err.get("error", {}).get("message", "")
        if "EMAIL_NOT_FOUND" in code or "INVALID_LOGIN_CREDENTIALS" in code:
            if create_if_missing:
                signup_url = f"https://identitytoolkit.googleapis.com/v1/accounts:signUp?key={API_KEY}"
                s_req = urllib.request.Request(signup_url, data=json.dumps(payload).encode("utf-8"), headers={"Content-Type": "application/json"})
                with urllib.request.urlopen(s_req) as s_resp:
                    s_data = json.loads(s_resp.read().decode("utf-8"))
                    return s_data["idToken"], s_data["localId"]
        raise RuntimeError(f"Auth error for {email}: {code}")

def compress_image_base64(filename, max_dim=600, quality=75):
    path = os.path.join(IMAGES_DIR, filename)
    im = Image.open(path).convert("RGB")
    im.thumbnail((max_dim, max_dim), Image.Resampling.LANCZOS)
    buf = io.BytesIO()
    im.save(buf, format="JPEG", quality=quality)
    b64_str = base64.b64encode(buf.getvalue()).decode("utf-8")
    print(f"  [Image] {filename} -> {len(buf.getvalue())} bytes (Base64 {len(b64_str)} chars)")
    return b64_str

def write_doc_patch(collection, doc_id, fields_dict, token):
    mask_paths = [f"updateMask.fieldPaths={k}" for k in fields_dict.keys()]
    mask_str = "&".join(mask_paths)
    url = f"https://firestore.googleapis.com/v1/projects/{PROJECT_ID}/databases/(default)/documents/{collection}/{doc_id}?{mask_str}"
    
    formatted_fields = {}
    for k, v in fields_dict.items():
        if isinstance(v, str):
            formatted_fields[k] = {"stringValue": v}
        elif isinstance(v, (int, float)):
            formatted_fields[k] = {"doubleValue": float(v)}
        elif isinstance(v, bool):
            formatted_fields[k] = {"booleanValue": v}
        elif isinstance(v, list):
            formatted_fields[k] = {"arrayValue": {"values": [{"stringValue": str(x)} for x in v]}}
        elif isinstance(v, dict):
            m = {}
            for mk, mv in v.items():
                if isinstance(mv, (int, float)):
                    m[mk] = {"doubleValue": float(mv)}
                else:
                    m[mk] = {"stringValue": str(mv)}
            formatted_fields[k] = {"mapValue": {"fields": m}}

    req = urllib.request.Request(url, data=json.dumps({"fields": formatted_fields}).encode("utf-8"), headers={
        "Content-Type": "application/json",
        "Authorization": f"Bearer {token}"
    }, method="PATCH")
    with urllib.request.urlopen(req) as resp:
        return json.loads(resp.read().decode("utf-8"))

def write_doc_post(collection, doc_id, fields_dict, token):
    url = f"https://firestore.googleapis.com/v1/projects/{PROJECT_ID}/databases/(default)/documents/{collection}?documentId={doc_id}"
    formatted_fields = {}
    for k, v in fields_dict.items():
        if isinstance(v, str):
            formatted_fields[k] = {"stringValue": v}
        elif isinstance(v, (int, float)):
            formatted_fields[k] = {"doubleValue": float(v)}
        elif isinstance(v, bool):
            formatted_fields[k] = {"booleanValue": v}
        elif isinstance(v, list):
            formatted_fields[k] = {"arrayValue": {"values": [{"stringValue": str(x)} for x in v]}}
        elif isinstance(v, dict):
            m = {}
            for mk, mv in v.items():
                if isinstance(mv, (int, float)):
                    m[mk] = {"doubleValue": float(mv)}
                else:
                    m[mk] = {"stringValue": str(mv)}
            formatted_fields[k] = {"mapValue": {"fields": m}}

    req = urllib.request.Request(url, data=json.dumps({"fields": formatted_fields}).encode("utf-8"), headers={
        "Content-Type": "application/json",
        "Authorization": f"Bearer {token}"
    }, method="POST")
    try:
        with urllib.request.urlopen(req) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        if e.code == 409: # Already exists
            print(f"  [i] {collection}/{doc_id} already exists (HTTP 409)")
            return None
        raise

def main():
    print("=== PAW AID: Final Cloud Firestore Seeder ===")
    
    # 1. Accounts
    print("\n1. Provisioning Accounts...")
    c1_tok, c1_uid = get_auth_token("citizen1.chennai@pawaid.org", "Password@123")
    c2_tok, c2_uid = get_auth_token("citizen2.chennai@pawaid.org", "PawAid@Citizen2026")
    ngo_s_tok, ngo_s_uid = get_auth_token("ngo.southchennai@pawaid.org", "PawAid@Ngo2026")
    ngo_n_tok, ngo_n_uid = get_auth_token("ngo.northchennai@pawaid.org", "PawAid@Ngo2026")

    print(f"  [OK] Citizen 1 (Karthik Raman - South Chennai): UID {c1_uid}")
    print(f"  [OK] Citizen 2 (Priya Sundaram - North Chennai): UID {c2_uid}")
    print(f"  [OK] NGO South (Besant Paws): UID {ngo_s_uid}")
    print(f"  [OK] NGO North (Perambur Rescue): UID {ngo_n_uid}")

    # 2. Users Collection
    print("\n2. Ensuring Users in Firestore...")
    users = [
        ("users", c1_uid, {"email": "citizen1.chennai@pawaid.org", "role": "CITIZEN", "fullName": "Karthik Raman", "phoneNumber": "+91 98410 11223", "accountStatus": "active"}, c1_tok),
        ("users", c2_uid, {"email": "citizen2.chennai@pawaid.org", "role": "CITIZEN", "fullName": "Priya Sundaram", "phoneNumber": "+91 98411 99887", "accountStatus": "active"}, c2_tok),
        ("users", ngo_s_uid, {"email": "ngo.southchennai@pawaid.org", "role": "NGO", "fullName": "South Chennai Animal Welfare Trust (Besant Paws)", "phoneNumber": "+91 98401 22334", "accountStatus": "pending"}, ngo_s_tok),
        ("users", ngo_n_uid, {"email": "ngo.northchennai@pawaid.org", "role": "NGO", "fullName": "North Chennai Animal Rescue Foundation", "phoneNumber": "+91 98402 77889", "accountStatus": "pending"}, ngo_n_tok),
    ]
    for col, doc_id, data, tok in users:
        write_doc_patch(col, doc_id, data, tok)
        print(f"  [OK] User: {data['fullName']}")

    # 3. NGOs Collection
    print("\n3. Ensuring NGOs in Firestore...")
    ngo_south = {
        "name": "South Chennai Animal Welfare Trust (Besant Paws)",
        "registrationNumber": "NGO-TN-CHE-2021-0089",
        "email": "ngo.southchennai@pawaid.org",
        "phone": "+91 98401 22334",
        "city": "Chennai",
        "state": "Tamil Nadu",
        "address": "14, 4th Main Road, Besant Nagar, Chennai - 600090",
        "latitude": 13.0002,
        "longitude": 80.2668,
        "serviceRadiusKm": 25.0,
        "specializations": ["Dogs", "Cats", "Emergency Trauma", "Fracture Care"],
        "status": "pending",
        "verificationStatus": "pending",
        "userId": ngo_s_uid,
    }
    ngo_north = {
        "name": "North Chennai Animal Rescue Foundation",
        "registrationNumber": "NGO-TN-CHE-2019-0042",
        "email": "ngo.northchennai@pawaid.org",
        "phone": "+91 98402 77889",
        "city": "Chennai",
        "state": "Tamil Nadu",
        "address": "88, Paper Mills Road, Perambur, Chennai - 600011",
        "latitude": 13.1147,
        "longitude": 80.2435,
        "serviceRadiusKm": 25.0,
        "specializations": ["Cattle", "Large Animals", "Dogs", "Birds", "First Aid"],
        "status": "pending",
        "verificationStatus": "pending",
        "userId": ngo_n_uid,
    }
    write_doc_post("ngos", ngo_s_uid, ngo_south, ngo_s_tok)
    write_doc_post("ngos", ngo_n_uid, ngo_north, ngo_n_tok)
    print("  [OK] NGO South: Besant Paws (Adyar/Besant Nagar)")
    print("  [OK] NGO North: Perambur Rescue Foundation")

    # 4. Images
    print("\n4. Compressing and Base64 Encoding Images from C:\\Users\\Rithu\\Downloads\\sample data...")
    img1 = compress_image_base64("pic1.png")
    img2 = compress_image_base64("pic2.jpg")
    img3 = compress_image_base64("pic3.jpg")
    img4 = compress_image_base64("pic4.jpg")

    # 5. The 4 Animal Distress Cases
    print("\n5. Writing 4 Cases to Cloud Firestore (reports/)...")
    cases = [
        # Case 1: Dog with Hind Leg Injury (Besant Nagar - South Chennai)
        ("case_south_dog_001", {
            "reportId": "case_south_dog_001",
            "citizenId": c1_uid,
            "reportStatus": "NEW",
            "photoBase64": img1,
            "aiAnalysis": {
                "animal": "Dog",
                "animalType": "DOG",
                "injury": "The hind legs appear injured or affected, and the dog is seated with one leg held awkwardly to the side. The exact injury is unclear from the photo.",
                "animalDescription": "The hind legs appear injured or affected, and the dog is seated with one leg held awkwardly to the side. The exact injury is unclear from the photo.",
                "injuryCategory": "TRAUMA_LIMB",
                "location": "Hind legs",
                "signs": "Unusual seated posture; no clear bleeding is visible.",
                "severity": "Moderate concern; mobility and injury need an in-person check.",
                "recommendedResponse": "Arrange veterinary assessment and care. Have the hind legs examined for wounds or infection and treated as needed.",
                "address": "Near Gandhi Beach Road, Besant Nagar, South Chennai - 600090",
                "latitude": 12.9985,
                "longitude": 80.2690,
                "assignedNgoId": ngo_s_uid,
                "assignedNgoName": "South Chennai Animal Welfare Trust (Besant Paws)",
                "citizenName": "Karthik Raman",
                "citizenPhone": "+91 98410 11223"
            }
        }, c1_tok),

        # Case 2: Cow with Broken Horn (Perambur - North Chennai)
        ("case_north_cow_002", {
            "reportId": "case_north_cow_002",
            "citizenId": c2_uid,
            "reportStatus": "NEW",
            "photoBase64": img2,
            "aiAnalysis": {
                "animal": "Cow",
                "animalType": "CATTLE",
                "injury": "One horn appears broken. No obvious blood is visible in the image.",
                "animalDescription": "One horn appears broken. No obvious blood is visible in the image.",
                "injuryCategory": "HEAD_OR_HORN_TRAUMA",
                "location": "Horn",
                "signs": "Broken or damaged horn; active bleeding is not apparent.",
                "severity": "Moderate concern; the extent of damage at the break cannot be judged from this photo.",
                "recommendedResponse": "Have a veterinarian assess the horn and treat it if needed, especially if the break exposes sensitive tissue, becomes painful, or shows signs of infection.",
                "address": "Near Perambur Railway Market, Paper Mills Road, North Chennai - 600011",
                "latitude": 13.1180,
                "longitude": 80.2410,
                "assignedNgoId": ngo_n_uid,
                "assignedNgoName": "North Chennai Animal Rescue Foundation",
                "citizenName": "Priya Sundaram",
                "citizenPhone": "+91 98411 99887"
            }
        }, c2_tok),

        # Case 3: Dog with Severe Emaciation / Thinness (Thiruvanmiyur - South Chennai)
        ("case_south_dog_003", {
            "reportId": "case_south_dog_003",
            "citizenId": c1_uid,
            "reportStatus": "NEW",
            "photoBase64": img3,
            "aiAnalysis": {
                "animal": "Dog",
                "animalType": "DOG",
                "injury": "The dog appears very thin and lean. The image cannot show the cause or confirm an infection or disease.",
                "animalDescription": "The dog appears very thin and lean. The image cannot show the cause or confirm an infection or disease.",
                "injuryCategory": "MALNUTRITION_EMACIATION",
                "location": "Overall body condition",
                "signs": "Prominent body contours and a sparse or uneven coat are visible.",
                "severity": "Moderate to high concern; thinness warrants assessment, but severity cannot be determined from a photo alone.",
                "recommendedResponse": "Arrange a veterinary examination to assess body condition and check for possible illness, parasites, or other causes. A photo cannot identify a specific disease.",
                "address": "Opposite Thiruvanmiyur Bus Terminus, South Chennai - 600041",
                "latitude": 12.9830,
                "longitude": 80.2590,
                "assignedNgoId": ngo_s_uid,
                "assignedNgoName": "South Chennai Animal Welfare Trust (Besant Paws)",
                "citizenName": "Karthik Raman",
                "citizenPhone": "+91 98410 11223"
            }
        }, c1_tok),

        # Case 4: Cat with Skin Rash / Distorted Photo (Royapuram - North Chennai)
        ("case_north_cat_004", {
            "reportId": "case_north_cat_004",
            "citizenId": c2_uid,
            "reportStatus": "NEW",
            "photoBase64": img4,
            "aiAnalysis": {
                "animal": "Cat",
                "animalType": "CAT",
                "injury": "The image is heavily distorted by green bands, so the reported rashes or possible infection under the face and on the abdomen cannot be reliably verified from the picture.",
                "animalDescription": "The image is heavily distorted by green bands, so the reported rashes or possible infection under the face and on the abdomen cannot be reliably verified from the picture.",
                "injuryCategory": "SKIN_RASH_INFECTION",
                "location": "Under the face and abdomen, as reported.",
                "signs": "The image quality prevents a clear view of the skin.",
                "severity": "Not assessable from this image.",
                "recommendedResponse": "Arrange veterinary assessment as soon as possible for the reported skin changes. Use a clear, unfiltered photo for visual documentation if available; don’t delay care if the cat seems unwell or the affected areas are worsening.",
                "address": "Near Royapuram Bridge, Rajaji Salai, North Chennai - 600013",
                "latitude": 13.1095,
                "longitude": 80.2940,
                "assignedNgoId": ngo_n_uid,
                "assignedNgoName": "North Chennai Animal Rescue Foundation",
                "citizenName": "Priya Sundaram",
                "citizenPhone": "+91 98411 99887"
            }
        }, c2_tok),
    ]

    for cid, data, tok in cases:
        write_doc_post("reports", cid, data, tok)
        print(f"  [OK] Seeded {cid} ({data['aiAnalysis']['animal']} at {data['aiAnalysis']['address']})")

    print("\n=== SUCCESS: All 2 NGOs, 2 Citizens, and 4 Animal Distress Cases (with Firebase-stored Images) have been successfully written to Cloud Firestore! ===")

if __name__ == "__main__":
    main()
