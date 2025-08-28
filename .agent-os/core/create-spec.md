---
description: Spec Creation Rules with Security & Performance AC
globs: { alwaysApply: false }
version: 2.0
encoding: UTF-8
---
# Create Spec
<pre_flight_check>EXECUTE: @.agent-os/instructions/meta/pre-flight.md</pre_flight_check>
<process_flow>
<step number="1" subagent="context-fetcher" name="spec">Clasificación de datos, AuthZ, OpenAPI, CSP/CORS, validación, RLS y S3.</step>
<step number="2" subagent="qa-engineer" name="ac">AC de seguridad/performance (RLS deny, CSP nonces, WAF on, p95/p75).</step>
</process_flow>
<post_flight_check>EXECUTE: @.agent-os/instructions/meta/post-flight.md</post_flight_check>
