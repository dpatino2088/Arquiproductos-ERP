# Instruction: Advanced Security Setup

## Overview

Implement advanced security features including Content Security Policy (CSP), Trusted Types, Subresource Integrity (SRI), and sandboxed iframes. This setup should provide comprehensive protection against XSS, CSRF, and other security vulnerabilities while maintaining good user experience.

## Core Requirements

### 1. Content Security Policy

- Strict CSP implementation
- Nonce-based script execution
- Hash-based inline styles
- Resource restrictions

### 2. Trusted Types

- Runtime type checking for DOM operations
- Safe HTML sanitization
- Policy enforcement
- Fallback strategies

### 3. Subresource Integrity

- SRI for external resources
- Integrity checking
- Fallback handling
- Monitoring and alerting

### 4. Additional Security

- Sandboxed iframes
- Secure communication
- Security headers
- Vulnerability scanning

## Implementation Steps

### Step 1: Content Security Policy

```typescript
// src/lib/security/csp.ts
interface CSPDirective {
  "default-src"?: string[];
  "script-src"?: string[];
  "style-src"?: string[];
  "img-src"?: string[];
  "font-src"?: string[];
  "connect-src"?: string[];
  "frame-src"?: string[];
  "object-src"?: string[];
  "base-uri"?: string[];
  "form-action"?: string[];
  "frame-ancestors"?: string[];
  "upgrade-insecure-requests"?: boolean;
  "block-all-mixed-content"?: boolean;
}

class CSPManager {
  private policy: CSPDirective;
  private nonces: Map<string, string> = new Map();

  constructor() {
    this.policy = this.getDefaultPolicy();
  }

  private getDefaultPolicy(): CSPDirective {
    return {
      "default-src": ["'self'"],
      "script-src": [
        "'self'",
        "'unsafe-inline'", // Remove in production
        "'unsafe-eval'", // Remove in production
      ],
      "style-src": [
        "'self'",
        "'unsafe-inline'", // Remove in production
        "https://fonts.googleapis.com",
      ],
      "img-src": ["'self'", "data:", "https:"],
      "font-src": ["'self'", "https://fonts.gstatic.com"],
      "connect-src": ["'self'", "https://api.remo.com", "https://sentry.io"],
      "frame-src": ["'self'", "https://www.google.com"],
      "object-src": ["'none'"],
      "base-uri": ["'self'"],
      "form-action": ["'self'"],
      "frame-ancestors": ["'self'"],
      "upgrade-insecure-requests": true,
      "block-all-mixed-content": true,
    };
  }

  generateNonce(type: string): string {
    const nonce = this.generateRandomNonce();
    this.nonces.set(type, nonce);
    return nonce;
  }

  private generateRandomNonce(): string {
    const array = new Uint8Array(16);
    crypto.getRandomValues(array);
    return Array.from(array, (byte) => byte.toString(16).padStart(2, "0")).join(
      ""
    );
  }

  getNonce(type: string): string | undefined {
    return this.nonces.get(type);
  }

  addNonceToPolicy(type: string, nonce: string) {
    if (type === "script") {
      this.policy["script-src"] = this.policy["script-src"] || [];
      this.policy["script-src"].push(`'nonce-${nonce}'`);
    } else if (type === "style") {
      this.policy["style-src"] = this.policy["style-src"] || [];
      this.policy["style-src"].push(`'nonce-${nonce}'`);
    }
  }

  generatePolicyString(): string {
    const directives = [];

    for (const [directive, values] of Object.entries(this.policy)) {
      if (values === true) {
        directives.push(directive);
      } else if (Array.isArray(values)) {
        directives.push(`${directive} ${values.join(" ")}`);
      }
    }

    return directives.join("; ");
  }

  applyPolicy() {
    const policyString = this.generatePolicyString();

    // Apply CSP meta tag
    this.applyMetaTag(policyString);

    // Apply CSP header (if possible)
    this.applyHeader(policyString);
  }

  private applyMetaTag(policy: string) {
    let meta = document.querySelector(
      'meta[http-equiv="Content-Security-Policy"]'
    );
    if (!meta) {
      meta = document.createElement("meta");
      meta.setAttribute("http-equiv", "Content-Security-Policy");
      document.head.appendChild(meta);
    }
    meta.setAttribute("content", policy);
  }

  private applyHeader(policy: string) {
    // In a real application, this would be set by the server
    // For client-side testing, we can use a custom header
    if (typeof window !== "undefined") {
      (window as any).__CSP_POLICY__ = policy;
    }
  }
}

export const cspManager = new CSPManager();

// src/components/SecureScript.tsx
import React from "react";
import { cspManager } from "@/lib/security/csp";

interface SecureScriptProps {
  children: string;
  type?: "text/javascript" | "module";
}

export function SecureScript({
  children,
  type = "text/javascript",
}: SecureScriptProps) {
  const nonce = cspManager.generateNonce("script");

  React.useEffect(() => {
    cspManager.addNonceToPolicy("script", nonce);
    cspManager.applyPolicy();
  }, [nonce]);

  return (
    <script
      type={type}
      nonce={nonce}
      dangerouslySetInnerHTML={{ __html: children }}
    />
  );
}
```

### Step 2: Trusted Types Implementation

```typescript
// src/lib/security/trustedTypes.ts
interface TrustedTypesPolicy {
  name: string;
  createHTML?: (input: string) => string;
  createScript?: (input: string) => string;
  createScriptURL?: (input: string) => string;
}

class TrustedTypesManager {
  private policy: TrustedTypesPolicy | null = null;
  private isSupported: boolean;

  constructor() {
    this.isSupported = this.checkSupport();
    if (this.isSupported) {
      this.initializePolicy();
    }
  }

  private checkSupport(): boolean {
    return typeof window !== "undefined" && "trustedTypes" in window;
  }

  private initializePolicy() {
    if (!this.isSupported) return;

    try {
      this.policy = (window as any).trustedTypes.createPolicy("remo-policy", {
        createHTML: (input: string) => this.sanitizeHTML(input),
        createScript: (input: string) => this.sanitizeScript(input),
        createScriptURL: (input: string) => this.sanitizeURL(input),
      });
    } catch (error) {
      console.warn("Failed to create Trusted Types policy:", error);
      this.policy = null;
    }
  }

  private sanitizeHTML(input: string): string {
    // Basic HTML sanitization
    return input
      .replace(/<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/gi, "")
      .replace(/<iframe\b[^<]*(?:(?!<\/iframe>)<[^<]*)*<\/iframe>/gi, "")
      .replace(/javascript:/gi, "")
      .replace(/on\w+\s*=/gi, "");
  }

  private sanitizeScript(input: string): string {
    // Basic script sanitization
    return input
      .replace(/<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/gi, "")
      .replace(/javascript:/gi, "");
  }

  private sanitizeURL(input: string): string {
    // Basic URL sanitization
    const url = new URL(input, window.location.origin);
    if (url.protocol === "javascript:" || url.protocol === "data:") {
      return "about:blank";
    }
    return url.href;
  }

  createTrustedHTML(input: string): string {
    if (!this.isSupported || !this.policy) {
      return this.sanitizeHTML(input);
    }

    try {
      return this.policy.createHTML!(input);
    } catch (error) {
      console.warn("Trusted Types HTML creation failed:", error);
      return this.sanitizeHTML(input);
    }
  }

  createTrustedScript(input: string): string {
    if (!this.isSupported || !this.policy) {
      return this.sanitizeScript(input);
    }

    try {
      return this.policy.createScript!(input);
    } catch (error) {
      console.warn("Trusted Types script creation failed:", error);
      return this.sanitizeScript(input);
    }
  }

  createTrustedURL(input: string): string {
    if (!this.isSupported || !this.policy) {
      return this.sanitizeURL(input);
    }

    try {
      return this.policy.createScriptURL!(input);
    } catch (error) {
      console.warn("Trusted Types URL creation failed:", error);
      return this.sanitizeURL(input);
    }
  }

  isEnabled(): boolean {
    return this.isSupported && this.policy !== null;
  }
}

export const trustedTypes = new TrustedTypesManager();

// src/components/SafeHtml.tsx
import React from "react";
import { trustedTypes } from "@/lib/security/trustedTypes";

interface SafeHtmlProps {
  html: string;
  className?: string;
  tag?: keyof JSX.IntrinsicElements;
}

export function SafeHtml({ html, className, tag: Tag = "div" }: SafeHtmlProps) {
  const safeHtml = React.useMemo(() => {
    return trustedTypes.createTrustedHTML(html);
  }, [html]);

  return (
    <Tag className={className} dangerouslySetInnerHTML={{ __html: safeHtml }} />
  );
}
```

### Step 3: Subresource Integrity

```typescript
// src/lib/security/sri.ts
interface SRIResource {
  url: string;
  integrity: string;
  crossorigin?: "anonymous" | "use-credentials";
}

class SRIManager {
  private resources: Map<string, SRIResource> = new Map();
  private fallbackUrls: Map<string, string> = new Map();

  addResource(resource: SRIResource) {
    this.resources.set(resource.url, resource);
  }

  addFallback(originalUrl: string, fallbackUrl: string) {
    this.fallbackUrls.set(originalUrl, fallbackUrl);
  }

  async loadScript(url: string): Promise<void> {
    const resource = this.resources.get(url);

    if (!resource) {
      console.warn(`No SRI data for resource: ${url}`);
      return this.loadScriptWithoutSRI(url);
    }

    try {
      await this.loadScriptWithSRI(resource);
    } catch (error) {
      console.warn(`SRI check failed for ${url}:`, error);
      await this.loadScriptFallback(url);
    }
  }

  async loadStylesheet(url: string): Promise<void> {
    const resource = this.resources.get(url);

    if (!resource) {
      console.warn(`No SRI data for resource: ${url}`);
      return this.loadStylesheetWithoutSRI(url);
    }

    try {
      await this.loadStylesheetWithSRI(resource);
    } catch (error) {
      console.warn(`SRI check failed for ${url}:`, error);
      await this.loadStylesheetFallback(url);
    }
  }

  private async loadScriptWithSRI(resource: SRIResource): Promise<void> {
    return new Promise((resolve, reject) => {
      const script = document.createElement("script");
      script.src = resource.url;
      script.integrity = resource.integrity;
      script.crossOrigin = resource.crossorigin || "anonymous";

      script.onload = () => resolve();
      script.onerror = () =>
        reject(new Error(`Failed to load script: ${resource.url}`));

      document.head.appendChild(script);
    });
  }

  private async loadStylesheetWithSRI(resource: SRIResource): Promise<void> {
    return new Promise((resolve, reject) => {
      const link = document.createElement("link");
      link.rel = "stylesheet";
      link.href = resource.url;
      link.integrity = resource.integrity;
      link.crossOrigin = resource.crossorigin || "anonymous";

      link.onload = () => resolve();
      link.onerror = () =>
        reject(new Error(`Failed to load stylesheet: ${resource.url}`));

      document.head.appendChild(link);
    });
  }

  private async loadScriptWithoutSRI(url: string): Promise<void> {
    return new Promise((resolve, reject) => {
      const script = document.createElement("script");
      script.src = url;

      script.onload = () => resolve();
      script.onerror = () => reject(new Error(`Failed to load script: ${url}`));

      document.head.appendChild(script);
    });
  }

  private async loadStylesheetWithoutSRI(url: string): Promise<void> {
    return new Promise((resolve, reject) => {
      const link = document.createElement("link");
      link.rel = "stylesheet";
      link.href = url;

      link.onload = () => resolve();
      link.onerror = () =>
        reject(new Error(`Failed to load stylesheet: ${url}`));

      document.head.appendChild(link);
    });
  }

  private async loadScriptFallback(url: string): Promise<void> {
    const fallbackUrl = this.fallbackUrls.get(url);
    if (fallbackUrl) {
      console.log(`Loading fallback script: ${fallbackUrl}`);
      return this.loadScriptWithoutSRI(fallbackUrl);
    }

    console.error(`No fallback available for script: ${url}`);
    throw new Error(`Failed to load script and no fallback available: ${url}`);
  }

  private async loadStylesheetFallback(url: string): Promise<void> {
    const fallbackUrl = this.fallbackUrls.get(url);
    if (fallbackUrl) {
      console.log(`Loading fallback stylesheet: ${fallbackUrl}`);
      return this.loadStylesheetWithoutSRI(fallbackUrl);
    }

    console.error(`No fallback available for stylesheet: ${url}`);
    throw new Error(
      `Failed to load stylesheet and no fallback available: ${url}`
    );
  }
}

export const sriManager = new SRIManager();

// Initialize with common resources
sriManager.addResource({
  url: "https://cdn.jsdelivr.net/npm/react@18/umd/react.production.min.js",
  integrity: "sha384-...", // Add actual integrity hash
  crossorigin: "anonymous",
});

sriManager.addResource({
  url: "https://cdn.jsdelivr.net/npm/react-dom@18/umd/react-dom.production.min.js",
  integrity: "sha384-...", // Add actual integrity hash
  crossorigin: "anonymous",
});
```

### Step 4: Sandboxed Iframes

```typescript
// src/components/SandboxedIframe.tsx
import React from "react";

interface SandboxedIframeProps {
  src: string;
  title: string;
  width?: string | number;
  height?: string | number;
  allow?: string;
  sandbox?: string[];
  className?: string;
}

export function SandboxedIframe({
  src,
  title,
  width = "100%",
  height = "400px",
  allow,
  sandbox = ["allow-scripts", "allow-same-origin"],
  className,
}: SandboxedIframeProps) {
  const sandboxValue = sandbox.join(" ");

  return (
    <iframe
      src={src}
      title={title}
      width={width}
      height={height}
      allow={allow}
      sandbox={sandboxValue}
      className={className}
      loading="lazy"
      referrerPolicy="no-referrer"
    />
  );
}

// src/components/SecureEmbed.tsx
import React from "react";
import { SandboxedIframe } from "./SandboxedIframe";

interface SecureEmbedProps {
  url: string;
  title: string;
  type: "iframe" | "embed" | "object";
  width?: string | number;
  height?: string | number;
  className?: string;
}

export function SecureEmbed({
  url,
  title,
  type,
  width,
  height,
  className,
}: SecureEmbedProps) {
  if (type === "iframe") {
    return (
      <SandboxedIframe
        src={url}
        title={title}
        width={width}
        height={height}
        className={className}
        sandbox={[
          "allow-scripts",
          "allow-same-origin",
          "allow-forms",
          "allow-popups",
        ]}
      />
    );
  }

  if (type === "embed") {
    return (
      <embed
        src={url}
        title={title}
        width={width}
        height={height}
        className={className}
        type="application/pdf"
      />
    );
  }

  if (type === "object") {
    return (
      <object
        data={url}
        type="application/pdf"
        width={width}
        height={height}
        className={className}
      >
        <p>
          Unable to display content.{" "}
          <a href={url} target="_blank" rel="noopener noreferrer">
            Open in new tab
          </a>
        </p>
      </object>
    );
  }

  return null;
}
```

### Step 5: Security Headers and Monitoring

```typescript
// src/lib/security/headers.ts
interface SecurityHeaders {
  "X-Content-Type-Options": string;
  "X-Frame-Options": string;
  "X-XSS-Protection": string;
  "Referrer-Policy": string;
  "Permissions-Policy": string;
  "Cross-Origin-Embedder-Policy": string;
  "Cross-Origin-Opener-Policy": string;
  "Cross-Origin-Resource-Policy": string;
}

class SecurityHeadersManager {
  private headers: SecurityHeaders = {
    "X-Content-Type-Options": "nosniff",
    "X-Frame-Options": "SAMEORIGIN",
    "X-XSS-Protection": "1; mode=block",
    "Referrer-Policy": "strict-origin-when-cross-origin",
    "Permissions-Policy": "geolocation=(), microphone=(), camera=()",
    "Cross-Origin-Embedder-Policy": "require-corp",
    "Cross-Origin-Opener-Policy": "same-origin",
    "Cross-Origin-Resource-Policy": "same-origin",
  };

  applyHeaders() {
    // In a real application, these headers would be set by the server
    // For client-side testing, we can simulate their presence
    if (typeof window !== "undefined") {
      (window as any).__SECURITY_HEADERS__ = this.headers;
    }
  }

  getHeaders(): SecurityHeaders {
    return { ...this.headers };
  }

  updateHeader(name: keyof SecurityHeaders, value: string) {
    this.headers[name] = value;
  }
}

export const securityHeaders = new SecurityHeadersManager();

// src/lib/security/monitoring.ts
interface SecurityEvent {
  type:
    | "csp-violation"
    | "trusted-types-violation"
    | "sri-failure"
    | "xss-attempt";
  details: Record<string, any>;
  timestamp: string;
  url: string;
  userAgent: string;
}

class SecurityMonitor {
  private events: SecurityEvent[] = [];
  private maxEvents = 1000;

  logEvent(type: SecurityEvent["type"], details: Record<string, any>) {
    const event: SecurityEvent = {
      type,
      details,
      timestamp: new Date().toISOString(),
      url: window.location.href,
      userAgent: navigator.userAgent,
    };

    this.events.push(event);

    // Keep only the last maxEvents
    if (this.events.length > this.maxEvents) {
      this.events = this.events.slice(-this.maxEvents);
    }

    // Send to monitoring service
    this.sendToMonitoringService(event);

    // Log locally
    console.warn("Security event:", event);
  }

  private async sendToMonitoringService(event: SecurityEvent) {
    try {
      await fetch("/api/security/events", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(event),
      });
    } catch (error) {
      console.error("Failed to send security event:", error);
    }
  }

  getEvents(): SecurityEvent[] {
    return [...this.events];
  }

  getEventsByType(type: SecurityEvent["type"]): SecurityEvent[] {
    return this.events.filter((event) => event.type === type);
  }

  clearEvents() {
    this.events = [];
  }
}

export const securityMonitor = new SecurityMonitor();

// Set up CSP violation monitoring
if (typeof window !== "undefined") {
  window.addEventListener("securitypolicyviolation", (event) => {
    securityMonitor.logEvent("csp-violation", {
      violatedDirective: event.violatedDirective,
      blockedURI: event.blockedURI,
      documentURI: event.documentURI,
      sourceFile: event.sourceFile,
      lineNumber: event.lineNumber,
      columnNumber: event.columnNumber,
    });
  });
}
```

## Best Practices

### 1. Content Security Policy

- Start with strict policies
- Use nonces for inline scripts
- Monitor CSP violations
- Test thoroughly before production

### 2. Trusted Types

- Implement comprehensive policies
- Provide fallback sanitization
- Monitor policy violations
- Test with real-world scenarios

### 3. Subresource Integrity

- Generate integrity hashes
- Provide fallback resources
- Monitor SRI failures
- Update hashes when resources change

### 4. Security Monitoring

- Log all security events
- Set up alerts for violations
- Monitor trends over time
- Respond quickly to incidents

## Quality Gates

### 1. CSP Implementation

- CSP headers are properly set
- No unsafe directives in production
- Nonces are properly generated
- Violations are monitored

### 2. Trusted Types

- Policies are comprehensive
- Fallbacks are implemented
- Violations are caught
- Performance impact is minimal

### 3. SRI Implementation

- All external resources have integrity
- Fallbacks are available
- Failures are handled gracefully
- Monitoring is active

### 4. Security Headers

- All security headers are set
- Headers are properly configured
- Monitoring is active
- Violations are logged

## Next Steps

After completing advanced security setup:

1. Set up security monitoring dashboards
2. Implement automated security testing
3. Add security incident response
4. Conduct security audits
5. Set up security training
