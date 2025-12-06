/// <reference types="vite/client" />
// Trusted Types implementation for enhanced XSS protection
import { sanitizeHtml } from './security';

// Extend Window interface for Trusted Types support
declare global {
  interface Window {
    trustedTypes?: {
      createPolicy(name: string, policy: TrustedTypePolicy): TrustedTypePolicy;
      isHTML(value: unknown): boolean;
      isScript(value: unknown): boolean;
      isScriptURL(value: unknown): boolean;
    };
  }
}

interface TrustedTypePolicy {
  createHTML?: (input: string) => string;
  createScript?: (input: string) => string;
  createScriptURL?: (input: string) => string;
}

// TypeScript interfaces for Trusted Types (for reference)
// interface TrustedHTML {
//   toString(): string;
// }

// interface TrustedScript {
//   toString(): string;
// }

// interface TrustedScriptURL {
//   toString(): string;
// }

class TrustedTypesManager {
  private policy: TrustedTypePolicy | null = null;
  private isSupported: boolean;

  constructor() {
    this.isSupported = this.checkSupport();
    if (this.isSupported) {
      this.initializePolicy();
    }
  }

  private checkSupport(): boolean {
    return typeof window !== 'undefined' && 'trustedTypes' in window;
  }

  private initializePolicy() {
    if (!this.isSupported || !window.trustedTypes) return;

    try {
      this.policy = window.trustedTypes.createPolicy('WAPunch-policy', {
        createHTML: (input: string) => this.sanitizeHTML(input),
        createScript: (input: string) => this.sanitizeScript(input),
        createScriptURL: (input: string) => this.sanitizeURL(input),
      });
    } catch (_error) {
      console.warn('Failed to create Trusted Types policy:', _error);
      this.policy = null;
    }
  }

  private sanitizeHTML(input: string): string {
    // Use our existing DOMPurify sanitization
    return sanitizeHtml(input);
  }

  private sanitizeScript(input: string): string {
    // Basic script sanitization - in production, this should be more restrictive
    const sanitized = input
      .replace(/<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/gi, '')
      .replace(/javascript:/gi, '')
      .replace(/on\w+\s*=/gi, '');
    
    console.warn('Script content sanitized:', { original: input, sanitized });
    return sanitized;
  }

  private sanitizeURL(input: string): string {
    try {
      const url = new URL(input, window.location.origin);
      
      // Block dangerous protocols
      if (['javascript:', 'data:', 'vbscript:'].includes(url.protocol)) {
        console.warn('Blocked dangerous URL protocol:', url.protocol);
        return 'about:blank';
      }
      
      return url.href;
    } catch {
      console.warn('Invalid URL provided to sanitizeURL:', input);
      return 'about:blank';
    }
  }

  // Public methods for creating trusted content
  createTrustedHTML(input: string): string {
    if (this.policy && this.policy.createHTML) {
      return this.policy.createHTML(input);
    }
    
    // Fallback to regular sanitization if Trusted Types not supported
    return this.sanitizeHTML(input);
  }

  createTrustedScript(input: string): string {
    if (this.policy && this.policy.createScript) {
      return this.policy.createScript(input);
    }
    
    // Fallback to regular sanitization if Trusted Types not supported
    return this.sanitizeScript(input);
  }

  createTrustedScriptURL(input: string): string {
    if (this.policy && this.policy.createScriptURL) {
      return this.policy.createScriptURL(input);
    }
    
    // Fallback to regular sanitization if Trusted Types not supported
    return this.sanitizeURL(input);
  }

  // Check if content is already trusted
  isTrustedHTML(value: unknown): boolean {
    return this.isSupported && window.trustedTypes?.isHTML(value) || false;
  }

  isTrustedScript(value: unknown): boolean {
    return this.isSupported && window.trustedTypes?.isScript(value) || false;
  }

  isTrustedScriptURL(value: unknown): boolean {
    return this.isSupported && window.trustedTypes?.isScriptURL(value) || false;
  }

  // Safe DOM manipulation methods
  safeSetInnerHTML(element: Element, htmlContent: string): void {
    const trustedHTML = this.createTrustedHTML(htmlContent);
    element.innerHTML = trustedHTML;
  }

  safeSetAttribute(element: Element, attribute: string, value: string): void {
    if (attribute.toLowerCase().startsWith('on')) {
      console.warn('Blocked attempt to set event handler attribute:', attribute);
      return;
    }
    
    if (attribute === 'src' || attribute === 'href') {
      const sanitizedValue = this.createTrustedScriptURL(value);
      element.setAttribute(attribute, sanitizedValue);
    } else {
      element.setAttribute(attribute, value);
    }
  }

  // Utility method to check if Trusted Types is supported
  isSupported_(): boolean {
    return this.isSupported;
  }
}

// Create and export singleton instance
export const trustedTypesManager = new TrustedTypesManager();

// Export utility functions for easier usage
export const createTrustedHTML = (input: string) => trustedTypesManager.createTrustedHTML(input);
export const createTrustedScript = (input: string) => trustedTypesManager.createTrustedScript(input);
export const createTrustedScriptURL = (input: string) => trustedTypesManager.createTrustedScriptURL(input);
export const safeSetInnerHTML = (element: Element, html: string) => trustedTypesManager.safeSetInnerHTML(element, html);
export const safeSetAttribute = (element: Element, attr: string, value: string) => trustedTypesManager.safeSetAttribute(element, attr, value);
