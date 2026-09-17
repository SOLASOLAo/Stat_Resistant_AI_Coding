"""Run the public PLE simulator against the isolated Common consumer only."""
import hashlib
import json
import os
import shutil
import traceback
from datetime import datetime
import scriptengine as se

work = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..',
                                  'data', 'native-packages', '20260915'))
source = os.path.join(work, 'build-11', 'consumer', 'BppMachineCommon', 'Consumer.project')
target = os.path.join(work, 'common-simulation-05', 'Simulation.project')
report_path = os.path.join(work, 'common-simulation-05.json')
expected = os.path.join(work, 'cpstudio', 'ReferenceProject', 'StationTemplate',
                       'Plc', 'Stat010_V5.11_CtrlX_PLC.project')

def digest(path):
    with open(path, 'rb') as stream:
        return hashlib.sha256(stream.read()).hexdigest().upper()

original = se.projects.primary
if original is None or os.path.normcase(str(original.path)) != os.path.normcase(expected) or original.dirty:
    raise Exception('Expected the clean isolated reference in the sole PLE session')
if os.path.exists(target) or os.path.exists(report_path):
    raise Exception('Simulation evidence is immutable; do not replay')
build = json.load(open(os.path.join(work, 'bpp-build-11.json'), 'rb'))
proof = [c for c in build['checks'] if c['name'] == 'BppMachineCommon' and c['kind'] == 'consumer'][0]
if proof['errorCount'] or digest(source) != proof['outputSha256']:
    raise Exception('Consumer baseline differs from the reviewed fresh build')
original_hash = digest(expected)
report = {'profile': 'ctrlX PLC 2.6.8', 'physicalOperations': False,
          'simulation': False, 'passed': False, 'sourceSha256': digest(source),
          'startedAtUtc': datetime.utcnow().isoformat() + 'Z'}
try:
    os.makedirs(os.path.dirname(target))
    shutil.copy2(source, target)
    original.close()
    p = se.projects.open(target)
    device = [o for o in p.get_children(False) if o.get_name() == 'Device'][0]
    # Keep the task GUID used by the template's generated I/O mapping. Only
    # change the group affinity in the public native export/import format.
    app = p.active_application
    config = [o for o in app.get_children(False) if o.is_task_configuration][0]
    before = os.path.join(os.path.dirname(target), 'TaskConfiguration-before.export')
    adjusted = os.path.join(os.path.dirname(target), 'TaskConfiguration-simulation.export')
    config.export_native(before)
    content = open(before, 'rb').read()
    old = b'<Single Name="Core" Type="int">3</Single>'
    if content.count(old) != 1:
        raise Exception('Expected exactly one hardware task group affinity')
    with open(adjusted, 'wb') as stream:
        stream.write(content.replace(old, b'<Single Name="Core" Type="int">-1</Single>'))
    config.remove()
    app.import_native(adjusted)
    config = [o for o in app.get_children(False) if o.is_task_configuration][0]
    task = [o for o in config.get_children(False) if o.is_task][0]
    config.export_native(os.path.join(os.path.dirname(target), 'TaskConfiguration-after.export'))
    report['simulationTask'] = {'name': task.get_name(), 'interval': task.interval, 'unit': task.interval_unit,
                                'entry': str(task.pous[0]), 'coreBinding': task.core_binding}
    device.set_simulation_mode(True)
    if not device.get_simulation_mode():
        raise Exception('Simulation mode was not enabled; no login attempted')
    report['simulation'] = True
    for category in se.system.get_message_categories(False):
        se.system.clear_messages(category)
    p.clean_all()
    p.active_application.generate_code()
    report['messages'] = [{'severity': str(m.severity), 'text': str(getattr(m, 'text', m))}
        for category in se.system.get_message_categories(True)
        for m in se.system.get_message_objects(category)]
    report['errorCount'] = sum(1 for m in report['messages'] if m['severity'].endswith('Error'))
    report['freshCompile'] = True
    if report['errorCount']:
        raise Exception('Simulator compilation failed; no login attempted')
    p.save()
    # All online API calls below target this verified local simulation only.
    with se.online.create_online_application(p.active_application) as sim:
        if not device.get_simulation_mode() or os.path.normcase(str(p.path)) != os.path.normcase(target):
            raise Exception('Simulator target guard changed')
        try:
            sim.login(se.OnlineChangeOption.Never, False)
            sim.start()
            report['observations'] = []
            for unused in range(40):
                se.system.delay(250)
                values = list(sim.read_values(('PLC_PRG.Done', 'PLC_PRG.PassedChecks', 'PLC_PRG.FailedMask', 'PLC_PRG.Stage')))
                report['observations'].append([str(v) for v in values])
                if str(values[0]).upper() == 'TRUE':
                    break
            report['passed'] = (str(values[0]).upper() == 'TRUE' and str(values[1]) in ('19', 'INT#19')
                                and str(values[2]) in ('0', 'DWORD#0', '16#00000000', 'DWORD#16#00000000'))
        finally:
            if sim.is_logged_in:
                sim.stop()
                sim.logout()
    p.save()
    report['outputSha256'] = digest(target)
    p.close()
except Exception:
    report['error'] = traceback.format_exc()
finally:
    active = se.projects.primary
    if active is not None and os.path.normcase(str(active.path)) == os.path.normcase(target):
        active.close()
    if se.projects.primary is None:
        se.projects.open(expected)
    report['originalUnchanged'] = digest(expected) == original_hash
    report['finishedAtUtc'] = datetime.utcnow().isoformat() + 'Z'
    with open(report_path, 'wb') as stream:
        stream.write(json.dumps(report, indent=2).encode('utf-8'))
    print('COMMON_SIMULATION_REPORT ' + report_path)
