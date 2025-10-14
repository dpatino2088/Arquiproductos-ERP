import { z } from 'zod';

// Email validation schema
export const emailSchema = z.string().email('Invalid email format');

// Password validation schema
export const passwordSchema = z.string()
  .min(8, 'Password must be at least 8 characters')
  .regex(/[A-Z]/, 'Password must contain at least one uppercase letter')
  .regex(/[a-z]/, 'Password must contain at least one lowercase letter')
  .regex(/[0-9]/, 'Password must contain at least one number')
  .regex(/[^A-Za-z0-9]/, 'Password must contain at least one special character');


// User profile schema
export const userProfileSchema = z.object({
  name: z.string().min(2, 'Name must be at least 2 characters'),
  email: emailSchema,
  phone: z.string().regex(/^\+?[\d\s\-()]+$/, 'Invalid phone number').optional(),
  department: z.string().optional(),
  position: z.string().optional(),
});

// Search schema
export const searchSchema = z.object({
  query: z.string().min(1, 'Search query is required').max(100, 'Search query too long'),
  filters: z.array(z.string()).optional(),
});

// Export type definitions
export type UserProfileData = z.infer<typeof userProfileSchema>;
export type SearchData = z.infer<typeof searchSchema>;
