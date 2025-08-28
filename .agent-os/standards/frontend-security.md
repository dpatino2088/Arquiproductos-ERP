# Standard: Frontend Security

## Overview

Implement minimum security controls in the frontend to protect against common vulnerabilities and ensure secure data handling.

## Core Requirements

### 1. Input Validation

- Validate all user inputs on the client side
- Implement proper sanitization for HTML content
- Use Zod schemas for form validation
- Prevent XSS attacks through proper encoding

### 2. Authentication Security

- Implement secure token storage
- Handle token refresh securely
- Implement proper logout procedures
- Secure authentication state management

### 3. API Security

- Implement proper CORS handling
- Use HTTPS for all API calls
- Implement request/response validation
- Handle authentication headers securely

### 4. Content Security

- Sanitize HTML content before rendering
- Implement safe content rendering
- Prevent script injection
- Use DOMPurify for content sanitization

## Implementation Guidelines

### Input Sanitization

```typescript
import DOMPurify from "dompurify";

export function sanitizeHtml(html: string): string {
  return DOMPurify.sanitize(html, {
    ALLOWED_TAGS: ["b", "i", "em", "strong", "a", "p", "br"],
    ALLOWED_ATTR: ["href", "target", "rel"],
  });
}
```

### Form Validation

```typescript
import { z } from "zod";

const loginSchema = z.object({
  email: z.string().email("Invalid email"),
  password: z.string().min(6, "Password too short"),
});
```

### Token Security

```typescript
// Store tokens in memory, not localStorage
const authStore = create<AuthStore>((set) => ({
  accessToken: null,
  setToken: (token: string) => set({ accessToken: token }),
  clearToken: () => set({ accessToken: null }),
}));
```

## Security Best Practices

- Never store sensitive data in localStorage
- Always validate and sanitize user input
- Implement proper error handling without information leakage
- Use secure communication protocols
- Implement proper session management
