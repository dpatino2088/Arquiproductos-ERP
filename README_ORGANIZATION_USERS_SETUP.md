# Organization Users Setup Guide

This guide explains how to set up the Organization → Users integration.

## Overview

When an Organization is created or its Main Email is updated, the system will:
1. Create/invite a Supabase Auth user for that email
2. Link the user to the Organization with role 'owner'
3. Send an invitation email to set their password

## Database Setup

### 1. Run the Migration

Execute the migration file to create the necessary tables:

```sql
-- Run this file in your Supabase SQL Editor:
database/migrations/create_users_and_organization_users.sql
```

This creates:
- `Users` table (links to `auth.users`)
- `OrganizationUsers` table (links Users to Organizations with roles)

### 2. Verify Tables

After running the migration, verify the tables exist:
- Go to Supabase Dashboard → Table Editor
- You should see `Users` and `OrganizationUsers` tables

## Supabase Edge Function Setup

### 1. Install Supabase CLI

```bash
npm install -g supabase
```

### 2. Login to Supabase

```bash
supabase login
```

### 3. Link Your Project

```bash
supabase link --project-ref your-project-ref
```

### 4. Deploy the Edge Function

```bash
supabase functions deploy ensure-organization-owner
```

### 5. Set Environment Variables

In your Supabase Dashboard:
1. Go to **Project Settings** → **Edge Functions**
2. Add these secrets:
   - `SUPABASE_URL`: Your Supabase project URL
   - `SUPABASE_SERVICE_ROLE_KEY`: Your service role key (from Settings → API)
   - `SITE_URL`: Your frontend URL (e.g., `https://yourdomain.com` or `http://localhost:5173` for dev)

### 6. Test the Function

You can test the function using curl:

```bash
curl -i --location --request POST 'https://your-project.supabase.co/functions/v1/ensure-organization-owner' \
  --header 'Authorization: Bearer YOUR_ANON_KEY' \
  --header 'Content-Type: application/json' \
  --data '{"organizationId":"uuid-here","mainEmail":"owner@example.com"}'
```

## Frontend Configuration

### Environment Variables

Make sure your `.env.local` file includes:

```env
VITE_SUPABASE_URL=https://your-project.supabase.co
VITE_SUPABASE_ANON_KEY=your-anon-key
```

### How It Works

1. **Organization Save**: When you save an Organization with a `main_email`:
   - The form saves the Organization to the database
   - Then calls the Edge Function to ensure the owner user exists
   - The Edge Function:
     - Checks if a user with that email exists
     - If not, invites them via Supabase Auth
     - Creates/updates the `Users` row
     - Creates/updates the `OrganizationUsers` row with role 'owner'

2. **User Invitation**: The invited user receives an email with a link to set their password

3. **Password Reset**: Users can use "Forgot password?" on the login page

## Roles

The system supports these roles:
- **owner**: Full access, can manage organization and all members
- **admin**: Can manage members and most settings
- **member**: Standard access
- **viewer**: Read-only access

## Row Level Security (RLS)

RLS policies are automatically created:
- Users can read their own profile
- Users can read OrganizationUsers for organizations they belong to
- Only owners/admins can add/update members

## Troubleshooting

### Edge Function Not Working

1. Check that the function is deployed:
   ```bash
   supabase functions list
   ```

2. Check function logs:
   ```bash
   supabase functions logs ensure-organization-owner
   ```

3. Verify environment variables are set in Supabase Dashboard

### User Not Receiving Email

1. Check Supabase Auth settings:
   - Go to **Authentication** → **Email Templates**
   - Verify "Invite user" template is configured

2. Check SMTP settings:
   - Go to **Project Settings** → **Auth** → **SMTP Settings**
   - Configure SMTP if using custom email provider

### RLS Policy Errors

If you get permission errors:
1. Verify RLS is enabled on the tables
2. Check that policies are created correctly
3. Ensure the user is authenticated when making requests

## Next Steps

1. **Access Control**: Implement role-based access in your components
2. **Member Management**: Build UI to add/remove members from organizations
3. **Role Management**: Allow owners/admins to change member roles
4. **Session Management**: Load user's organizations and roles on login

## Security Notes

⚠️ **IMPORTANT**: 
- Never expose the `SUPABASE_SERVICE_ROLE_KEY` in client-side code
- The service role key should ONLY be used in Edge Functions or server-side code
- Always use RLS policies to protect data access

