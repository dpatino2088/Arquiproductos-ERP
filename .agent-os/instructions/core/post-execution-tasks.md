---
description: Rules to finalize a task/feature after deployment
globs: { alwaysApply: false }
version: 2.0
encoding: UTF-8
---
# Post-Execution
<pre_flight_check>EXECUTE: @.agent-os/instructions/meta/pre-flight.md</pre_flight_check>
<process_flow>
<step number="1" subagent="qa-engineer" name="prod">Verificar logs/PII, métricas, WAF.</step>
<step number="2" subagent="security-analyst" name="sec">DAST staging/prod; revisar findings.</step>
<step number="3" subagent="sre" name="runbook">Runbooks, alertas y canarios.</step>
</process_flow>
<post_flight_check>EXECUTE: @.agent-os/instructions/meta/post-flight.md</post_flight_check>
