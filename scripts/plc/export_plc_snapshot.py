# -*- coding: utf-8 -*-
"""Export a deterministic, read-only PLC source snapshot from ctrlX PLE.

Run this file inside the ctrlX PLC Engineering ScriptEngine (IronPython 2.7).
The caller must inject these globals before execfile():

    SNAPSHOT_PROJECT_PATH = r"C:\\...\\Station.project"
    SNAPSHOT_OUTPUT_DIR = r"C:\\...\\data\\plc_snapshots\\station010"

The project must already be the primary project. This script deliberately does
not call se.projects.open(), save(), or any online/device API.
"""

from __future__ import print_function

import hashlib
import json
import os
import re
import sys
import traceback

import scriptengine as se
from System.IO import Directory, File
from System.Security.Cryptography import SHA256
from System.Text import UTF8Encoding


FORMAT_VERSION = 1
ROOT_MARKER = ".plc-snapshot-root"
MANIFEST_NAME = "manifest.json"
OBJECTS_DIR_NAME = "objects"
UTF8_NO_BOM = UTF8Encoding(False)


def _to_unicode(value):
    if value is None:
        return u""
    if isinstance(value, unicode):
        return value
    if isinstance(value, str):
        return value.decode("utf-8", "replace")
    return unicode(value)


def _normalize_text(value):
    text = _to_unicode(value)
    return text.replace(u"\r\n", u"\n").replace(u"\r", u"\n")


def _sha256_text(text):
    return hashlib.sha256(_to_unicode(text).encode("utf-8")).hexdigest()


def _sha256_file(path):
    digest = SHA256.Create()
    stream = File.OpenRead(path)
    try:
        hash_bytes = digest.ComputeHash(stream)
    finally:
        stream.Close()
        digest.Dispose()
    return u"".join(u"%02x" % value for value in hash_bytes)


def _canonical_path(path):
    return os.path.normcase(os.path.abspath(path))


def _safe_object_name(name):
    value = re.sub(ur"[^0-9A-Za-z_.-]+", u"_", _to_unicode(name)).strip(u"._")
    if not value:
        value = u"object"
    return value[:80]


def _read_text_section(obj, attribute_name):
    try:
        section = getattr(obj, attribute_name)
        if section is not None and hasattr(section, "text"):
            return _normalize_text(section.text)
    except Exception:
        pass
    return u""


def _find_application(project):
    try:
        application = project.active_application
        if application is not None:
            return application
    except Exception:
        pass

    # Narrow fallback: only descend through Device -> PLC Logic -> Application.
    current = project
    for expected_name in ("Device", "PLC Logic", "Application"):
        match = None
        for child in current.get_children(False):
            if _to_unicode(child.get_name()) == expected_name:
                match = child
                break
        if match is None:
            raise RuntimeError("Cannot find PLC tree node: %s" % expected_name)
        current = match
    return current


def _collect_code_objects(application):
    collected = []
    application_system_nodes = set((u"Library Manager", u"Task Configuration", u"Symbols"))

    def walk(obj, parent_path):
        name = _to_unicode(obj.get_name())
        object_path = parent_path + u"/" + name if parent_path else name
        declaration = _read_text_section(obj, "textual_declaration")
        implementation = _read_text_section(obj, "textual_implementation")

        if declaration or implementation:
            collected.append({
                "path": object_path,
                "name": name,
                "type": _to_unicode(type(obj).__name__),
                "declaration": declaration,
                "implementation": implementation,
            })

        try:
            children = obj.get_children(False)
        except Exception:
            children = []
        for child in children:
            # These Application children contain no user ST and may expand into
            # large repository/configuration graphs in ScriptEngine.
            if object_path == u"Application" and _to_unicode(child.get_name()) in application_system_nodes:
                continue
            walk(child, object_path)

    walk(application, u"")
    collected.sort(key=lambda item: item["path"].lower())
    return collected


def _render_object(item):
    header = (
        u"(*\n"
        u"  PLC text snapshot - generated; do not edit this mirror.\n"
        u"  Object path: %s\n"
        u"  Object type: %s\n"
        u"*)\n" % (item["path"], item["type"])
    )
    parts = [header]
    if item["declaration"]:
        parts.append(u"\n(* ===== DECLARATION ===== *)\n")
        parts.append(item["declaration"])
        if not item["declaration"].endswith(u"\n"):
            parts.append(u"\n")
    if item["implementation"]:
        parts.append(u"\n(* ===== IMPLEMENTATION ===== *)\n")
        parts.append(item["implementation"])
        if not item["implementation"].endswith(u"\n"):
            parts.append(u"\n")
    return u"".join(parts)


def _load_previous_files(manifest_path):
    if not File.Exists(manifest_path):
        return set()
    try:
        previous = json.loads(_to_unicode(File.ReadAllText(manifest_path, UTF8_NO_BOM)))
        result = set()
        for item in previous.get("objects", []):
            relative_path = _to_unicode(item.get("file", u""))
            if relative_path.startswith(OBJECTS_DIR_NAME + u"/") and relative_path.endswith(u".st"):
                result.add(relative_path)
        return result
    except Exception:
        raise RuntimeError("Existing manifest is invalid; refusing stale-file cleanup: %s" % manifest_path)


def _write_snapshot(project_path, output_dir, code_objects):
    output_dir = os.path.abspath(output_dir)
    objects_dir = os.path.join(output_dir, OBJECTS_DIR_NAME)
    marker_path = os.path.join(output_dir, ROOT_MARKER)
    manifest_path = os.path.join(output_dir, MANIFEST_NAME)

    if not Directory.Exists(output_dir):
        Directory.CreateDirectory(output_dir)
    if File.Exists(marker_path):
        marker = _normalize_text(File.ReadAllText(marker_path, UTF8_NO_BOM)).strip()
        if marker != u"plc-text-snapshot-v1":
            raise RuntimeError("Unexpected snapshot root marker: %s" % marker_path)
    else:
        File.WriteAllText(marker_path, u"plc-text-snapshot-v1\n", UTF8_NO_BOM)
    if not Directory.Exists(objects_dir):
        Directory.CreateDirectory(objects_dir)

    previous_files = _load_previous_files(manifest_path)
    manifest_objects = []
    current_files = set()

    for item in code_objects:
        path_hash = hashlib.sha256(item["path"].encode("utf-8")).hexdigest()[:16]
        file_name = u"%s__%s.st" % (path_hash, _safe_object_name(item["name"]))
        relative_path = OBJECTS_DIR_NAME + u"/" + file_name
        absolute_path = os.path.join(output_dir, relative_path.replace(u"/", os.sep))
        rendered = _render_object(item)
        File.WriteAllText(absolute_path, rendered, UTF8_NO_BOM)
        current_files.add(relative_path)
        manifest_objects.append({
            "path": item["path"],
            "type": item["type"],
            "file": relative_path,
            "sha256": _sha256_text(rendered),
            "hasDeclaration": bool(item["declaration"]),
            "hasImplementation": bool(item["implementation"]),
        })

    # Delete only stale files explicitly owned by the previous manifest.
    for relative_path in sorted(previous_files - current_files):
        stale_path = os.path.join(output_dir, relative_path.replace(u"/", os.sep))
        if File.Exists(stale_path):
            File.Delete(stale_path)

    manifest = {
        "formatVersion": FORMAT_VERSION,
        "sourceProject": os.path.basename(project_path),
        "sourceProjectSha256": _sha256_file(project_path),
        "objectCount": len(manifest_objects),
        "objects": manifest_objects,
    }
    manifest_text = _to_unicode(json.dumps(manifest, ensure_ascii=False, indent=2, sort_keys=True)) + u"\n"
    File.WriteAllText(manifest_path, manifest_text, UTF8_NO_BOM)
    return manifest


def main():
    if "SNAPSHOT_PROJECT_PATH" not in globals() or "SNAPSHOT_OUTPUT_DIR" not in globals():
        raise RuntimeError("SNAPSHOT_PROJECT_PATH and SNAPSHOT_OUTPUT_DIR must be injected by the caller")

    project_path = os.path.abspath(_to_unicode(SNAPSHOT_PROJECT_PATH))
    output_dir = os.path.abspath(_to_unicode(SNAPSHOT_OUTPUT_DIR))
    project = se.projects.primary
    if project is None:
        raise RuntimeError("No primary PLC project is open")
    if _canonical_path(_to_unicode(project.path)) != _canonical_path(project_path):
        raise RuntimeError(
            "Primary project mismatch; expected '%s', got '%s'" % (project_path, _to_unicode(project.path))
        )

    application = _find_application(project)
    code_objects = _collect_code_objects(application)
    manifest = _write_snapshot(project_path, output_dir, code_objects)
    print("PLC_SNAPSHOT_OBJECTS=%d" % manifest["objectCount"])
    print("PLC_SNAPSHOT_OUTPUT=%s" % output_dir)
    print("PLC_SNAPSHOT_PROJECT_SHA256=%s" % manifest["sourceProjectSha256"])
    print("SCRIPT_SUCCESS")


try:
    main()
except Exception as error:
    print("SCRIPT_ERROR: %s" % error)
    print(traceback.format_exc())
    sys.exit(1)
