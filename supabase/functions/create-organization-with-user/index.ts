// Supabase Edge Function: Create Organization with User
// This function creates a new Organization and a corresponding Auth user
// Returns the organization data and a temporary password (only on creation)

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

// Generate temporary password (10-12 characters)
function generateTemporaryPassword(): string {
  const base = Math.random().toString(36).slice(-8);
  const uppercase = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  const lowercase = 'abcdefghijklmnopqrstuvwxyz';
  const numbers = '0123456789';
  const symbols = '!@#$%^&*';
  
  const randomUpper = uppercase[Math.floor(Math.random() * uppercase.length)];
  const randomLower = lowercase[Math.floor(Math.random() * lowercase.length)];
  const randomNumber = numbers[Math.floor(Math.random() * numbers.length)];
  const randomSymbol = symbols[Math.floor(Math.random() * symbols.length)];
  
  const password = randomSymbol + randomUpper + randomLower + randomNumber + base;
  return password.split('').sort(() => Math.random() - 0.5).join('');
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (req.method !== 'POST') {
    return new Response(
      JSON.stringify({ error: 'Method not allowed' }),
      {
        status: 405,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  }

  try {
    // Get the service role key from environment
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';

    if (!supabaseUrl || !supabaseServiceKey) {
      throw new Error('Missing Supabase environment variables');
    }

    // Create admin client with service role key
    const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey, {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
    });

    // Create regular client for organization operations
    const supabaseClient = createClient(supabaseUrl, supabaseServiceKey);

    // Parse request body
    const {
      organizationId, // null for new, existing ID for update
      organizationData,
    } = await req.json();

    if (!organizationData) {
      return new Response(
        JSON.stringify({ error: 'Missing organizationData' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      );
    }

    const { main_email } = organizationData;
    if (!main_email) {
      return new Response(
        JSON.stringify({ error: 'main_email is required' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      );
    }

    console.log('Processing organization:', { organizationId: organizationId || 'NEW', main_email });

    // 1) Upsert Organization
    const now = new Date().toISOString();
    let savedOrganization;

    if (organizationId) {
      // Update existing organization
      console.log('Updating existing organization:', organizationId);
      const { data, error } = await supabaseClient
        .from('Organizations')
        .update({
          ...organizationData,
          updated_at: now,
        })
        .eq('id', organizationId)
        .select()
        .single();

      if (error) {
        console.error('Error updating organization:', error);
        throw error;
      }

      savedOrganization = data;
    } else {
      // Insert new organization
      console.log('Creating new organization');
      const { data, error } = await supabaseClient
        .from('Organizations')
        .insert({
          ...organizationData,
          created_at: now,
          updated_at: now,
        })
        .select()
        .single();

      if (error) {
        console.error('Error creating organization:', error);
        throw error;
      }

      savedOrganization = data;
    }

    if (!savedOrganization) {
      throw new Error('Failed to save organization');
    }

    console.log('Organization saved:', savedOrganization.id);

    // 2) Check if owner_user_id already exists
    let initialPassword: string | undefined = undefined;
    let userCreationError: string | undefined = undefined;

    if (savedOrganization.owner_user_id) {
      console.log('Organization already has owner_user_id, skipping user creation');
    } else {
      // 3) Create auth user for new organization
      try {
        console.log('Creating auth user for organization owner...');
        
        const temporaryPassword = generateTemporaryPassword();
        
        const { data: authData, error: authError } = await supabaseAdmin.auth.admin.createUser({
          email: main_email,
          password: temporaryPassword,
          email_confirm: true, // Auto-confirm email
          user_metadata: {
            global_role: 'org_user',
            default_organization_id: savedOrganization.id,
          },
        });

        if (authError) {
          console.error('Error creating auth user:', authError);
          userCreationError = authError.message;
          // Don't throw - organization is already created
        } else if (authData?.user) {
          const ownerUserId = authData.user.id;
          console.log('Auth user created successfully:', ownerUserId);

          // Update organization with owner_user_id
          const { error: updateError } = await supabaseClient
            .from('Organizations')
            .update({ owner_user_id: ownerUserId })
            .eq('id', savedOrganization.id);

          if (updateError) {
            console.error('Error updating organization with owner_user_id:', updateError);
            userCreationError = 'User created but failed to link to organization';
          } else {
            savedOrganization.owner_user_id = ownerUserId;
            
            // Create OrganizationUsers entry for the owner
            // Check if entry already exists (to avoid duplicates)
            const { data: existingOrgUser } = await supabaseClient
              .from('OrganizationUsers')
              .select('id')
              .eq('organization_id', savedOrganization.id)
              .eq('user_id', ownerUserId)
              .eq('deleted', false)
              .single();

            if (!existingOrgUser) {
              const { error: orgUserError } = await supabaseClient
                .from('OrganizationUsers')
                .insert({
                  organization_id: savedOrganization.id,
                  user_id: ownerUserId,
                  role: 'owner',
                  invited_by: null, // Owner is not invited by anyone
                  deleted: false,
                });

              if (orgUserError) {
                console.error('Error creating OrganizationUsers entry:', orgUserError);
                // Don't fail the whole operation, just log the error
                userCreationError = userCreationError || 'User created but failed to add to organization users';
              } else {
                console.log('OrganizationUsers entry created for owner');
              }
            } else {
              console.log('OrganizationUsers entry already exists for owner');
            }
            
            initialPassword = temporaryPassword;
            console.log('Organization updated with owner_user_id');
          }
        }
      } catch (userErr: any) {
        console.error('Exception creating auth user:', userErr);
        userCreationError = userErr.message || 'Failed to create user account';
        // Organization is already created, so we continue
      }
    }

    // 4) Return response
    return new Response(
      JSON.stringify({
        success: true,
        organization: savedOrganization,
        initialPassword, // Only present when user was created
        userCreationError, // Only present if user creation failed
      }),
      {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  } catch (error: any) {
    console.error('Error in create-organization-with-user function:', error);
    return new Response(
      JSON.stringify({
        error: error.message || 'Internal server error',
        details: error.toString(),
      }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  }
});

