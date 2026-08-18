# Verified OpCon object catalog

The catalog records only interface facts that were checked against local
manuals and/or the compiled Station010 project. It does not copy proprietary
manual text or vendor source code.

Each entry identifies its exact object version, local read-only source path,
commands, important parameters/feedback and integration lifecycle. Unverified
assumptions must be marked `pending`, not promoted to a reusable rule.

When an entry has been used successfully in more than one project, it may be
promoted with the common PLC sources into a separate versioned
`BppAutomationCommon` repository/library.
