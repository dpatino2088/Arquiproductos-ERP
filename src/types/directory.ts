/**
 * Directory module types
 * Unified model for DirectoryContacts
 */

export interface DirectoryContact {
  id: string;
  organization_id: string;
  contact_type: 'individual' | 'company';
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

