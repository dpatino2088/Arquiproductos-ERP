---
description: Common Pre-Flight Steps for Agent OS (Tailored for React + Laravel + PostgreSQL + S3 on AWS)
globs:
  alwaysApply: true
version: 1.1
encoding: UTF-8
---
# Pre-Flight Rules (Security-First)
- Delegar subagentes exactamente como se pide.
- Procesar XML en orden. Baseline: Secrets Manager, OIDC, CloudFront+OAC, WAF, RLS/pgAudit, KMS, VPC Endpoints.


## UI Pre-Flight (must-pass checks)
- Tokens de diseño versionados (colores HSL, tipografía, spacing, radii, sombras).
- Accesibilidad WCAG 2.2 AA: contraste ≥ 4.5:1; foco visible; navegación teclado.
- Theming light/dark con CSS variables + `prefers-color-scheme`.
- CSP con nonces; CORS restringido.
- Presupuestos: LCP p75 ≤ 2.5s; CSS p75 < 70KB gzip.
- Smoke tests de Storybook/Playwright (Modal, Alert, Toast).
