import { useEffect, useState } from 'react';
import { supabase } from '../../lib/supabase/client';

interface DirectoryContact {
  first_name: string | null;
  last_name: string | null;
  email: string | null;
}

interface DirectoryCustomer {
  id: string;
  company_name: string | null;
  email: string | null;
  city: string | null;
  primary_contact_id: string | null;
  DirectoryContacts: DirectoryContact | null;
}

export default function TestDirectory() {
  const [customers, setCustomers] = useState<DirectoryCustomer[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    async function loadCustomers() {
      try {
        setLoading(true);
        setError(null);

        const { data, error: queryError } = await supabase
          .from('DirectoryCustomers')
          .select(`
            id,
            company_name,
            email,
            city,
            primary_contact_id,
            "DirectoryContacts"!primary_contact_id (
              first_name,
              last_name,
              email
            )
          `)
          .eq('organization_id', '4de856e8-36ce-480a-952b-a2f5083c69d6');

        if (queryError) {
          console.error('Supabase query error:', queryError);
          setError(queryError.message);
          return;
        }

        console.log('✅ Customers loaded:', data);
        setCustomers(data || []);
      } catch (err) {
        console.error('Error loading customers:', err);
        setError(err instanceof Error ? err.message : 'Unknown error');
      } finally {
        setLoading(false);
      }
    }

    loadCustomers();
  }, []);

  if (loading) {
    return (
      <div style={{ padding: 20 }}>
        <h1>Loading Directory Customers...</h1>
      </div>
    );
  }

  if (error) {
    return (
      <div style={{ padding: 20 }}>
        <h1>Error Loading Directory Customers</h1>
        <div style={{ color: 'red', marginTop: 10 }}>
          <strong>Error:</strong> {error}
        </div>
        <details style={{ marginTop: 20 }}>
          <summary>Debug Info</summary>
          <pre style={{ background: '#f5f5f5', padding: 10, marginTop: 10 }}>
            {JSON.stringify({ error }, null, 2)}
          </pre>
        </details>
      </div>
    );
  }

  return (
    <div style={{ padding: 20 }}>
      <h1>Directory Customers Loaded 🚀</h1>
      <p style={{ marginTop: 10, color: '#666' }}>
        Found {customers.length} customers
      </p>
      <div style={{ marginTop: 20 }}>
        <pre style={{ 
          background: '#f5f5f5', 
          padding: 15, 
          borderRadius: 4,
          overflow: 'auto',
          maxHeight: '600px'
        }}>
          {JSON.stringify(customers, null, 2)}
        </pre>
      </div>
    </div>
  );
}

