"""One reviewed Station010 migration via public ScriptEngine, offline only.

Inject MIGRATION_PLAN and MIGRATION_RECEIPT absolute paths before execfile.
Every affected object and each retired subtree is checked before the first write.
No online API, library generation, graph edits or generated-region edits.
"""
import hashlib
import json
import os
from datetime import datetime
import scriptengine as se


def normalized(text):
    return text.replace('\r\n', '\n').replace('\r', '\n').strip() + '\n'


def digest(path):
    with open(path, 'rb') as stream:
        return hashlib.sha256(stream.read()).hexdigest()


with open(MIGRATION_PLAN, 'rb') as stream:
    plan = json.loads(stream.read().decode('utf-8-sig'))
with open(os.path.join(plan['snapshot'], 'manifest.json'), 'rb') as stream:
    snapshot = json.loads(stream.read().decode('utf-8-sig'))
project = se.projects.primary
if project is None or os.path.normcase(project.path) != os.path.normcase(plan['project']):
    raise Exception('Wrong primary project')
if project.dirty:
    raise Exception('Unsaved project changes; inspect before applying')
if digest(project.path) != snapshot['sourceProjectSha256']:
    raise Exception('Project changed since the reviewed native-export snapshot')
if os.path.exists(MIGRATION_RECEIPT):
    raise Exception('Receipt exists. Inspect state; do not replay this migration.')
app = project.active_application


def locate(path):
    parts = path.split('/')
    if parts.pop(0) != 'Application':
        raise Exception('Not an application object')
    obj = app
    for name in parts:
        candidates = [c for c in obj.get_children(False) if c.get_name() == name]
        if len(candidates) != 1:
            raise Exception('Expected one native object: ' + path)
        obj = candidates[0]
    return obj


def check(obj, expected, path):
    for key in ('declaration', 'implementation'):
        if expected[key] is not None:
            text = getattr(obj, 'textual_' + key).text
            if normalized(text) != normalized(expected[key]):
                raise Exception('Object changed: ' + path + ' / ' + key)


for change in plan['changes']:
    check(locate(change['path']), change['before'], change['path'])
for group in plan['removals']:
    for obj in group['objects']:
        check(locate(obj['path']), obj, obj['path'])
print('PREFLIGHT_OK changes=%d retiredRoots=%d' % (len(plan['changes']), len(plan['removals'])))

receipt = {'planSha256': digest(MIGRATION_PLAN), 'project': project.path,
           'startedAtUtc': datetime.utcnow().isoformat() + 'Z',
           'onlineOperations': False, 'changed': [], 'retired': [], 'saved': False}
try:
    for change in plan['changes']:
        obj = locate(change['path'])
        for key in ('declaration', 'implementation'):
            if change['before'][key] != change['after'][key]:
                getattr(obj, 'textual_' + key).replace(change['after'][key])
        check(obj, change['after'], change['path'])
        receipt['changed'].append(change['path'])
    for group in plan['removals']:
        locate(group['path']).remove()
        receipt['retired'].append(group['path'])
    for change in plan['changes']:
        check(locate(change['path']), change['after'], change['path'])
    project.save()
    receipt['saved'] = True
    receipt['readbackVerified'] = True
    receipt['projectSha256'] = digest(project.path)
finally:
    receipt['completedAtUtc'] = datetime.utcnow().isoformat() + 'Z'
    with open(MIGRATION_RECEIPT, 'wb') as stream:
        stream.write(json.dumps(receipt, indent=2).encode('utf-8'))
print('STATION_NATIVE_MIGRATION_SAVED')
