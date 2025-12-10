export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[];

export interface Database {
  public: {
    Tables: {
      Companies: {
        Row: {
          id: string;
          name: string;
          deleted: boolean;
          archived: boolean;
          created_date: string;
          modified_date: string;
          creator: string | null;
          modifier: string | null;
        };
        Insert: {
          id?: string;
          name: string;
          deleted?: boolean;
          archived?: boolean;
          created_date?: string;
          modified_date?: string;
          creator?: string | null;
          modifier?: string | null;
        };
        Update: Partial<Database['public']['Tables']['Companies']['Insert']>;
      };
      UserProfiles: {
        Row: {
          id: string;
          company_id: string;
          first_name: string;
          last_name: string;
          role: string;
          deleted: boolean;
          archived: boolean;
          created_date: string;
          modified_date: string;
          creator: string | null;
          modifier: string | null;
        };
        Insert: {
          id: string;
          company_id: string;
          first_name: string;
          last_name: string;
          role: string;
          deleted?: boolean;
          archived?: boolean;
          created_date?: string;
          modified_date?: string;
          creator?: string | null;
          modifier?: string | null;
        };
        Update: Partial<Database['public']['Tables']['UserProfiles']['Insert']>;
      };
    };
  };
}

