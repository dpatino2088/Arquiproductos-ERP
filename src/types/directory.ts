/**
 * Directory module types
 * Unified model for DirectoryContacts
 */

// Contact type enum values matching Supabase directory_contact_type
export type DirectoryContactType = 
  | 'architect'
  | 'interior_designer'
  | 'project_manager'
  | 'consultant'
  | 'dealer'
  | 'reseller'
  | 'partner';

export interface DirectoryContact {
  id: string;
  organization_id: string;
  contact_type: DirectoryContactType;
  title_id?: string | null;
  customer_name: string;
  identification_number?: string | null;
  primary_phone?: string | null;
  cell_phone?: string | null;
  alt_phone?: string | null;
  email?: string | null;
  street_address_line_1?: string | null;
  street_address_line_2?: string | null;
  city?: string | null;
  state?: string | null;
  zip_code?: string | null;
  country?: string | null;
  created_at: string;
  updated_at?: string | null;
  deleted: boolean;
  archived: boolean;
}

