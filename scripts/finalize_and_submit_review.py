#!/usr/bin/env python3
"""
Finalizes Mirage Blade: Hourglass (com.ngd.mirageblade) on App Store Connect:
Sets Age Rating, attaches Build 100 (macOS) & Build 101 (iOS/iPadOS), and submits BOTH to WAITING_FOR_REVIEW.
"""

import os
import sys
import time

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, SCRIPT_DIR)
from configure_appstore_all import BUNDLE_ID, api_request, make_jwt  # noqa: E402


def configure_age_rating(base: str, token: str, app_id: str):
    app_infos = api_request("GET", f"{base}/apps/{app_id}/appInfos", token)
    if not app_infos.get("data"):
        return
    info_id = app_infos["data"][0]["id"]
    for sub_two in ("GAMES_ADVENTURE", "GAMES_ARCADE"):
        try:
            api_request("PATCH", f"{base}/appInfos/{info_id}", token, {
                "data": {
                    "type": "appInfos",
                    "id": info_id,
                    "relationships": {
                        "primaryCategory": {"data": {"type": "appCategories", "id": "GAMES"}},
                        "primarySubcategoryOne": {"data": {"type": "appCategories", "id": "GAMES_ACTION"}},
                        "primarySubcategoryTwo": {"data": {"type": "appCategories", "id": sub_two}},
                    }
                }
            })
            break
        except Exception:
            pass

    ard_res = api_request("GET", f"{base}/appInfos/{info_id}/ageRatingDeclaration", token)
    ard = ard_res.get("data")
    if not ard:
        return
    ard_id = ard["id"]
    cur_attrs = ard.get("attributes", {})

    desired_enums = {
        "alcoholTobaccoOrDrugUseOrReferences": "NONE",
        "contests": "NONE",
        "gamblingSimulated": "NONE",
        "horrorOrFearThemes": "NONE",
        "matureOrSuggestiveThemes": "NONE",
        "medicalOrTreatmentInformation": "NONE",
        "profanityOrCrudeHumor": "NONE",
        "sexualContentGraphicAndNudity": "NONE",
        "sexualContentOrNudity": "NONE",
        "violenceCartoonOrFantasy": "INFREQUENT_OR_MILD",
        "violenceRealistic": "NONE",
        "violenceRealisticProlongedGraphicOrSadistic": "NONE",
        "gunsOrOtherWeapons": "INFREQUENT_OR_MILD",
        "kidsAgeBand": None,
    }
    desired_bools = {
        "gambling": False,
        "lootBox": False,
        "unrestrictedWebAccess": False,
        "ageAssurance": False,
        "advertising": False,
        "healthOrWellnessTopics": False,
        "messagingAndChat": False,
        "parentalControls": False,
        "userGeneratedContent": False,
        "socialMedia": False,
    }

    patch_attrs = {}
    for k, v in desired_enums.items():
        if k in cur_attrs:
            patch_attrs[k] = v
    for k, v in desired_bools.items():
        if k in cur_attrs:
            patch_attrs[k] = v

    try:
        api_request("PATCH", f"{base}/ageRatingDeclarations/{ard_id}", token, {
            "data": {"type": "ageRatingDeclarations", "id": ard_id, "attributes": patch_attrs}
        })
        print(f"==> Configured Age Rating Declaration ({ard_id})!")
    except Exception as e:
        print(f"Note on Age Rating Declaration: {e}")


def wait_and_attach_builds(base: str, key_id: str, issuer_id: str, key_path: str, app_id: str) -> dict:
    token = make_jwt(key_id, issuer_id, key_path)
    vers = api_request("GET", f"{base}/apps/{app_id}/appStoreVersions", token)
    ver_by_plat = {v["attributes"]["platform"]: v["id"] for v in vers.get("data", [])}

    target_map = {"100": "MAC_OS", "101": "IOS"}
    attached = {}

    for attempt in range(35):
        token = make_jwt(key_id, issuer_id, key_path)
        builds_res = api_request("GET", f"{base}/builds?filter[app]={app_id}&limit=20", token)
        for b in builds_res.get("data", []):
            bid = b["id"]
            bver = str(b["attributes"].get("version", ""))
            state = b["attributes"].get("processingState")
            plat = target_map.get(bver)
            print(f"   [Check {attempt + 1}] Build {bver} ({bid}, {plat}) -> {state}")
            if plat and plat not in attached and state == "VALID":
                try:
                    api_request("PATCH", f"{base}/builds/{bid}", token, {
                        "data": {"type": "builds", "id": bid, "attributes": {"usesNonExemptEncryption": False}}
                    })
                except Exception:
                    pass
                ver_id = ver_by_plat.get(plat)
                if ver_id:
                    api_request("PATCH", f"{base}/appStoreVersions/{ver_id}/relationships/build", token, {
                        "data": {"type": "builds", "id": bid}
                    })
                    print(f"==> ATTACHED {plat} Build {bver} ({bid}) to App Store Version {ver_id}!")
                    attached[plat] = ver_id

        if len(attached) >= 2:
            break
        time.sleep(8)

    return ver_by_plat


def try_submit_platform(base: str, token: str, app_id: str, platform: str, ver_id: str):
    print(f"\n==> Attempting App Review submission for {platform} ({ver_id})...")
    try:
        try:
            api_request("PATCH", f"{base}/appStoreVersions/{ver_id}", token, {
                "data": {"type": "appStoreVersions", "id": ver_id, "attributes": {"releaseType": "AFTER_APPROVAL"}}
            })
        except Exception:
            pass

        existing_subs = api_request("GET", f"{base}/apps/{app_id}/reviewSubmissions?filter[platform]={platform}", token)
        sub_id = next((s["id"] for s in existing_subs.get("data", []) if s["attributes"].get("state") in ("READY_FOR_REVIEW", "UNRESOLVED_ISSUES")), None)
        if not sub_id:
            created_sub = api_request("POST", f"{base}/reviewSubmissions", token, {
                "data": {
                    "type": "reviewSubmissions",
                    "attributes": {"platform": platform},
                    "relationships": {"app": {"data": {"type": "apps", "id": app_id}}}
                }
            })
            sub_id = created_sub["data"]["id"]

        try:
            api_request("POST", f"{base}/reviewSubmissionItems", token, {
                "data": {
                    "type": "reviewSubmissionItems",
                    "relationships": {
                        "reviewSubmission": {"data": {"type": "reviewSubmissions", "id": sub_id}},
                        "appStoreVersion": {"data": {"type": "appStoreVersions", "id": ver_id}},
                    }
                }
            })
        except Exception:
            pass

        res = api_request("PATCH", f"{base}/reviewSubmissions/{sub_id}", token, {
            "data": {"type": "reviewSubmissions", "id": sub_id, "attributes": {"submitted": True}}
        })
        st = res.get("data", {}).get("attributes", {}).get("state")
        print(f"==> SUCCESS! {platform} submitted to App Review! ReviewSubmission state = {st}")
    except Exception as e:
        print(f"==> Note when submitting {platform} via API:\n{e}")


def main():
    key_id = os.environ.get("ASC_KEY_ID", "Z992GJ553V").strip()
    issuer_id = os.environ.get("ASC_ISSUER_ID", "b66d4183-4ecf-491d-992b-ce246240199b").strip()
    key_path = os.environ.get(
        "ASC_KEY_PATH",
        "/Users/gabordanielnagy/.gemini/antigravity/brain/75a1d5cc-1b15-43a1-a775-3011de888b88/.user_uploaded/media_1794641558319_e343185e.p8",
    ).strip()

    base = "https://api.appstoreconnect.apple.com/v1"
    token = make_jwt(key_id, issuer_id, key_path)

    apps = api_request("GET", f"{base}/apps?filter[bundleId]={BUNDLE_ID}", token)
    if not apps.get("data"):
        sys.exit(f"App for {BUNDLE_ID} not found yet in App Store Connect.")
    app_id = apps["data"][0]["id"]

    configure_age_rating(base, token, app_id)
    ver_by_plat = wait_and_attach_builds(base, key_id, issuer_id, key_path, app_id)

    token = make_jwt(key_id, issuer_id, key_path)
    for plat, vid in ver_by_plat.items():
        try_submit_platform(base, token, app_id, plat, vid)


if __name__ == "__main__":
    main()
