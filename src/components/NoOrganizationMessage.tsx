import { Building2, Mail, AlertCircle, Plus } from 'lucide-react';
import { useAuthStore } from '../stores/auth-store';
import { router } from '../lib/router';

export function NoOrganizationMessage() {
  const { user } = useAuthStore();

  return (
    <div className="flex items-center justify-center min-h-[60vh] p-6">
      <div className="max-w-md w-full text-center">
        <div className="mb-6">
          <Building2 className="w-16 h-16 text-gray-400 mx-auto mb-4" />
          <h2 className="text-2xl font-semibold text-gray-900 mb-2">
            No Organization Access
          </h2>
          <p className="text-gray-600">
            Your account is not associated with any organization yet.
          </p>
        </div>

        <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-4 mb-6">
          <div className="flex items-start gap-3">
            <AlertCircle className="w-5 h-5 text-yellow-600 flex-shrink-0 mt-0.5" />
            <div className="text-left">
              <p className="text-sm font-medium text-yellow-800 mb-1">
                What to do next?
              </p>
              <ul className="text-sm text-yellow-700 space-y-1 list-disc list-inside">
                <li>Contact your administrator to be added to an organization</li>
                <li>Wait for an invitation email if you've been invited</li>
                <li>If you're a superadmin, you can create a new organization</li>
              </ul>
            </div>
          </div>
        </div>

        <div className="space-y-3">
          <button
            onClick={() => router.navigate('/organizations/manage')}
            className="w-full px-4 py-2 bg-primary text-white rounded-md hover:bg-primary/90 transition-colors flex items-center justify-center gap-2"
            style={{ backgroundColor: 'var(--primary-brand-hex)' }}
          >
            <Plus className="w-4 h-4" />
            Manage Organizations
          </button>
          
          <a
            href={`mailto:support@example.com?subject=Organization Access Request&body=Hi, I need to be added to an organization. My email is: ${user?.email || ''}`}
            className="block w-full px-4 py-2 border border-gray-300 text-gray-700 rounded-md hover:bg-gray-50 transition-colors flex items-center justify-center gap-2"
          >
            <Mail className="w-4 h-4" />
            Contact Administrator
          </a>
        </div>
      </div>
    </div>
  );
}

