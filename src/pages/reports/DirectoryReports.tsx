import { useEffect, useState } from 'react';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { useContacts } from '../../hooks/useDirectory';
import { Contact, Building } from 'lucide-react';

export default function DirectoryReports() {
  const { registerSubmodules } = useSubmoduleNav();
  const { contacts, loading, error } = useContacts();
  const [selectedType, setSelectedType] = useState<'all' | 'customer'>('all');

  useEffect(() => {
    registerSubmodules('Reports', []);
  }, [registerSubmodules]);

  const filteredContacts = contacts.filter(contact => {
    if (selectedType === 'all') return true;
    // All contacts belong to customers now, so 'customer' filter shows all
    if (selectedType === 'customer') return true;
    return true;
  });

  const customerCount = contacts.length;

  if (loading) {
    return (
      <div className="flex items-center justify-center min-h-[400px]">
        <div className="text-center">
          <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary mx-auto mb-4"></div>
          <p className="text-sm text-gray-600">Loading directory reports...</p>
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="flex items-center justify-center min-h-[400px]">
        <div className="text-center">
          <p className="text-sm text-red-600 mb-4">Error loading directory: {error}</p>
        </div>
      </div>
    );
  }

  return (
    <div className="p-6">
      <div className="mb-6">
        <h1 className="text-xl font-semibold text-foreground mb-1">Directory Reports</h1>
        <p className="text-xs" style={{ color: 'var(--gray-500)' }}>
          View and analyze your directory data
        </p>
      </div>

      {/* Summary Cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mb-6">
        <div className="bg-white border border-gray-200 rounded-lg p-4">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-gray-600 mb-1">Total Contacts</p>
              <p className="text-2xl font-semibold text-gray-900">{contacts.length}</p>
            </div>
            <Contact className="w-8 h-8 text-primary" />
          </div>
        </div>
        <div className="bg-white border border-gray-200 rounded-lg p-4">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-gray-600 mb-1">Customer Contacts</p>
              <p className="text-2xl font-semibold text-gray-900">{customerCount}</p>
            </div>
            <Building className="w-8 h-8 text-green-500" />
          </div>
        </div>
      </div>

      {/* Filter Tabs */}
      <div className="mb-4 border-b border-gray-200">
        <div className="flex gap-4">
          <button
            onClick={() => setSelectedType('all')}
            className={`pb-2 px-1 text-sm font-medium transition-colors ${
              selectedType === 'all'
                ? 'border-b-2 border-primary text-primary'
                : 'text-gray-600 hover:text-gray-900'
            }`}
          >
            All ({contacts.length})
          </button>
          <button
            onClick={() => setSelectedType('customer')}
            className={`pb-2 px-1 text-sm font-medium transition-colors ${
              selectedType === 'customer'
                ? 'border-b-2 border-primary text-primary'
                : 'text-gray-600 hover:text-gray-900'
            }`}
          >
            Customer ({customerCount})
          </button>
        </div>
      </div>

      {/* Contacts Table */}
      <div className="bg-white border border-gray-200 rounded-lg overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full">
            <thead className="bg-gray-50 border-b border-gray-200">
              <tr>
                <th className="px-4 py-3 text-left text-xs font-semibold text-gray-700 uppercase">Type</th>
                <th className="px-4 py-3 text-left text-xs font-semibold text-gray-700 uppercase">Name</th>
                <th className="px-4 py-3 text-left text-xs font-semibold text-gray-700 uppercase">Email</th>
                <th className="px-4 py-3 text-left text-xs font-semibold text-gray-700 uppercase">Phone</th>
                <th className="px-4 py-3 text-left text-xs font-semibold text-gray-700 uppercase">Location</th>
                <th className="px-4 py-3 text-left text-xs font-semibold text-gray-700 uppercase">Status</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-200">
              {filteredContacts.length === 0 ? (
                <tr>
                  <td colSpan={6} className="px-4 py-8 text-center text-gray-500">
                    No contacts found
                  </td>
                </tr>
              ) : (
                filteredContacts.map((contact) => (
                  <tr key={contact.id} className="hover:bg-gray-50">
                    <td className="px-4 py-3">
                      <span className="inline-flex items-center gap-1 px-2 py-1 rounded text-xs font-medium bg-blue-50 text-blue-700">
                        <Contact className="w-3 h-3" />
                        {contact.category}
                      </span>
                    </td>
                    <td className="px-4 py-3 text-sm text-gray-900">
                      {contact.firstName} {contact.lastName}
                      {contact.company && ` - ${contact.company}`}
                    </td>
                    <td className="px-4 py-3 text-sm text-gray-600">{contact.email || 'N/A'}</td>
                    <td className="px-4 py-3 text-sm text-gray-600">{contact.phone || 'N/A'}</td>
                    <td className="px-4 py-3 text-sm text-gray-600">{contact.location}</td>
                    <td className="px-4 py-3">
                      <span className={`px-2 py-1 rounded text-xs font-medium ${
                        contact.status === 'Active'
                          ? 'bg-green-50 text-green-700'
                          : contact.status === 'Archived'
                          ? 'bg-purple-50 text-purple-700'
                          : 'bg-gray-50 text-gray-700'
                      }`}>
                        {contact.status}
                      </span>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}

