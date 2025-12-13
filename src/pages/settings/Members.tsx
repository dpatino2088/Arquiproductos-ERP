import { useState, useEffect } from 'react';
import { useCompanyStore } from '../../stores/company-store';
import { supabase } from '../../lib/supabase/client';
import { Plus, Mail, MoreVertical, X } from 'lucide-react';
import { Select as SelectShadcn, SelectContent, SelectItem, SelectTrigger, SelectValue } from '../../components/ui/SelectShadcn';
import Input from '../../components/ui/Input';
import Label from '../../components/ui/Label';

interface Member {
  id: string;
  user_id: string;
  email: string;
  name: string;
  role: 'super_admin' | 'admin' | 'supervisor' | 'employee';
  status: 'active' | 'invited';
  created_at: string;
}

const ROLES = [
  { value: 'super_admin', label: 'Owner' },
  { value: 'admin', label: 'Admin' },
  { value: 'supervisor', label: 'Supervisor' },
  { value: 'employee', label: 'Employee' },
];

export default function Members() {
  const { currentCompany } = useCompanyStore();
  const [members, setMembers] = useState<Member[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [showInviteModal, setShowInviteModal] = useState(false);
  const [inviteEmail, setInviteEmail] = useState('');
  const [inviteRole, setInviteRole] = useState<'super_admin' | 'admin' | 'supervisor' | 'employee'>('employee');
  const [inviteMessage, setInviteMessage] = useState('');
  const [isInviting, setIsInviting] = useState(false);
  const [editingRole, setEditingRole] = useState<string | null>(null);

  // Load members
  useEffect(() => {
    loadMembers();
  }, [currentCompany?.id]);

  const loadMembers = async () => {
    if (!currentCompany?.id) return;

    setIsLoading(true);
    try {
      // Get company_users
      // Note: We can't directly join auth.users, so we'll get user_id and fetch emails separately if needed
      const { data, error } = await supabase
        .from('company_users')
        .select(`
          id,
          user_id,
          role,
          created_at
        `)
        .eq('company_id', currentCompany.id)
        .eq('is_deleted', false)
        .order('created_at', { ascending: false });

      if (error) {
        console.error('Error loading members:', error);
        return;
      }

      // Transform data to Member format
      // TODO: Fetch user emails from auth.users via a function or store them in a profile table
      // For now, we'll assume all members are 'active' (status field may not exist in company_users)
      const membersData: Member[] = (data || []).map((cu: any) => ({
        id: cu.id,
        user_id: cu.user_id,
        email: `user_${cu.user_id.slice(0, 8)}@example.com`, // Placeholder - needs proper implementation
        name: `User ${cu.user_id.slice(0, 8)}`, // Placeholder - needs proper implementation
        role: cu.role,
        status: 'active' as const, // Default to active - can be enhanced later with invite system
        created_at: cu.created_at,
      }));

      setMembers(membersData);
    } catch (error) {
      console.error('Error loading members:', error);
    } finally {
      setIsLoading(false);
    }
  };

  const handleInvite = async () => {
    if (!currentCompany?.id || !inviteEmail) return;

    setIsInviting(true);
    try {
      // TODO: Implement actual invite logic
      // This would typically:
      // 1. Create an invite record
      // 2. Send an email invitation
      // 3. Add to company_users with status='invited'
      
      console.log('Inviting member:', {
        email: inviteEmail,
        role: inviteRole,
        message: inviteMessage,
        company_id: currentCompany.id,
      });

      // For now, just show success and reset form
      setShowInviteModal(false);
      setInviteEmail('');
      setInviteRole('employee');
      setInviteMessage('');
      
      // Reload members
      await loadMembers();
    } catch (error) {
      console.error('Error inviting member:', error);
    } finally {
      setIsInviting(false);
    }
  };

  const handleRoleChange = async (memberId: string, newRole: 'super_admin' | 'admin' | 'supervisor' | 'employee') => {
    if (!currentCompany?.id) return;

    try {
      const { error } = await supabase
        .from('company_users')
        .update({ role: newRole })
        .eq('id', memberId)
        .eq('company_id', currentCompany.id);

      if (error) {
        console.error('Error updating role:', error);
        return;
      }

      // Update local state
      setMembers(members.map(m => 
        m.id === memberId ? { ...m, role: newRole } : m
      ));
      setEditingRole(null);
    } catch (error) {
      console.error('Error updating role:', error);
    }
  };

  const handleResendInvite = async (memberId: string) => {
    // TODO: Implement resend invite logic
    console.log('Resending invite for member:', memberId);
  };

  const handleRemove = async (memberId: string) => {
    if (!currentCompany?.id || !confirm('Are you sure you want to remove this member?')) return;

    try {
      const { error } = await supabase
        .from('company_users')
        .update({ is_deleted: true })
        .eq('id', memberId)
        .eq('company_id', currentCompany.id);

      if (error) {
        console.error('Error removing member:', error);
        return;
      }

      // Reload members
      await loadMembers();
    } catch (error) {
      console.error('Error removing member:', error);
    }
  };

  if (isLoading) {
    return (
      <div className="bg-white border border-gray-200 rounded-lg p-12 text-center">
        <p className="text-gray-500">Loading members...</p>
      </div>
    );
  }

  return (
    <>
      <div className="bg-white border border-gray-200 rounded-lg overflow-hidden">
        {/* Header with Invite Button */}
        <div className="flex items-center justify-between p-4 border-b border-gray-200">
          <div>
            <h3 className="text-sm font-semibold text-gray-900">Team Members</h3>
            <p className="text-xs text-gray-500 mt-1">{members.length} member{members.length !== 1 ? 's' : ''}</p>
          </div>
          <button
            onClick={() => setShowInviteModal(true)}
            className="flex items-center gap-2 px-3 py-1.5 rounded text-white text-sm hover:opacity-90 transition-colors"
            style={{ backgroundColor: 'var(--primary-brand-hex)' }}
          >
            <Plus style={{ width: '16px', height: '16px' }} />
            Invite member
          </button>
        </div>

        {/* Members Table */}
        <div className="overflow-x-auto">
          <table className="w-full">
            <thead className="bg-gray-50 border-b border-gray-200">
              <tr>
                <th className="text-left px-4 py-3 text-xs font-semibold text-gray-900">Name</th>
                <th className="text-left px-4 py-3 text-xs font-semibold text-gray-900">Email</th>
                <th className="text-left px-4 py-3 text-xs font-semibold text-gray-900">Role</th>
                <th className="text-left px-4 py-3 text-xs font-semibold text-gray-900">Status</th>
                <th className="text-right px-4 py-3 text-xs font-semibold text-gray-900">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-200">
              {members.length === 0 ? (
                <tr>
                  <td colSpan={5} className="px-4 py-8 text-center text-sm text-gray-500">
                    No members found. Invite your first team member to get started.
                  </td>
                </tr>
              ) : (
                members.map((member) => (
                  <tr key={member.id} className="hover:bg-gray-50">
                    <td className="px-4 py-3 text-sm text-gray-900">{member.name}</td>
                    <td className="px-4 py-3 text-sm text-gray-600">{member.email}</td>
                    <td className="px-4 py-3">
                      {editingRole === member.id ? (
                        <SelectShadcn
                          value={member.role}
                          onValueChange={(value) => {
                            handleRoleChange(member.id, value as typeof member.role);
                          }}
                        >
                          <SelectTrigger className="h-8 text-xs w-32">
                            <SelectValue />
                          </SelectTrigger>
                          <SelectContent>
                            {ROLES.map((role) => (
                              <SelectItem key={role.value} value={role.value}>
                                {role.label}
                              </SelectItem>
                            ))}
                          </SelectContent>
                        </SelectShadcn>
                      ) : (
                        <button
                          onClick={() => setEditingRole(member.id)}
                          className="text-sm text-gray-900 hover:text-primary"
                        >
                          {ROLES.find(r => r.value === member.role)?.label || member.role}
                        </button>
                      )}
                    </td>
                    <td className="px-4 py-3">
                      <span className={`inline-flex items-center px-2 py-1 rounded-full text-xs font-medium ${
                        member.status === 'active'
                          ? 'bg-green-100 text-green-800'
                          : 'bg-yellow-100 text-yellow-800'
                      }`}>
                        {member.status === 'active' ? 'Active' : 'Invited'}
                      </span>
                    </td>
                    <td className="px-4 py-3 text-right">
                      <div className="flex items-center justify-end gap-2">
                        {member.status === 'invited' && (
                          <button
                            onClick={() => handleResendInvite(member.id)}
                            className="text-xs text-primary hover:underline"
                          >
                            Resend invite
                          </button>
                        )}
                        <button
                          onClick={() => handleRemove(member.id)}
                          className="text-xs text-red-600 hover:underline"
                        >
                          Remove
                        </button>
                      </div>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* Invite Modal */}
      {showInviteModal && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50">
          <div className="bg-white rounded-lg shadow-xl w-full max-w-md mx-4">
            <div className="flex items-center justify-between p-4 border-b border-gray-200">
              <h3 className="text-lg font-semibold text-gray-900">Invite Member</h3>
              <button
                onClick={() => {
                  setShowInviteModal(false);
                  setInviteEmail('');
                  setInviteRole('employee');
                  setInviteMessage('');
                }}
                className="text-gray-500 hover:text-gray-700"
              >
                <X style={{ width: '20px', height: '20px' }} />
              </button>
            </div>

            <div className="p-6 space-y-4">
              <div>
                <Label htmlFor="invite_email" required>Email</Label>
                <Input
                  id="invite_email"
                  type="email"
                  value={inviteEmail}
                  onChange={(e) => setInviteEmail(e.target.value)}
                  placeholder="colleague@example.com"
                  className="h-10 text-sm"
                />
              </div>

              <div>
                <Label htmlFor="invite_role" required>Role</Label>
                <SelectShadcn
                  value={inviteRole}
                  onValueChange={(value) => setInviteRole(value as typeof inviteRole)}
                >
                  <SelectTrigger className="h-10 text-sm">
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    {ROLES.map((role) => (
                      <SelectItem key={role.value} value={role.value}>
                        {role.label}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </SelectShadcn>
              </div>

              <div>
                <Label htmlFor="invite_message">Message (optional)</Label>
                <textarea
                  id="invite_message"
                  value={inviteMessage}
                  onChange={(e) => setInviteMessage(e.target.value)}
                  placeholder="Add a personal message to the invitation..."
                  className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-primary focus:border-transparent text-sm"
                  rows={3}
                />
              </div>
            </div>

            <div className="flex items-center justify-end gap-3 p-4 border-t border-gray-200">
              <button
                onClick={() => {
                  setShowInviteModal(false);
                  setInviteEmail('');
                  setInviteRole('employee');
                  setInviteMessage('');
                }}
                className="px-4 py-2 border border-gray-300 text-gray-700 rounded-md hover:bg-gray-50 transition-colors"
              >
                Cancel
              </button>
              <button
                onClick={handleInvite}
                disabled={isInviting || !inviteEmail}
                className="px-4 py-2 rounded text-white text-sm hover:opacity-90 transition-colors disabled:opacity-50"
                style={{ backgroundColor: 'var(--primary-brand-hex)' }}
              >
                {isInviting ? 'Sending...' : 'Send Invitation'}
              </button>
            </div>
          </div>
        </div>
      )}
    </>
  );
}

