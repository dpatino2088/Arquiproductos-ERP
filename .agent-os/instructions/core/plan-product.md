---
description: Product Planning Rules (Tailored Stack)
globs: { alwaysApply: false }
version: 2.0
encoding: UTF-8
---
# Product Planning
<pre_flight_check>EXECUTE: @.agent-os/instructions/meta/pre-flight.md</pre_flight_check>
<process_flow>
<step number="1" subagent="planner" name="mission">Definir misión, SLAs, cumplimiento.</step>
<step number="2" subagent="architect" name="ref-arch">CloudFront+S3(OAC), WAF, ALB→ECS, Aurora/RDS, Endpoints, Secrets, KMS.</step>
<step number="3" subagent="architect" name="roadmap">Roadmap por fases y DR/RTO.</step>
</process_flow>
<post_flight_check>EXECUTE: @.agent-os/instructions/meta/post-flight.md</post_flight_check>
