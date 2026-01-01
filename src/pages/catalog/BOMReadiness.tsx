import { useState, useEffect } from 'react';
import { useOrganizationContext } from '../../context/OrganizationContext';
import { supabase } from '../../lib/supabase/client';
import { useUIStore } from '../../stores/ui-store';
import { router } from '../../lib/router';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { Download, AlertCircle, CheckCircle, AlertTriangle, ExternalLink, Package, Wrench } from 'lucide-react';

interface BOMReadinessIssue {
  type: string;
  severity: 'BLOCKER' | 'WARN';
  message: string;
}

interface SuggestedSeed {
  type: string;
  sql: string;
}

interface ProductTypeReadiness {
  product_type_id: string;
  product_type_name: string;
  product_type_code: string;
  template_count: number;
  components_count: number;
  status: 'READY' | 'MISSING_TEMPLATE' | 'MISSING_COMPONENTS' | 'ISSUES';
  issues: BOMReadinessIssue[];
  suggested_seeds: SuggestedSeed[];
  stats?: {
    fixed_components?: number;
    valid_fixed_components?: number;
    auto_select_components?: number;
    resolvable_auto_select?: number;
    missing_uom_count?: number;
    invalid_roles_count?: number;
  };
}

interface BOMReadinessReport {
  summary: {
    total_product_types: number;
    ready: number;
    blockers: number;
    warnings: number;
  };
  items: ProductTypeReadiness[];
}

export default function BOMReadiness() {
  const { activeOrganizationId } = useOrganizationContext();
  const { registerSubmodules } = useSubmoduleNav();
  const [report, setReport] = useState<BOMReadinessReport | null>(null);
  const [readiness, setReadiness] = useState<ProductTypeReadiness[]>([]);
  const [loading, setLoading] = useState(true);
  const [selectedProductType, setSelectedProductType] = useState<string | null>(null);
  const [activeTab, setActiveTab] = useState<'overview' | 'details' | 'seeds'>('overview');
  
  // Register Catalog submodules when BOMReadiness component mounts
  useEffect(() => {
    const currentPath = window.location.pathname;
    if (currentPath.startsWith('/catalog')) {
      registerSubmodules('Catalog', [
        { id: 'items', label: 'Items', href: '/catalog/items', icon: Package },
        { id: 'bom', label: 'BOM', href: '/catalog/bom', icon: Wrench },
        { id: 'bom-readiness', label: 'BOM Readiness', href: '/catalog/bom-readiness', icon: CheckCircle },
      ]);
    }
  }, [registerSubmodules]);
  
  useEffect(() => {
    if (!activeOrganizationId) {
      setLoading(false);
      useUIStore.getState().addNotification({
        type: 'warning',
        title: 'Warning',
        message: 'No organization selected. Please select an organization to view BOM readiness.'
      });
      return;
    }
    
    const fetchReadiness = async () => {
      try {
        setLoading(true);
        const { data, error } = await supabase.rpc('get_bom_readiness', {
          p_organization_id: activeOrganizationId
        });
        
        if (error) {
          console.error('Error fetching BOM readiness:', error);
          throw error;
        }
        
        // The new function returns { summary: {...}, items: [...] }
        if (data && typeof data === 'object') {
          setReport(data as BOMReadinessReport);
          // Set items from the report
          setReadiness(Array.isArray(data.items) ? data.items : []);
        } else {
          // Fallback if data format is unexpected
          setReport({
            summary: {
              total_product_types: 0,
              ready: 0,
              blockers: 0,
              warnings: 0
            },
            items: []
          });
          setReadiness([]);
        }
        
        if (import.meta.env.DEV) {
          console.log('BOM Readiness Report:', data);
        }
      } catch (err) {
        console.error('Error fetching BOM readiness:', err);
        useUIStore.getState().addNotification({
          type: 'error',
          title: 'Error',
          message: err instanceof Error ? err.message : 'Failed to load BOM readiness report'
        });
      } finally {
        setLoading(false);
      }
    };
    
    fetchReadiness();
  }, [activeOrganizationId]);
  
  // Get summary from report or calculate from readiness array
  const summary = report?.summary || {
    total_product_types: readiness.length,
    ready: readiness.filter(r => r.status === 'READY').length,
    blockers: readiness.reduce((sum, r) => 
      sum + r.issues.filter(i => i.severity === 'BLOCKER').length, 0),
    warnings: readiness.reduce((sum, r) => 
      sum + r.issues.filter(i => i.severity === 'WARN').length, 0),
  };
  
  const readinessPercent = summary.total_product_types > 0 
    ? Math.round((summary.ready / summary.total_product_types) * 100)
    : 0;
  
  // Generate SQL script for all suggested seeds
  const generateSQLScript = (): string => {
    const allSeeds = readiness.flatMap(r => 
      r.suggested_seeds.map(seed => ({
        ...seed,
        product_type: r.product_type_name,
        product_type_code: r.product_type_code
      }))
    );
    
    if (allSeeds.length === 0) {
      return `-- BOM Readiness Seeds - Generated ${new Date().toISOString()}
-- Organization ID: ${activeOrganizationId}
-- Status: No seeds needed - all ProductTypes are ready!

-- All BOM configurations appear to be complete.
-- No automatic seeds are required at this time.
`;
    }
    
    const sql = `-- BOM Readiness Seeds - Generated ${new Date().toISOString()}
-- Organization ID: ${activeOrganizationId}
-- 
-- WARNING: Review all SQL statements before executing
-- Some statements may require manual adjustments (e.g., ItemCategory mappings)

${allSeeds.map((seed, idx) => `-- ============================================
-- ${idx + 1}. ${seed.product_type} (${seed.product_type_code}): ${seed.type}
-- ============================================
${seed.sql}`).join('\n\n')}

-- ============================================
-- End of generated seeds
-- ============================================
`;
    
    return sql;
  };
  
  const handleDownloadSQL = () => {
    const sql = generateSQLScript();
    const blob = new Blob([sql], { type: 'text/sql' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `bom-readiness-seeds-${Date.now()}.sql`;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
    
    useUIStore.getState().addNotification({
      type: 'success',
      title: 'Success',
      message: 'SQL script downloaded successfully'
    });
  };
  
  const handleCopySQL = () => {
    const sql = generateSQLScript();
    navigator.clipboard.writeText(sql);
    useUIStore.getState().addNotification({
      type: 'success',
      title: 'Success',
      message: 'SQL script copied to clipboard'
    });
  };
  
  const selectedProduct = selectedProductType 
    ? readiness.find(r => r.product_type_id === selectedProductType)
    : null;
  
  if (loading) {
    return (
      <div className="p-6">
        <div className="animate-pulse space-y-4">
          <div className="h-8 bg-gray-200 rounded w-1/4"></div>
          <div className="grid grid-cols-4 gap-4">
            {[1, 2, 3, 4].map(i => (
              <div key={i} className="h-24 bg-gray-200 rounded"></div>
            ))}
          </div>
        </div>
      </div>
    );
  }
  
  return (
    <div className="p-6">
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">BOM Readiness Dashboard</h1>
          <p className="text-sm text-gray-600 mt-1">
            Analyze BOM configuration completeness and generate seeds for missing components
          </p>
        </div>
        <div className="flex gap-2">
          <button
            onClick={() => {
              const sql = generateSQLScript();
              if (sql.includes('No seeds needed')) {
                useUIStore.getState().addNotification({
                  type: 'info',
                  title: 'Info',
                  message: 'No seeds needed - all configurations are complete!'
                });
                return;
              }
              handleCopySQL();
            }}
            className="px-4 py-2 text-sm border border-gray-300 rounded-lg hover:bg-gray-50"
          >
            Copy SQL
          </button>
          <button
            onClick={handleDownloadSQL}
            className="px-4 py-2 text-sm bg-blue-600 text-white rounded-lg hover:bg-blue-700 flex items-center gap-2"
          >
            <Download className="w-4 h-4" />
            Generate SQL Script
          </button>
        </div>
      </div>
      
      {/* Summary Cards */}
      <div className="grid grid-cols-4 gap-4 mb-6">
        <div className="bg-white border border-gray-200 rounded-lg p-4">
          <div className="text-sm text-gray-500 mb-1">Readiness</div>
          <div className="text-3xl font-bold text-blue-600">{readinessPercent}%</div>
          <div className="text-xs text-gray-500 mt-1">
            {summary.ready} of {summary.total_product_types} ready
          </div>
        </div>
        <div className="bg-white border border-gray-200 rounded-lg p-4">
          <div className="text-sm text-gray-500 mb-1">Total ProductTypes</div>
          <div className="text-3xl font-bold text-gray-900">{summary.total_product_types}</div>
        </div>
        <div className="bg-white border border-red-200 rounded-lg p-4">
          <div className="text-sm text-red-500 mb-1 flex items-center gap-1">
            <AlertCircle className="w-4 h-4" />
            Blockers
          </div>
          <div className="text-3xl font-bold text-red-600">{summary.blockers}</div>
          <div className="text-xs text-red-500 mt-1">Critical issues</div>
        </div>
        <div className="bg-white border border-yellow-200 rounded-lg p-4">
          <div className="text-sm text-yellow-600 mb-1 flex items-center gap-1">
            <AlertTriangle className="w-4 h-4" />
            Warnings
          </div>
          <div className="text-3xl font-bold text-yellow-600">{summary.warnings}</div>
          <div className="text-xs text-yellow-500 mt-1">Non-critical</div>
        </div>
      </div>
      
      {/* Tabs */}
      <div className="border-b border-gray-200 mb-4">
        <nav className="flex gap-4">
          <button
            onClick={() => setActiveTab('overview')}
            className={`pb-2 px-1 border-b-2 font-medium text-sm ${
              activeTab === 'overview'
                ? 'border-blue-600 text-blue-600'
                : 'border-transparent text-gray-500 hover:text-gray-700'
            }`}
          >
            Overview
          </button>
          <button
            onClick={() => setActiveTab('details')}
            className={`pb-2 px-1 border-b-2 font-medium text-sm ${
              activeTab === 'details'
                ? 'border-blue-600 text-blue-600'
                : 'border-transparent text-gray-500 hover:text-gray-700'
            }`}
          >
            Details
          </button>
          <button
            onClick={() => setActiveTab('seeds')}
            className={`pb-2 px-1 border-b-2 font-medium text-sm ${
              activeTab === 'seeds'
                ? 'border-blue-600 text-blue-600'
                : 'border-transparent text-gray-500 hover:text-gray-700'
            }`}
          >
            Seeds Generator
          </button>
        </nav>
      </div>
      
      {/* Tab Content */}
      {activeTab === 'overview' && (
        <div className="bg-white border border-gray-200 rounded-lg overflow-hidden">
          <table className="w-full">
            <thead className="bg-gray-50 border-b border-gray-200">
              <tr>
                <th className="text-left py-3 px-4 text-xs font-semibold text-gray-900">ProductType</th>
                <th className="text-center py-3 px-4 text-xs font-semibold text-gray-900">Status</th>
                <th className="text-center py-3 px-4 text-xs font-semibold text-gray-900">Templates</th>
                <th className="text-center py-3 px-4 text-xs font-semibold text-gray-900">Components</th>
                <th className="text-center py-3 px-4 text-xs font-semibold text-gray-900">Issues</th>
                <th className="text-center py-3 px-4 text-xs font-semibold text-gray-900">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-200">
              {readiness.length === 0 ? (
                <tr>
                  <td colSpan={6} className="py-8 text-center text-gray-500">
                    No ProductTypes found
                  </td>
                </tr>
              ) : (
                readiness.map(pt => {
                  const blockerCount = pt.issues.filter(i => i.severity === 'BLOCKER').length;
                  const warnCount = pt.issues.filter(i => i.severity === 'WARN').length;
                  
                  return (
                    <tr key={pt.product_type_id} className="hover:bg-gray-50">
                      <td className="py-3 px-4">
                        <div className="font-medium text-sm text-gray-900">{pt.product_type_name}</div>
                        {pt.product_type_code && (
                          <div className="text-xs text-gray-500 mt-0.5">{pt.product_type_code}</div>
                        )}
                      </td>
                      <td className="py-3 px-4 text-center">
                        <span className={`inline-flex px-2 py-1 rounded text-xs font-medium ${
                          pt.status === 'READY' 
                            ? 'bg-green-100 text-green-800' 
                            : pt.status === 'MISSING_TEMPLATE' || pt.status === 'MISSING_COMPONENTS'
                            ? 'bg-red-100 text-red-800'
                            : 'bg-yellow-100 text-yellow-800'
                        }`}>
                          {pt.status}
                        </span>
                      </td>
                      <td className="py-3 px-4 text-center text-sm text-gray-700">
                        {pt.template_count}
                      </td>
                      <td className="py-3 px-4 text-center text-sm text-gray-700">
                        {pt.components_count}
                      </td>
                      <td className="py-3 px-4 text-center">
                        {blockerCount > 0 && (
                          <span className="inline-flex items-center gap-1 text-xs text-red-600 font-medium">
                            <AlertCircle className="w-3 h-3" />
                            {blockerCount}
                          </span>
                        )}
                        {warnCount > 0 && (
                          <span className="inline-flex items-center gap-1 text-xs text-yellow-600 font-medium ml-2">
                            <AlertTriangle className="w-3 h-3" />
                            {warnCount}
                          </span>
                        )}
                        {blockerCount === 0 && warnCount === 0 && (
                          <span className="text-xs text-gray-400">—</span>
                        )}
                      </td>
                      <td className="py-3 px-4 text-center">
                        <div className="flex items-center justify-center gap-2">
                          <button
                            onClick={() => {
                              setSelectedProductType(
                                selectedProductType === pt.product_type_id ? null : pt.product_type_id
                              );
                              setActiveTab('details');
                            }}
                            className="text-blue-600 hover:underline text-xs"
                          >
                            Details
                          </button>
                          {pt.template_count > 0 && (
                            <button
                              onClick={() => router.navigate('/catalog/bom')}
                              className="text-gray-600 hover:text-gray-900 text-xs flex items-center gap-1"
                            >
                              <ExternalLink className="w-3 h-3" />
                              Templates
                            </button>
                          )}
                        </div>
                      </td>
                    </tr>
                  );
                })
              )}
            </tbody>
          </table>
        </div>
      )}
      
      {activeTab === 'details' && (
        <div className="space-y-4">
          {selectedProduct ? (
            <>
              <div className="bg-white border border-gray-200 rounded-lg p-4">
                <h2 className="text-lg font-semibold mb-2">{selectedProduct.product_type_name}</h2>
                <div className="grid grid-cols-2 gap-4 text-sm">
                  <div>
                    <span className="text-gray-500">Status:</span>{' '}
                    <span className={`font-medium ${
                      selectedProduct.status === 'READY' ? 'text-green-600' : 'text-red-600'
                    }`}>
                      {selectedProduct.status}
                    </span>
                  </div>
                  <div>
                    <span className="text-gray-500">Templates:</span>{' '}
                    <span className="font-medium">{selectedProduct.template_count}</span>
                  </div>
                  <div>
                    <span className="text-gray-500">Components:</span>{' '}
                    <span className="font-medium">{selectedProduct.components_count}</span>
                  </div>
                  {selectedProduct.stats && (
                    <>
                      <div>
                        <span className="text-gray-500">Fixed Components:</span>{' '}
                        <span className="font-medium">
                          {selectedProduct.stats.valid_fixed_components || 0} / {selectedProduct.stats.fixed_components || 0}
                        </span>
                      </div>
                      <div>
                        <span className="text-gray-500">Auto-Select:</span>{' '}
                        <span className="font-medium">
                          {selectedProduct.stats.resolvable_auto_select || 0} / {selectedProduct.stats.auto_select_components || 0}
                        </span>
                      </div>
                    </>
                  )}
                </div>
              </div>
              
              {selectedProduct.issues.length > 0 ? (
                <div className="space-y-3">
                  <h3 className="text-sm font-semibold text-gray-900">Issues</h3>
                  {selectedProduct.issues.map((issue, idx) => (
                    <div
                      key={idx}
                      className={`p-4 rounded-lg border ${
                        issue.severity === 'BLOCKER'
                          ? 'bg-red-50 border-red-200'
                          : 'bg-yellow-50 border-yellow-200'
                      }`}
                    >
                      <div className="flex items-start gap-2">
                        {issue.severity === 'BLOCKER' ? (
                          <AlertCircle className="w-5 h-5 text-red-600 flex-shrink-0 mt-0.5" />
                        ) : (
                          <AlertTriangle className="w-5 h-5 text-yellow-600 flex-shrink-0 mt-0.5" />
                        )}
                        <div className="flex-1">
                          <div className="font-medium text-sm text-gray-900 mb-1">
                            {issue.type}
                          </div>
                          <div className="text-sm text-gray-700">{issue.message}</div>
                        </div>
                        <span className={`px-2 py-1 rounded text-xs font-medium ${
                          issue.severity === 'BLOCKER'
                            ? 'bg-red-100 text-red-800'
                            : 'bg-yellow-100 text-yellow-800'
                        }`}>
                          {issue.severity}
                        </span>
                      </div>
                    </div>
                  ))}
                </div>
              ) : (
                <div className="bg-green-50 border border-green-200 rounded-lg p-4">
                  <div className="flex items-center gap-2">
                    <CheckCircle className="w-5 h-5 text-green-600" />
                    <span className="font-medium text-green-900">No issues found</span>
                  </div>
                  <p className="text-sm text-green-700 mt-1">
                    This ProductType is ready for BOM generation.
                  </p>
                </div>
              )}
            </>
          ) : (
            <div className="bg-gray-50 border border-gray-200 rounded-lg p-8 text-center">
              <p className="text-gray-500">Select a ProductType from the Overview tab to see details</p>
            </div>
          )}
        </div>
      )}
      
      {activeTab === 'seeds' && (
        <div className="bg-white border border-gray-200 rounded-lg p-6">
          <div className="flex items-center justify-between mb-4">
            <div>
              <h3 className="text-lg font-semibold text-gray-900">Generated SQL Seeds</h3>
              <p className="text-sm text-gray-600 mt-1">
                Review and execute these SQL statements to fix missing configurations
              </p>
            </div>
            <div className="flex gap-2">
              <button
                onClick={handleCopySQL}
                className="px-4 py-2 text-sm border border-gray-300 rounded-lg hover:bg-gray-50"
              >
                Copy to Clipboard
              </button>
              <button
                onClick={handleDownloadSQL}
                className="px-4 py-2 text-sm bg-blue-600 text-white rounded-lg hover:bg-blue-700 flex items-center gap-2"
              >
                <Download className="w-4 h-4" />
                Download SQL
              </button>
            </div>
          </div>
          
          <div className="bg-gray-900 text-gray-100 p-4 rounded-lg overflow-x-auto">
            <pre className="text-xs font-mono whitespace-pre-wrap">
              {generateSQLScript()}
            </pre>
          </div>
          
          <div className="mt-4 p-4 bg-yellow-50 border border-yellow-200 rounded-lg">
            <div className="flex items-start gap-2">
              <AlertTriangle className="w-5 h-5 text-yellow-600 flex-shrink-0 mt-0.5" />
              <div className="text-sm text-yellow-800">
                <p className="font-medium mb-1">Warning</p>
                <p>
                  Review all SQL statements before executing. Some statements may require manual adjustments, 
                  especially ItemCategory mappings for ComponentRoleMap entries.
                </p>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

