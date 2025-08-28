# Standard: Advanced Security

## Overview

Implement advanced security measures including Content Security Policy, Trusted Types, Subresource Integrity, and sandboxed iframes to protect against sophisticated attacks.

## Core Requirements

### 1. Content Security Policy (CSP)

- Implement strict CSP headers
- Restrict script execution sources
- Control resource loading
- Monitor CSP violations

### 2. Trusted Types

- Implement Trusted Types for DOM manipulation
- Sanitize user input before DOM insertion
- Prevent XSS through type safety
- Use DOMPurify with Trusted Types

### 3. Subresource Integrity (SRI)

- Implement SRI for external resources
- Verify resource integrity
- Prevent resource tampering
- Monitor SRI failures

### 4. Sandboxed Iframes

- Implement iframe sandboxing
- Restrict iframe capabilities
- Control cross-origin communication
- Prevent clickjacking attacks

## Implementation Guidelines

### Content Security Policy

```typescript
// CSP configuration
const cspConfig = {
  "default-src": ["'self'"],
  "script-src": ["'self'", "'unsafe-inline'"],
  "style-src": ["'self'", "'unsafe-inline'"],
  "img-src": ["'self'", "data:", "https:"],
  "connect-src": ["'self'", "https://api.example.com"],
  "frame-src": ["'none'"],
  "object-src": ["'none'"],
  "base-uri": ["'self'"],
  "form-action": ["'self'"],
};

// Apply CSP headers
app.use((req, res, next) => {
  const cspHeader = Object.entries(cspConfig)
    .map(([key, values]) => `${key} ${values.join(" ")}`)
    .join("; ");

  res.setHeader("Content-Security-Policy", cspHeader);
  next();
});
```

### Trusted Types Implementation

```typescript
// Trusted Types setup
if (window.trustedTypes && window.trustedTypes.createPolicy) {
  const policy = window.trustedTypes.createPolicy("default", {
    createHTML: (string) => DOMPurify.sanitize(string),
    createScriptURL: (string) => string,
    createScript: (string) => string,
  });

  // Use Trusted Types for DOM manipulation
  element.innerHTML = policy.createHTML(userInput);
}
```

### Subresource Integrity

```html
<!-- SRI implementation -->
<script
  src="https://cdn.example.com/script.js"
  integrity="sha384-abc123..."
  crossorigin="anonymous"
></script>

<link
  rel="stylesheet"
  href="https://cdn.example.com/style.css"
  integrity="sha384-def456..."
  crossorigin="anonymous"
/>
```

### Iframe Sandboxing

```typescript
// Sandboxed iframe component
interface SandboxedIframeProps {
  src: string;
  title: string;
  sandbox?: string[];
}

export function SandboxedIframe({
  src,
  title,
  sandbox = ["allow-scripts", "allow-same-origin"],
}: SandboxedIframeProps) {
  return (
    <iframe
      src={src}
      title={title}
      sandbox={sandbox.join(" ")}
      loading="lazy"
      referrerPolicy="no-referrer"
    />
  );
}
```

## Security Headers

```typescript
// Security headers configuration
const securityHeaders = {
  "X-Content-Type-Options": "nosniff",
  "X-Frame-Options": "DENY",
  "X-XSS-Protection": "1; mode=block",
  "Referrer-Policy": "strict-origin-when-cross-origin",
  "Permissions-Policy": "geolocation=(), microphone=(), camera=()",
  "Strict-Transport-Security": "max-age=31536000; includeSubDomains",
};
```

## Security Monitoring

```typescript
// CSP violation monitoring
document.addEventListener("securitypolicyviolation", (event) => {
  console.error("CSP Violation:", {
    violatedDirective: event.violatedDirective,
    blockedURI: event.blockedURI,
    sourceFile: event.sourceFile,
    lineNumber: event.lineNumber,
  });

  // Send to monitoring service
  reportSecurityViolation(event);
});
```

## Best Practices

- Implement CSP in report-only mode first
- Monitor and analyze CSP violations
- Use Trusted Types for all DOM manipulation
- Implement SRI for all external resources
- Regularly audit security headers
- Test security measures in staging environment
