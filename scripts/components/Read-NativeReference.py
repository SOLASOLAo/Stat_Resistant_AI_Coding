"""Fresh offline build and public Symbol API audit of the isolated reference."""
import os
import json
import traceback
import shutil
from datetime import datetime
import scriptengine as se

root = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', 'data', 'native-packages', '20260915'))
expected = [os.path.join(root, base, 'StationTemplate', 'Plc', 'Stat010_V5.11_CtrlX_PLC.project')
            for base in ('cpstudio/ReferenceProject', 'reinstalled-reference')]
p = se.projects.primary
if p is None or os.path.normcase(str(p.path)) not in [os.path.normcase(os.path.normpath(path)) for path in expected]:
    raise Exception('Read-only audit target is not the isolated reference')
stamp = datetime.utcnow().strftime('%Y%m%dT%H%M%S')
report = {'path': str(p.path), 'dirty': bool(p.dirty), 'physicalOperations': False,
          'observedAtUtc': stamp, 'messages': [], 'objects': []}
for category in se.system.get_message_categories(False):
    se.system.clear_messages(category)
p.clean_all()
p.active_application.generate_code()
report['freshCompile'] = True
for category in se.system.get_message_categories(True):
    for m in se.system.get_message_objects(category):
        report['messages'].append({'severity': str(m.severity), 'text': str(getattr(m, 'text', m))})
report['errorCount'] = sum(1 for m in report['messages'] if m['severity'].endswith('Error'))
report['warningCount'] = sum(1 for m in report['messages'] if m['severity'].endswith('Warning'))
for obj in p.active_application.get_children(True):
    if 'Bpp' in obj.get_name() or obj.get_name() in ('TraceInputs', 'ForceTraceReferenceSettings', 'ForceTraceReferenceSignals'):
        item = {'name': obj.get_name()}
        if obj.has_textual_declaration:
            item['declaration'] = obj.textual_declaration.text
        if obj.has_textual_implementation:
            item['implementation'] = obj.textual_implementation.text
        report['objects'].append(item)
try:
    symbol = [o for o in p.active_application.get_children(True) if o.is_symbol_config][0]
    burster_request = os.path.join(root, 'cpstudio', 'burster-symbols.once.json')
    if os.path.exists(burster_request):
        request = json.load(open(burster_request, 'rb'))
        if request != {'Unit': 'BursterResis2316Unit', 'Extension': 'BursterResistomat23161Extension'} or report['errorCount']:
            raise Exception('Unexpected Burster reference symbol request')
        signature = symbol.get_all_signatures(False).find('BursterResistomat23161')
        report['configuredBurster'] = []
        for variable in signature.variables:
            if variable.name not in request or variable.type != request[variable.name]:
                raise Exception('Generated Burster variable changed')
            variable.configured_access = se.SymbolAccess.ReadWriteExecute
            report['configuredBurster'].append(variable.name)
        p.active_application.generate_code()
        p.save()
        os.rename(burster_request, burster_request + '.applied-' + stamp)
    # Only the two inspected, native-generated reference data instances.
    # This bypasses the defective REST transport, not the Symbol access check.
    configure = os.path.join(root, 'cpstudio', 'configure-symbols.once.json')
    if os.path.exists(configure):
        request = json.load(open(configure, 'rb'))
        if request not in ({'Station': 'a', 'Wp100': 'a_1'},
                           {'Station': 'ForceTrace', 'Wp100': 'Trace2'}) or report['errorCount']:
            raise Exception('Unexpected reference symbol request or compile failure')
        p.save()
        backup = os.path.join(root, 'cpstudio', 'before-symbols-' + stamp + '.project')
        if not os.path.exists(backup):
            shutil.copy2(str(p.path), backup)
        signatures = symbol.get_all_signatures(False)
        report['configuredParents'] = []
        for owner, name in request.items():
            signature = signatures.find(owner)
            variable = [v for v in signature.variables if v.name == name][0]
            if variable.type != 'BppForceTraceData':
                raise Exception('Native generated type changed')
            before = str(variable.configured_access)
            variable.configured_access = se.SymbolAccess.Read
            report['configuredParents'].append({'owner': owner, 'name': name, 'before': before,
                                                'after': str(variable.configured_access)})
            old_name = {'Station': 'a', 'Wp100': 'a_1'}[owner]
            if name != old_name:
                for old in list(signature.variables):
                    if old.name == old_name:
                        if old.type != 'BppForceTraceData':
                            raise Exception('Unexpected old reference variable type')
                        old.configured_access = se.SymbolAccess.Void
        for category in se.system.get_message_categories(False):
            se.system.clear_messages(category)
        p.clean_all()
        p.active_application.generate_code()
        p.save()
        os.rename(configure, configure + '.applied-' + stamp)
    report['symbolAccessValues'] = [str(n) for n in dir(se.SymbolAccess) if not str(n).startswith('_')]
    report['signatures'] = []
    for label, read_collection in (('signatures', lambda: symbol.get_all_signatures(False)),
                                   ('datatypes', lambda: symbol.get_all_datatypes(False)),
                                   ('configuredTypes', symbol.get_only_configured_datatypes)):
        try:
            collection = read_collection()
        except Exception:
            report[label + 'Error'] = traceback.format_exc()
            continue
        for sig in collection:
            if sig.full_qualified_name in ('Station', 'Wp100', 'Test') or 'Bpp' in sig.full_qualified_name or 'Burster' in sig.full_qualified_name:
                report['signatures'].append({'collection': label, 'name': sig.full_qualified_name, 'libraryId': str(sig.library_id),
                    'variables': [{'name': v.name, 'type': v.type,
                                   'configured': str(v.configured_access),
                                   'effective': str(v.effective_access),
                                   'maximum': str(v.maximal_access)} for v in sig.variables]})
except Exception:
    report['symbolAuditError'] = traceback.format_exc()
report['applicationExport'] = os.path.join(root, 'cpstudio', 'reference-' + stamp + '.xml')
report['installedCandidateLibraries'] = []
for identity in ('BppBurster2316, 0.1.0.2 (BPP Internal Engineering)',
                 'BppForceTrace, 0.2.0.0 (BPP Internal Engineering)',
                 'BppMachineCommon, 0.1.0.0 (BPP Internal Engineering)'):
    import hashlib
    found = se.librarymanager.find_library(identity)
    library_path = str(se.librarymanager.get_file_path(found[0]))
    report['installedCandidateLibraries'].append({'identity': identity,
        'sha256': hashlib.sha256(open(library_path, 'rb').read()).hexdigest().upper()})
report['messages'] = [{'severity': str(m.severity), 'text': str(getattr(m, 'text', m))}
    for category in se.system.get_message_categories(True)
    for m in se.system.get_message_objects(category)]
report['errorCount'] = sum(1 for m in report['messages'] if m['severity'].endswith('Error'))
report['warningCount'] = sum(1 for m in report['messages'] if m['severity'].endswith('Warning'))
p.active_application.export_xml(path=report['applicationExport'], recursive=True,
                               export_folder_structure=True, declarations_as_plaintext=True)
p.save()
path = os.path.join(root, 'cpstudio', 'reference-' + stamp + '.json')
with open(path, 'wb') as stream:
    stream.write(json.dumps(report, indent=2).encode('utf-8'))
print('READ_ONLY_REFERENCE_AUDIT ' + path)
