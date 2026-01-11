import React, { useState, useEffect, useCallback } from 'react';
import { useCompanies, type Company, type CreateCompanyInput, type UpdateCompanyInput } from '../../hooks/useCompanies';
import { useOrganizationContext } from '../../context/OrganizationContext';
import { useCurrentOrgRole } from '../../hooks/useCurrentOrgRole';
import { useUIStore } from '../../stores/ui-store';
import { useConfirmDialog } from '../../hooks/useConfirmDialog';
import ConfirmDialog from '../../components/ui/ConfirmDialog';
import { supabase } from '../../lib/supabase/client';
import { Building, Plus, X, Edit, Trash2, Mail, Phone, RotateCw, Archive } from 'lucide-react';
import Input from '../../components/ui/Input';
import Label from '../../components/ui/Label';
import { Select as SelectShadcn, SelectContent, SelectItem, SelectTrigger, SelectValue } from '../../components/ui/SelectShadcn';

// StatusBadge component similar to CompanyPortalUsers
interface StatusBadgeProps {
  status: string;
  deleted?: boolean;
}

function StatusBadge({ status, deleted = false }: StatusBadgeProps) {
  // If deleted, show as archived
  if (deleted) {
    return (
      <span className="px-2 py-1 rounded text-xs font-medium bg-gray-100 text-gray-600 border border-gray-300">
        Archived
      </span>
    );
  }

  const normalizedStatus = (status || '').toLowerCase().trim();
  
  const statusColors: Record<string, { bg: string; text: string; border: string; label: string }> = {
    active: { 
      bg: 'bg-green-50', 
      text: 'text-green-700', 
      border: 'border border-green-200',
      label: 'Active'
    },
    disabled: { 
      bg: 'bg-gray-50', 
      text: 'text-gray-700', 
      border: 'border border-gray-200',
      label: 'Disabled'
    }
  };

  const colors = statusColors[normalizedStatus] || statusColors.disabled;

  return (
    <span className={`px-2 py-1 rounded text-xs font-medium ${colors.bg} ${colors.text} ${colors.border}`}>
      {colors.label}
    </span>
  );
}


export default function CompaniesSettings() {
  const { activeOrganizationId } = useOrganizationContext();
  const { isSuperAdmin, isOwner, isAdmin, loading: roleLoading } = useCurrentOrgRole();
  const { addNotification } = useUIStore();
  const { dialogState, showConfirm, closeDialog, handleConfirm } = useConfirmDialog();
  const [isSubmitting, setIsSubmitting] = useState(false);
  
  const { companies, isLoading, error, fetchCompanies, createCompany, updateCompany, archiveCompany } = useCompanies();
  
  
  // Companies list state
  const [showAddModal, setShowAddModal] = useState(false);
  const [editingCompany, setEditingCompany] = useState<Company | null>(null);
  
  // Form state - use 'active', 'disabled', or 'archived' (archived = soft delete)
  const [formData, setFormData] = useState({
    company_name: '',
    company_email: '',
    status: 'active' as 'active' | 'disabled' | 'archived',
  });


  // Handle add company
  const handleAddCompany = async () => {
    if (!formData.company_name.trim()) {
      addNotification({
        type: 'error',
        title: 'Validation error',
        message: 'Company name is required.',
      });
      return;
    }

    if (!activeOrganizationId) {
      addNotification({
        type: 'error',
        title: 'No organization',
        message: 'Please select an organization first.',
      });
      return;
    }

    try {
      setIsSubmitting(true);
      // Handle 'archived' status - should not be set on create, only on update
      const finalStatus = formData.status === 'archived' ? 'active' : formData.status;
      
      const input: CreateCompanyInput = {
        company_name: formData.company_name.trim(),
        company_email: formData.company_email.trim() || undefined,
        status: finalStatus === 'archived' ? 'active' : finalStatus, // Cannot create as archived
      };

      if (import.meta.env.DEV) {
        console.log('[CompaniesSettings] Creating company with input:', input);
      }

      const newCompany = await createCompany(input);
      
      if (import.meta.env.DEV) {
        console.log('[CompaniesSettings] Company created successfully:', newCompany);
      }

      addNotification({
        type: 'success',
        title: 'Company created',
        message: `Company created: ${newCompany.company_no || 'N/A'} - ${newCompany.company_name}`,
      });

      closeModal();
    } catch (err: any) {
      console.error('[CompaniesSettings] Error creating company:', err);
      const errorMessage = err?.message || err?.error?.message || 'Failed to create company.';
      addNotification({
        type: 'error',
        title: 'Error creating company',
        message: errorMessage,
      });
    } finally {
      setIsSubmitting(false);
    }
  };

  // Handle update company
  const handleUpdateCompany = async () => {
    if (!editingCompany || !formData.company_name.trim()) {
      addNotification({
        type: 'error',
        title: 'Validation error',
        message: 'Company name is required.',
      });
      return;
    }

    try {
      setIsSubmitting(true);
      
      // Handle 'archived' status - if archived, do soft delete instead of status update
      if (formData.status === 'archived') {
        await archiveCompany(editingCompany.id);
        addNotification({
          type: 'success',
          title: 'Company archived',
          message: `Company ${editingCompany.company_no || editingCompany.company_name} has been archived.`,
        });
      } else {
        // Normal status update (active or disabled)
        const input: UpdateCompanyInput = {
          company_name: formData.company_name.trim(),
          company_email: formData.company_email.trim() || undefined,
          status: formData.status, // 'active' or 'disabled'
        };

        await updateCompany(editingCompany.id, input);
        
        addNotification({
          type: 'success',
          title: 'Company updated',
          message: `Company ${editingCompany.company_no || editingCompany.company_name} updated successfully.`,
        });
        // Refresh the list to show updated status
        await fetchCompanies();
      }

      setEditingCompany(null);
      resetForm();
      closeModal();
    } catch (err: any) {
      console.error('[CompaniesSettings] Error updating company:', err);
      addNotification({
        type: 'error',
        title: 'Error updating company',
        message: err?.message || 'Failed to update company.',
      });
    } finally {
      setIsSubmitting(false);
    }
  };

  // Handle delete company (archive - soft delete)
  const handleDeleteCompany = async (company: Company) => {
    const confirmed = await showConfirm({
      title: 'Archive Company',
      message: `Are you sure you want to archive "${company.company_name}"? This action can be undone.`,
      variant: 'warning',
      confirmText: 'Archive',
      cancelText: 'Cancel',
    });

    if (!confirmed) return;

    try {
      setIsSubmitting(true);
      await archiveCompany(company.id);
      addNotification({
        type: 'success',
        title: 'Company archived',
        message: `Company ${company.company_no || company.company_name} has been archived.`,
      });
      // Refresh the list to remove archived company
      await fetchCompanies();
    } catch (err: any) {
      console.error('[CompaniesSettings] Error archiving company:', err);
      addNotification({
        type: 'error',
        title: 'Error archiving company',
        message: err?.message || 'Failed to archive company.',
      });
    } finally {
      setIsSubmitting(false);
    }
  };

  // Reset form
  const resetForm = () => {
    setFormData({
      company_name: '',
      company_email: '',
      status: 'active' as 'active' | 'disabled' | 'archived',
    });
  };

  // Open add modal
  const openAddModal = () => {
    resetForm();
    setEditingCompany(null);
    setShowAddModal(true);
  };

  // Open edit modal
  const openEditModal = (company: Company) => {
    // Normalize status: if deleted, show as 'archived', otherwise use status
    const normalizedStatus = company.deleted 
      ? 'archived' 
      : (company.status === 'active' ? 'active' : 'disabled');
    
    setFormData({
      company_name: company.company_name,
      company_email: company.company_email || '',
      status: normalizedStatus as 'active' | 'disabled' | 'archived',
    });
    setEditingCompany(company);
    setShowAddModal(true);
  };

  // Close modal
  const closeModal = () => {
    setShowAddModal(false);
    setEditingCompany(null);
    resetForm();
  };

  // Check permissions
  const canManageCompanies = isSuperAdmin || isOwner || isAdmin;

  // Debug logs
  useEffect(() => {
    if (import.meta.env.DEV) {
      console.log('[CompaniesSettings] Permissions:', {
        isSuperAdmin,
        isOwner,
        isAdmin,
        canManageCompanies,
        roleLoading,
        activeOrganizationId,
      });
    }
  }, [isSuperAdmin, isOwner, isAdmin, canManageCompanies, roleLoading, activeOrganizationId]);

  if (!activeOrganizationId) {
    return (
      <div className="bg-white border border-gray-200 rounded-lg p-6">
        <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-4">
          <p className="text-sm text-yellow-800">Please select an organization to view companies.</p>
        </div>
      </div>
    );
  }

  // Show loading state while permissions are loading
  if (roleLoading) {
    return (
      <div className="bg-white border border-gray-200 rounded-lg p-6">
        <div className="text-center py-8">
          <div className="text-sm text-gray-500">Loading permissions...</div>
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Companies List Section */}
      <div className="bg-white border border-gray-200 rounded-lg p-6">
        <div className="flex items-center justify-between mb-4">
          <div>
            <h2 className="text-lg font-semibold text-gray-900">Companies</h2>
            <p className="text-xs text-gray-500 mt-1">
              Manage companies in your organization ({companies.length} total)
            </p>
          </div>
          <div className="flex items-center gap-2">
            <button
              onClick={() => fetchCompanies()}
              className="px-3 py-1.5 border border-gray-300 rounded text-sm hover:bg-gray-50 flex items-center gap-1"
              title="Refresh"
            >
              <RotateCw className="w-3 h-3" />
              Refresh
            </button>
            {canManageCompanies && !roleLoading && (
              <button
                onClick={openAddModal}
                className="px-3 py-1.5 bg-primary text-white rounded text-sm hover:opacity-90 flex items-center gap-1"
              >
                <Plus className="w-3 h-3" />
                Add Company
              </button>
            )}
          </div>
        </div>

        {isLoading ? (
          <div className="text-center py-8">
            <div className="text-sm text-gray-500">Loading companies...</div>
          </div>
        ) : error ? (
          <div className="bg-red-50 border border-red-200 rounded-lg p-4">
            <p className="text-sm text-red-800">Error loading companies: {error}</p>
          </div>
        ) : companies.length === 0 ? (
          <div className="text-center py-12">
            <Building className="w-12 h-12 text-gray-400 mx-auto mb-4" />
            <p className="text-gray-600 mb-2">No companies found</p>
            <p className="text-sm text-gray-500">
              {canManageCompanies 
                ? 'Start by adding companies to your organization'
                : 'Companies will appear here once they are created.'}
            </p>
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead className="bg-gray-100 border-b border-gray-200">
                <tr>
                  <th className="text-left py-3 px-6 font-medium text-gray-900 text-xs">Company Number</th>
                  <th className="text-left py-3 px-6 font-medium text-gray-900 text-xs">Company</th>
                  <th className="text-left py-3 px-6 font-medium text-gray-900 text-xs">Email</th>
                  <th className="text-left py-3 px-6 font-medium text-gray-900 text-xs">Status</th>
                  <th className="text-left py-3 px-6 font-medium text-gray-900 text-xs">Date Added</th>
                  {canManageCompanies && !roleLoading && (
                    <th className="text-right py-3 px-6 font-medium text-gray-900 text-xs">Actions</th>
                  )}
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-200">
                {companies.map((company) => (
                  <tr key={company.id} className="hover:bg-gray-50 transition-colors">
                    <td className="py-4 px-6 text-gray-600 text-sm whitespace-nowrap font-mono">
                      {company.company_no || '-'}
                    </td>
                    <td className="py-4 px-6 text-gray-900 text-sm whitespace-nowrap">
                      <span className="font-medium">{company.company_name}</span>
                    </td>
                    <td className="py-4 px-6 text-gray-600 text-sm whitespace-nowrap truncate">
                      {company.company_email || '-'}
                    </td>
                    <td className="py-4 px-6 whitespace-nowrap">
                      <StatusBadge status={company.status} deleted={company.deleted} />
                    </td>
                    <td className="py-4 px-6 text-gray-600 text-sm whitespace-nowrap">
                      {company.created_at 
                        ? new Date(company.created_at).toLocaleDateString()
                        : '-'}
                    </td>
                    {canManageCompanies && !roleLoading && (
                      <td className="py-4 px-6">
                        <div className="flex items-center gap-2 justify-end">
                          <button
                            onClick={(e) => {
                              e.stopPropagation();
                              openEditModal(company);
                            }}
                            className="p-1.5 hover:bg-gray-100 rounded transition-colors text-gray-600"
                            title="Edit company"
                            disabled={company.deleted}
                          >
                            <Edit className="w-4 h-4" />
                          </button>
                          {!company.deleted && (
                            <button
                              onClick={(e) => {
                                e.stopPropagation();
                                handleDeleteCompany(company);
                              }}
                              className="p-1.5 hover:bg-gray-100 rounded transition-colors text-gray-600"
                              title="Archive company"
                            >
                              <Archive className="w-4 h-4" />
                            </button>
                          )}
                        </div>
                      </td>
                    )}
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {/* Add/Edit Company Modal */}
      {showAddModal && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
          <div className="bg-white rounded-lg p-6 max-w-md w-full mx-4">
            <div className="flex items-center justify-between mb-4">
              <h3 className="text-lg font-semibold text-gray-900">
                {editingCompany ? 'Edit Company' : 'Add Company'}
              </h3>
              <button
                onClick={closeModal}
                className="text-gray-400 hover:text-gray-600"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <div className="space-y-4">
              <div>
                <Label htmlFor="company_name" className="text-xs" required>
                  Company Name
                </Label>
                <Input
                  id="company_name"
                  value={formData.company_name}
                  onChange={(e) => setFormData({ ...formData, company_name: e.target.value })}
                  placeholder="Enter company name"
                  className="mt-1"
                />
              </div>

              <div>
                <Label htmlFor="company_email" className="text-xs">Email</Label>
                <Input
                  id="company_email"
                  type="email"
                  value={formData.company_email}
                  onChange={(e) => setFormData({ ...formData, company_email: e.target.value })}
                  placeholder="company@example.com"
                  className="mt-1"
                />
              </div>

              <div>
                <Label htmlFor="status" className="text-xs" required>Status</Label>
                <SelectShadcn
                  value={formData.status || 'active'}
                  onValueChange={(value) => {
                    setFormData({ ...formData, status: value as 'active' | 'disabled' | 'archived' });
                  }}
                  disabled={!editingCompany && formData.status === 'archived'} // Cannot create as archived
                >
                  <SelectTrigger className="mt-1" id="status">
                    <SelectValue placeholder="Select status" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="active">Active</SelectItem>
                    <SelectItem value="disabled">Disabled</SelectItem>
                    {editingCompany && (
                      <SelectItem value="archived">Archived (Delete)</SelectItem>
                    )}
                  </SelectContent>
                </SelectShadcn>
                {formData.status === 'archived' && editingCompany && (
                  <p className="mt-1 text-xs text-amber-600">
                    Selecting "Archived" will soft-delete this company. This action can be undone.
                  </p>
                )}
              </div>

              {editingCompany && (
                <div className="bg-blue-50 border border-blue-200 rounded-lg p-3">
                  <p className="text-xs text-blue-800">
                    <strong>Company Number:</strong> {editingCompany.company_no || 'N/A'} (cannot be changed)
                  </p>
                </div>
              )}
            </div>

            <div className="flex items-center gap-2 mt-6">
              <button
                onClick={closeModal}
                className="flex-1 px-4 py-2 border border-gray-300 rounded text-sm hover:bg-gray-50"
              >
                Cancel
              </button>
              <button
                onClick={editingCompany ? handleUpdateCompany : handleAddCompany}
                disabled={isSubmitting || !formData.company_name.trim()}
                className="flex-1 px-4 py-2 bg-primary text-white rounded text-sm hover:opacity-90 disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {isSubmitting ? 'Saving...' : editingCompany ? 'Update' : 'Create'} Company
              </button>
            </div>
          </div>
        </div>
      )}

      <ConfirmDialog
        isOpen={dialogState.isOpen}
        onClose={closeDialog}
        onConfirm={handleConfirm}
        title={dialogState.title}
        message={dialogState.message}
        variant={dialogState.variant}
        confirmText={dialogState.confirmText}
        cancelText={dialogState.cancelText}
        loading={dialogState.loading}
      />
    </div>
  );
}
