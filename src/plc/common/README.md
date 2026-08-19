# Common PLC POUs

Common POUs must not depend on a Station instance, project event designator or
physical BMK in executable code. Project signals are connected at the caller.

The source format uses `DECLARATION` and `IMPLEMENTATION` markers so an importer
can map both sections to `set_pou_code`. The current files are readable mirrors
of POUs already compiled in Station010; changes here require an explicit MCP
apply/readback/compile cycle before they are considered integrated.

`FB_MaintenanceDoorControl` is project-neutral: the caller supplies both door
feedbacks, the maintenance safety-relay feedback, monitoring times and event
mapping. Its detail fault outputs let each project construct BMK-specific
AdditionalInfo without embedding project designators in the reusable FB.
