---
description: Rules to execute a single task securely and efficiently
globs: { alwaysApply: false }
version: 2.0
encoding: UTF-8
---
# Execute Task
<pre_flight_check>EXECUTE: @.agent-os/instructions/meta/pre-flight.md</pre_flight_check>
<process_flow>
<step number="1" subagent="developer" name="prepare">Revisar AC y alcance de datos.</step>
<step number="2" subagent="developer" name="code">Parametrizar queries; validar/sanitizar; idempotencia.</step>
<step number="3" subagent="developer" name="tests">Pruebas unitarias/integración; RLS y headers.</step>
<step number="4" subagent="developer" name="docs">Actualizar OpenAPI/ERD/runbooks.</step>
</process_flow>
<post_flight_check>EXECUTE: @.agent-os/instructions/meta/post-flight.md</post_flight_check>
