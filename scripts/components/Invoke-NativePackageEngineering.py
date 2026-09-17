"""Run through the existing PLE Tools > Scripting > Execute Script File.

Only isolated files explicitly listed in native-engineering-request.json may
be opened or changed. This uses public CODESYS ScriptEngine APIs, never online
objects. The previously open, clean project is reopened without saving it.
"""
import hashlib
import json
import os
import re
import shutil
import traceback
from datetime import datetime

import scriptengine as se
from System import Version

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
WORK = os.path.join(REPO, 'data', 'native-packages', '20260915')
REQUEST = os.path.join(WORK, 'native-engineering-request.json')


def digest(path):
    with open(path, 'rb') as stream:
        return hashlib.sha256(stream.read()).hexdigest().upper()


def contained(path):
    full = os.path.normcase(os.path.abspath(path))
    root = os.path.normcase(os.path.abspath(WORK)) + os.sep
    if not full.startswith(root):
        raise Exception('Path is outside isolated workspace: ' + path)
    return os.path.abspath(path)


def messages():
    result = []
    for category in se.system.get_message_categories(True):
        for message in se.system.get_message_objects(category):
            result.append({'severity': str(message.severity),
                           'text': str(getattr(message, 'text', message))})
    return result


def compile_project(project, library):
    for category in se.system.get_message_categories(False):
        se.system.clear_messages(category)
    project.clean_all()
    if library:
        project.check_all_pool_objects()
    else:
        if project.active_application is None:
            raise Exception('No active application')
        project.active_application.build()
    entries = messages()
    errors = sum(1 for m in entries if m['severity'].endswith('Error'))
    warnings = sum(1 for m in entries if m['severity'].endswith('Warning'))
    return {'freshCompile': True, 'errorCount': errors, 'warningCount': warnings,
            'messages': entries, 'completedAtUtc': datetime.utcnow().isoformat() + 'Z'}


def source_text(entry):
    path = os.path.abspath(os.path.join(REPO, entry['path']))
    allowed = [os.path.join(REPO, 'src', 'plc', 'libraries'),
               os.path.join(REPO, 'examples', 'plc', 'components')]
    if not any(path.startswith(root + os.sep) for root in allowed):
        raise Exception('Source is outside the independent library tree')
    if digest(path) != entry['sha256']:
        raise Exception('Library source changed: ' + path)
    with open(path, 'rb') as stream:
        return stream.read().decode('utf-8-sig').replace('\r\n', '\n').strip()


def child(parent, name):
    found = [o for o in parent.get_children(False) if o.get_name() == name]
    if len(found) != 1:
        raise Exception('Expected one child: ' + name)
    return found[0]


def set_code(obj, declaration, implementation=None):
    obj.textual_declaration.replace(declaration)
    if obj.textual_declaration.text.replace('\r\n', '\n').strip() != declaration.strip():
        raise Exception('Declaration readback failed: ' + obj.get_name())
    if implementation is not None:
        obj.textual_implementation.replace(implementation)
        if obj.textual_implementation.text.replace('\r\n', '\n').strip() != implementation.strip():
            raise Exception('Implementation readback failed: ' + obj.get_name())


def import_source(folder, entry):
    text = source_text(entry)
    if text.startswith('TYPE '):
        name = re.match(r'TYPE\s+(\w+)', text).group(1)
        kind = se.DutType.Union if '\nUNION' in text else (
            se.DutType.Structure if '\nSTRUCT' in text else se.DutType.Alias)
        if kind == se.DutType.Alias:
            base_type = text.split(':', 1)[1].split(';', 1)[0].strip()
            obj = folder.create_dut(name=name, type=kind, baseType=base_type)
        else:
            obj = folder.create_dut(name=name, type=kind)
        set_code(obj, text)
        return 1
    pattern = r'\(\* ===== OBJECT (.*?) ===== \*\)\s*\(\* ===== DECLARATION ===== \*\)\s*(.*?)\(\* ===== IMPLEMENTATION ===== \*\)\s*(.*?)(?=\(\* ===== OBJECT |\Z)'
    parts = re.findall(pattern, text, re.S)
    if not parts:
        declaration, implementation = text.split('(* ===== DECLARATION ===== *)', 1)[1].split('(* ===== IMPLEMENTATION ===== *)', 1)
        name = re.search(r'FUNCTION_BLOCK\s+(\w+)', declaration).group(1)
        parts = [(name, declaration, implementation)]
    name, declaration, implementation = parts[0]
    root = folder.create_pou(name=name, type=se.PouType.FunctionBlock,
                             language=se.ImplementationLanguages.st)
    set_code(root, declaration.strip(), implementation.strip())
    props = {}
    for name, declaration, implementation in parts[1:]:
        declaration, implementation = declaration.strip(), implementation.strip()
        if '/' in name:
            prop_name, accessor = name.split('/')
            obj = child(props[prop_name], accessor)
            set_code(obj, declaration, implementation)
        elif declaration.startswith('PROPERTY'):
            return_type = declaration.split(':', 1)[1].strip()
            obj = root.create_property(name, return_type, se.ImplementationLanguages.st)
            set_code(obj, declaration)
            props[name] = obj
        else:
            first = declaration.split('\n')[0]
            return_type = first.split(':', 1)[1].strip() if ':' in first else None
            obj = root.create_method(name, return_type, se.ImplementationLanguages.st)
            set_code(obj, declaration, implementation)
    accessors = set(name for name, declaration, implementation in parts[1:] if '/' in name)
    for name, prop in props.items():
        for accessor in list(prop.get_children(False)):
            if name + '/' + accessor.get_name() not in accessors:
                accessor.remove()
    return len(parts)


def managed_library(name):
    found = se.librarymanager.find_library(name)
    if found is None:
        raise Exception('Required installed library is missing: ' + name)
    return found[0]


def resolve_ctrlx(library_manager):
    redirects = {
        'Tc2_System': 'IecSfc, 4.1.0.0 (System)',
        'OpconBaseSysDep': 'NxBaseSysDep_CXA, 1.0.6.0 (Bosch Group)',
        'OpconSocketSysDep': 'NxSocketSysDep_CXA, 1.0.7.0 (Bosch Group)',
    }
    resolutions = []
    def visit(reference, ancestors):
        name = str(reference.name)
        if name in ancestors:
            return
        if reference.is_placeholder and str(reference.placeholder_name) in redirects:
            target = redirects[str(reference.placeholder_name)]
            if str(reference.effective_resolution) != target:
                reference.set_redirection(target)
            if str(reference.effective_resolution) != target:
                raise Exception('Placeholder did not resolve: ' + name)
            resolutions.append({'placeholder': str(reference.placeholder_name), 'effective': target})
        for dependency in reference.get_dependencies():
            visit(dependency, ancestors + [name])
    for reference in library_manager.references:
        visit(reference, [])
    return resolutions


def dependency_inventory(manager):
    result = []
    visited = set()
    def visit(reference):
        effective = str(reference.effective_resolution) if reference.is_placeholder else str(reference.managed_library)
        identity = str(reference.name) + '|' + effective
        if identity in visited:
            return
        visited.add(identity)
        result.append({'reference': str(reference.name),
                       'effective': effective,
                       'namespace': str(reference.namespace),
                       'qualifiedOnly': bool(reference.qualified_only)})
        for dependency in reference.get_dependencies():
            visit(dependency)
    for reference in manager.references:
        visit(reference)
    return result


def build_library(entry):
    path = contained(entry['path'])
    output = contained(entry['output'])
    if os.path.exists(path) or os.path.exists(output):
        raise Exception('Use a fresh isolated work directory for each build attempt')
    if not os.path.isdir(os.path.dirname(path)):
        os.makedirs(os.path.dirname(path))
    p = se.projects.create(path)
    info = p.get_project_info()
    info.company = entry.get('company', 'BPP Internal Engineering')
    info.title = entry['name']
    info.version = Version(entry['version'])
    info.default_namespace = entry['name']
    info.author = 'WANG Zhi (RBCD\\TEF2)'
    info.description = entry['description']
    info.released = False
    manager = p.get_library_manager()
    for dependency in entry['dependencies']:
        manager.add_library(managed_library(dependency))
    for reference in manager.references:
        reference.qualified_only = False
        reference.publish_symbols_in_container = False
    redirects = resolve_ctrlx(manager)
    p.create_folder('Library')
    folder = child(p, 'Library')
    count = sum(import_source(folder, source) for source in entry['sources'])
    p.save()
    result = {'path': path, 'kind': 'library', 'name': entry['name'], 'version': entry['version'],
              'sourceReadbackObjects': count, 'sources': entry['sources'],
              'dependencies': dependency_inventory(manager), 'redirects': redirects}
    result.update(compile_project(p, True))
    if result['errorCount'] == 0:
        info.released = True
        p.save()
        p.save_as_compiled_library(output)
        result['compiledLibrary'] = output
        result['compiledSha256'] = digest(output)
        result['sourceProjectSha256'] = digest(path)
    p.close()
    return result


def build_consumer(entry, target_device):
    path = contained(entry['path'])
    if os.path.exists(path):
        raise Exception('Consumer output already exists')
    if digest(entry['template']) != entry['templateSha256']:
        raise Exception('Consumer template changed')
    os.makedirs(os.path.dirname(path))
    shutil.copyfile(entry['template'], path)
    p = se.projects.open(path)
    device = child(p, 'Device')
    device.update(type=target_device['type'], id=target_device['id'], version=target_device['version'])
    app = p.active_application
    if app is None:
        raise Exception('Template has no active application')
    manager = app.get_library_manager()
    for binary in entry['libraries']:
        library_path = contained(binary['path'])
        if digest(library_path) != binary['sha256']:
            raise Exception('Consumer library changed')
        found = se.librarymanager.find_library(binary['identity'])
        if found is None:
            install_repo = se.librarymanager.find_library('Standard, 3.5.18.0 (System)')[1]
            se.librarymanager.install_library(library_path, repository=install_repo, overwrite=False)
        elif digest(se.librarymanager.get_file_path(found[0])) != binary['sha256']:
            installed_path = str(se.librarymanager.get_file_path(found[0]))
            installed_hash = digest(installed_path)
            if (binary['identity'] not in (
                    'BppBurster2316, 0.1.0.2 (BPP Internal Engineering)',
                    'BppForceTrace, 0.2.0.0 (BPP Internal Engineering)',
                    'ForceTrace, 0.2.0.0 (Internal Engineering)',
                    'Burster2316, 0.1.0.2 (Internal Engineering)')
                    or installed_hash != binary.get('replaceInstalledSha256')):
                raise Exception('Different candidate bytes already installed; do not overwrite')
            backup = contained(os.path.join(os.path.dirname(path), 'previous-candidate.compiled-library'))
            shutil.copyfile(installed_path, backup)
            se.librarymanager.install_library(library_path, repository=found[1], overwrite=True)
            replaced = se.librarymanager.find_library(binary['identity'])
            if digest(se.librarymanager.get_file_path(replaced[0])) != binary['sha256']:
                raise Exception('Candidate replacement readback failed')
        manager.add_library(managed_library(binary['identity']))
    for dependency in entry.get('dependencies', []):
        manager.add_library(managed_library(dependency))
    redirects = resolve_ctrlx(manager)
    code = source_text(entry['source'])
    declaration, implementation = code.split('(* ===== IMPLEMENTATION ===== *)', 1)
    declaration = declaration.split('(* ===== DECLARATION ===== *)', 1)[1].strip()
    found = [obj for obj in app.get_children(False) if obj.get_name() == 'PLC_PRG']
    program = found[0] if found else app.create_pou(name='PLC_PRG', type=se.PouType.Program, language=se.ImplementationLanguages.st)
    set_code(program, declaration, implementation.strip())
    program.build_properties.link_always = True
    main = [obj for obj in app.get_children(True)
            if obj.get_name() == 'MAIN' and obj.has_textual_implementation]
    if len(main) != 1:
        raise Exception('Isolated template must have one MAIN task entry')
    set_code(main[0], 'PROGRAM MAIN', '// Isolated component consumer; no physical I/O.\nPLC_PRG();')
    p.save()
    check = {'kind': 'consumer', 'name': entry['name'], 'path': path,
             'sourceReadback': True, 'source': entry['source'],
             'dependencies': dependency_inventory(manager), 'redirects': redirects,
             'targetDevice': target_device}
    check.update(compile_project(p, False))
    check['programLinked'] = bool(program.build_properties.link_always)
    check['taskEntryReadback'] = main[0].textual_implementation.text
    if check['errorCount'] == 0:
        check['programSignatureCrc'] = str(program.get_signature_crc(application=app))
    check['applicationExport'] = os.path.join(os.path.dirname(path), 'Consumer.xml')
    app.export_xml(path=check['applicationExport'], recursive=True,
                   export_folder_structure=True, declarations_as_plaintext=True)
    p.save()
    check['outputSha256'] = digest(path)
    p.close()
    return check


with open(REQUEST, 'rb') as stream:
    request = json.load(stream)
report_path = contained(request['reportPath'])
if os.path.exists(report_path):
    raise Exception('Use a new report path; prior evidence is immutable')
original = se.projects.primary
original_path = str(original.path) if original is not None else None
if original is not None and original.dirty:
    raise Exception('Original project has unsaved changes; no project was closed')
if original_path != request['expectedOriginalProject']:
    raise Exception('Unexpected original project: ' + str(original_path))
original_hash = digest(original_path) if original_path else None
report = {'action': request['action'], 'startedAtUtc': datetime.utcnow().isoformat() + 'Z',
          'originalProject': original_path, 'originalSha256': original_hash,
          'profile': 'ctrlX PLC 2.6.8', 'onlineOperations': False, 'checks': [], 'passed': False}
try:
    target_device = request.get('targetDevice')
    if request.get('consumers'):
        if target_device is None:
            device_id = child(original, 'Device').get_device_identification()
            target_device = {'type': device_id.type, 'id': str(device_id.id), 'version': str(device_id.version)}
        report['targetDevice'] = target_device
    if original is not None:
        original.close()
    if request['action'] not in ('verify-danikor', 'build-libraries', 'build-consumers'):
        raise Exception('Unsupported action')
    for entry in request.get('libraries', []):
        try:
            report['checks'].append(build_library(entry))
        except Exception:
            report['checks'].append({'name': entry['name'], 'kind': 'library',
                                     'freshCompile': False, 'errorCount': 1,
                                     'error': traceback.format_exc()})
            failed = se.projects.primary
            if failed is not None and os.path.normcase(str(failed.path)).startswith(os.path.normcase(WORK) + os.sep):
                failed.close()
    for entry in request.get('consumers', []):
        for binary in entry['libraries']:
            if binary.get('fromBuild'):
                built = [check for check in report['checks']
                         if check.get('kind') == 'library'
                         and check.get('name') == binary['fromBuild']
                         and check.get('errorCount') == 0]
                if len(built) != 1:
                    raise Exception('Consumer requires one successful library build')
                binary['path'] = built[0]['compiledLibrary']
                binary['sha256'] = built[0]['compiledSha256']
        report['checks'].append(build_consumer(entry, target_device))
    for entry in request.get('projects', []):
        path = contained(entry['path'])
        if digest(path) != entry['sha256']:
            raise Exception('Project baseline changed: ' + path)
        project = se.projects.open(path)
        check = {'path': path, 'inputSha256': digest(path), 'kind': entry['kind']}
        check.update(compile_project(project, entry['kind'] == 'library'))
        report['checks'].append(check)
        if check['errorCount']:
            raise Exception('Compile failed: ' + path)
        if entry['kind'] != 'library':
            app = project.active_application
            check['dependencies'] = dependency_inventory(app.get_library_manager())
            if entry['kind'] == 'reference':
                symbol = [o for o in app.get_children(True) if o.is_symbol_config][0]
                check['symbols'] = []
                for collection in (symbol.get_all_signatures(False), symbol.get_only_configured_datatypes()):
                    for signature in collection:
                        if signature.full_qualified_name in ('Station', 'Wp100') or 'BppForceTraceData' in signature.full_qualified_name or 'BursterResistomat23161' in signature.full_qualified_name:
                            check['symbols'].append({'name': signature.full_qualified_name,
                                'variables': [{'name': v.name, 'type': v.type, 'effective': str(v.effective_access)}
                                              for v in signature.variables]})
            check['applicationExport'] = os.path.join(os.path.dirname(path), 'Consumer-readback.xml')
            app.export_xml(path=check['applicationExport'], recursive=True,
                           export_folder_structure=True, declarations_as_plaintext=True)
            project.save()
        check['outputSha256'] = digest(path)
        project.close()
    report['passed'] = all(check['errorCount'] == 0 for check in report['checks'])
except Exception:
    report['error'] = traceback.format_exc()
finally:
    active = se.projects.primary
    if active is not None and os.path.normcase(str(active.path)).startswith(os.path.normcase(WORK) + os.sep):
        active.close()
    if original_path and request.get('restoreOriginal', True) and se.projects.primary is None:
        se.projects.open(original_path)
    report['originalUnchanged'] = original_path is None or digest(original_path) == original_hash
    report['finishedAtUtc'] = datetime.utcnow().isoformat() + 'Z'
    with open(report_path, 'wb') as stream:
        stream.write(json.dumps(report, indent=2, ensure_ascii=True).encode('utf-8'))
    print('NATIVE_PACKAGE_REPORT ' + report_path)
    print('PASSED=' + str(report['passed']) + ' ORIGINAL_UNCHANGED=' + str(report['originalUnchanged']))
