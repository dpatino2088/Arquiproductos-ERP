---
description: Analyze Current Product Against Target Stack & Controls
globs: { alwaysApply: false }
version: 2.0
encoding: UTF-8
---
# Analyze Product
<pre_flight_check>EXECUTE: @.agent-os/instructions/meta/pre-flight.md</pre_flight_check>
<process_flow>
<step number="1" subagent="context-fetcher" name="gather">Inventario de arquitectura, datos y terceros.</step>
<step number="2" subagent="security-analyst" name="gaps">Gap matrix contra baseline.</step>
<step number="3" subagent="performance-analyst" name="budgets">Budgets web/api/db.</step>
<step number="4" subagent="risk-analyst" name="threat">Threat model (STRIDE) mínimo.</step>
</process_flow>
<post_flight_check>EXECUTE: @.agent-os/instructions/meta/post-flight.md</post_flight_check>
