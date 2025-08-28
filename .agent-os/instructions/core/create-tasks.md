---
description: Create an Agent OS task plan aligned to our stack
globs: { alwaysApply: false }
version: 2.0
encoding: UTF-8
---
# Create Tasks
<pre_flight_check>EXECUTE: @.agent-os/instructions/meta/pre-flight.md</pre_flight_check>
<process_flow>
<step number="1" subagent="planner" name="epics">Identity, Data Protection, Delivery, Observability, Compliance, Performance.</step>
<step number="2" subagent="planner" name="stories">Historias para React, Laravel, DB, S3, CI/CD.</step>
</process_flow>
<post_flight_check>EXECUTE: @.agent-os/instructions/meta/post-flight.md</post_flight_check>
