---
description: Rules to initiate and manage execution (Feature)
globs: { alwaysApply: false }
version: 2.0
encoding: UTF-8
---
# Execute Tasks
<pre_flight_check>EXECUTE: @.agent-os/instructions/meta/pre-flight.md</pre_flight_check>
<process_flow>
<step number="1" subagent="developer" name="impl">React TS + Tailwind; Laravel 8.3+; RLS; S3 presigned.</step>
<step number="2" subagent="ci" name="gates">Lint+Type+Tests+SAST+SCA+Load budgets.</step>
<step number="3" subagent="devops" name="deploy">OIDC deploy; rolling/canary; WAF/Config checks.</step>
</process_flow>
<post_flight_check>EXECUTE: @.agent-os/instructions/meta/post-flight.md</post_flight_check>
