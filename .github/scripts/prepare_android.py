import argparse
import json
import os
import xml.etree.ElementTree
from jsmin import jsmin

xml.etree.ElementTree.register_namespace("android", "http://schemas.android.com/apk/res/android")
xml.etree.ElementTree.register_namespace("tools", "http://schemas.android.com/tools")


def load_metadata(path):
    with open(path, "rb") as f:
        return json.loads(jsmin(str(f.read(), "UTF-8")))


def determine_micuse_from_conf(conf):
    print("Determining mic usage from conf.lua... ", end="")
    try:
        with open(conf, "r", encoding="UTF-8") as f:
            conflua = f.read().replace("\r\n", "\n")
        micpos = conflua.find("audio.mic")
        if micpos == -1:
            print("can't locate audio.mic, false assumed")
            return False
        newline = conflua.find("\n", micpos)
        sub = conflua[micpos + len("audio.mic") : newline]
        found = sub.find("true") != -1
        print("true" if found else ("false" if sub.find("false") != -1 else "unknown value"))
        return found
    except FileNotFoundError:
        print("file not found")
        return False


def is_candidate_activity(elem):
    if elem.tag == "activity":
        # Check intent-filter
        for elem2 in elem:
            if elem2.tag == "intent-filter":
                # Find the action
                for elem3 in elem2:
                    if elem3.tag == "action":
                        if (
                            elem3.get("{http://schemas.android.com/apk/res/android}name")
                            == "android.intent.action.MAIN"
                        ):
                            return True
    return False


def replace_build_gradle_entry(build_gradle: str, key: str, value):
    pos = build_gradle.find(key)
    if pos != -1:
        newline = build_gradle.find("\n", pos)
        valuepos = pos + len(key) + 1
        if type(value) == str:
            return build_gradle[:valuepos] + json.dumps(value) + build_gradle[newline:]
        else:
            return build_gradle[:valuepos] + str(value) + build_gradle[newline:]
    return build_gradle


def modify_app_build_gradle(love_android: str, metadata, commit: bool):
    print("Reading app/build.gradle")
    with open(f"{love_android}/app/build.gradle", "r", encoding="UTF-8") as f:
        build_gradle = f.read().replace("\r\n", "\n")
    # Modify build.gradle
    print("Changing app/build.gradle")
    build_gradle = replace_build_gradle_entry(build_gradle, "applicationId", metadata["android"]["packageName"])
    build_gradle = replace_build_gradle_entry(build_gradle, "versionCode", metadata["android"]["versionNumber"])
    build_gradle = replace_build_gradle_entry(build_gradle, "versionName", metadata["version"])
    if commit:
        print("Writing new app/build.gradle")
        with open(f"{love_android}/app/build.gradle", "w", encoding="UTF-8") as f:
            f.write(build_gradle)
    else:
        print("app/build.gradle")
        print(build_gradle)


def modify_app_name_from_manifest(love_android: str, metadata, commit: bool):
    # Load AndroidManifest.xml
    print("Reading AndroidManifest.xml")
    manifest = xml.etree.ElementTree.parse(f"{love_android}/app/src/main/AndroidManifest.xml")
    for elem in manifest.getroot():
        if elem.tag == "application":
            # Replace the label here
            elem.set("{http://schemas.android.com/apk/res/android}label", metadata["name"])
            # Find first main activity
            for elem2 in elem:
                if is_candidate_activity(elem2):
                    # Update name
                    elem2.set("{http://schemas.android.com/apk/res/android}label", metadata["name"])
                    # Update screen orientation
                    elem2.set(
                        "{http://schemas.android.com/apk/res/android}screenOrientation",
                        metadata["android"]["screenOrientation"],
                    )
                    break
    # Check if we should commit changes
    xmlmanifest: bytes = xml.etree.ElementTree.tostring(manifest.getroot(), "UTF-8", "xml")
    if commit:
        print("Writing new AndroidManifest.xml")
        with open(f"{love_android}/app/src/main/AndroidManifest.xml", "wb") as f:
            f.write(xmlmanifest)
    else:
        print("AndroidManifest.xml")
        print(str(xmlmanifest, "UTF-8"))


def replace_gradle_properties(gradle_properties: list[str], key: str, value: str):
    for i in range(len(gradle_properties)):
        line = gradle_properties[i]
        if line.find(key + "=") != -1:
            gradle_properties[i] = f"{key}={value}"
            return i
    gradle_properties.append(f"{key}={value}")
    return len(gradle_properties) - 1


def modify_from_gradle_properties(love_android: str, metadata, commit: bool):
    # Load gradle.properties
    print("Reading gradle.properties")
    with open(f"{love_android}/gradle.properties", "r", encoding="UTF-8", newline="") as f:
        gradle_properties = list(f)

    # Detect newline
    newline = "\r\n" if gradle_properties[0].find("\r\n") else "\n"
    # Remove newlines
    gradle_properties = list(map(str.strip, gradle_properties))

    # Replace keys keys
    name_bytes: bytes = metadata["name"].encode("UTF-8")
    name_byte_array = ",".join(map(str, name_bytes))
    app_name = replace_gradle_properties(gradle_properties, "app.name", metadata["name"])
    app_name_array = replace_gradle_properties(gradle_properties, "app.name_byte_array", name_byte_array)
    replace_gradle_properties(gradle_properties, "app.application_id", metadata["android"]["packageName"])
    replace_gradle_properties(gradle_properties, "app.version_code", metadata["android"]["versionNumber"])
    replace_gradle_properties(gradle_properties, "app.version_name", metadata["version"])
    replace_gradle_properties(gradle_properties, "app.orientation", metadata["android"].get("screenOrientation", "landscape"))

    # Determine if `app.name` or `app.name_byte_array` should be used.
    comment_index = app_name_array
    for i in name_bytes:
        if i > 128:
            comment_index = app_name
            break
    gradle_properties[comment_index] = "#" + gradle_properties[comment_index]

    # Write new changes
    if commit:
        print("Writing new gradle.properties")
        with open(f"{love_android}/gradle.properties", "wb") as f:
            f.write(newline.join(gradle_properties).encode("UTF-8"))
    else:
        print("gradle.properties")
        for line in gradle_properties:
            print(line)


def should_replace_from_gradle_properties(love_android: str):
    with open(f"{love_android}/app/build.gradle", "r", encoding="UTF-8") as f:
        build_gradle = f.read().replace("\r\n", "\n")
    return build_gradle.find("applicationId project.properties[\"app.application_id\"]") != -1


def main():
    love_android = os.getenv("LOVEANDROID")
    # Env check
    if love_android is None:
        raise Exception("Need LOVEANDROID environment variable")

    parser = argparse.ArgumentParser()
    parser.add_argument("--commit", action="store_true", help="Actually commit changes to files!")
    parser.add_argument(
        "--get-icon-path", action="store_true", help='Output icon path as "icon" variable to GitHub Actions.'
    )
    args = parser.parse_args()

    # Load metadata
    print("Reading metadata")
    metadata = load_metadata("metadata.json")
    if "useMicrophone" not in metadata["android"] or metadata["android"]["useMicrophone"] is None:
        metadata["android"]["useMicrophone"] = determine_micuse_from_conf("game/conf.lua")

    # Check icon path output
    if args.get_icon_path:
        appicon = metadata["android"]["icon"] or ""
        print(f"::set-output name=icon::{appicon}")

    if should_replace_from_gradle_properties(love_android):
        # Modify app config from gradle.properties
        modify_from_gradle_properties(love_android, metadata, args.commit)
    else:
        # Modify app name from manifest
        modify_app_name_from_manifest(love_android, metadata, args.commit)
        # Modify app/build.gradle
        modify_app_build_gradle(love_android, metadata, args.commit)

    # Write build flavors variable
    if metadata["android"]["useMicrophone"]:
        print(f"::set-output name=apk::assembleEmbedRecordDebug")
        print(f"::set-output name=aab::bundleEmbedRecordRelease")
        print(
            f"::set-output name=apkpath::love-android/app/build/outputs/apk/embedRecord/debug/app-embed-record-debug.apk"
        )
        print(
            f"::set-output name=aabpath::love-android/app/build/outputs/bundle/embedRecordRelease/app-embed-record-release.aab"
        )
    else:
        print(f"::set-output name=apk::assembleEmbedNoRecordDebug")
        print(f"::set-output name=aab::bundleEmbedNoRecordRelease")
        print(
            f"::set-output name=apkpath::love-android/app/build/outputs/apk/embedNoRecord/debug/app-embed-noRecord-debug.apk"
        )
        print(
            f"::set-output name=aabpath::love-android/app/build/outputs/bundle/embedNoRecordRelease/app-embed-noRecord-release.aab"
        )


if __name__ == "__main__":
    main()