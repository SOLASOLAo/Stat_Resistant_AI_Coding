"""Select the unpacked offline reference in the existing PLE session."""
import json
import os
import shutil
import scriptengine as se

root = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..',
                                  'data', 'native-packages', '20260915'))
relative = os.path.join('StationTemplate', 'Plc', 'Stat010_V5.11_CtrlX_PLC.project')
target = os.path.join(root, 'reinstalled-reference', relative)
allowed = [target, os.path.join(root, 'cpstudio', 'ReferenceProject', relative)]
project = se.projects.primary
if project is not None:
    if os.path.normcase(os.path.abspath(str(project.path))) not in [
            os.path.normcase(path) for path in allowed]:
        raise Exception('The active project is outside the two isolated references')
    if project.dirty:
        raise Exception('Save the active isolated reference before switching')
    project.close()
backup = os.path.join(root, 'icons-naming', 'before-export.project')
if not os.path.exists(backup):
    shutil.copy2(target, backup)
project = se.projects.open(target, primary=True)
if os.path.normcase(str(project.path)) != os.path.normcase(target):
    raise Exception('Unexpected opened project')
with open(os.path.join(root, 'icons-naming', 'opened-reference.json'), 'wb') as stream:
    stream.write(json.dumps({'path': str(project.path), 'dirty': bool(project.dirty),
                             'physicalOperations': False}, indent=2).encode('utf-8'))
print('OPENED_OFFLINE_REFERENCE ' + str(project.path))
