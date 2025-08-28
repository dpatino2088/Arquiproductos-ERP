# Standard: Forms

## Overview

Implement forms using React Hook Form with Zod validation, ensuring proper form state management and user experience.

## Core Requirements

### 1. Form Library

- Use React Hook Form for form state management
- Implement Zod for schema validation
- Use @hookform/resolvers for integration
- Implement proper error handling

### 2. Validation

- Define validation schemas with Zod
- Implement client-side validation
- Provide clear error messages
- Handle validation errors gracefully

### 3. Form State

- Manage form loading states
- Handle form submission properly
- Implement proper error states
- Manage form reset functionality

## Implementation Guidelines

### Form Setup

```typescript
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";

const formSchema = z.object({
  email: z.string().email("Invalid email"),
  password: z.string().min(6, "Password too short"),
});

type FormData = z.infer<typeof formSchema>;

const form = useForm<FormData>({
  resolver: zodResolver(formSchema),
  defaultValues: {
    email: "",
    password: "",
  },
});
```

### Form Submission

```typescript
const onSubmit = async (data: FormData) => {
  try {
    setLoading(true);
    await loginUser(data);
    navigate("/dashboard");
  } catch (error) {
    setError("root", { message: "Login failed" });
  } finally {
    setLoading(false);
  }
};
```

### Error Handling

```typescript
// Display field errors
{
  form.formState.errors.email && (
    <span className="text-red-500">{form.formState.errors.email.message}</span>
  );
}

// Display form errors
{
  form.formState.errors.root && (
    <div className="text-red-500">{form.formState.errors.root.message}</div>
  );
}
```

## Best Practices

- Always validate forms on both client and server
- Provide clear error messages
- Implement proper loading states
- Handle form submission errors gracefully
- Use TypeScript for type safety
