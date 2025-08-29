import { useEffect } from 'react';
import { FileText, Download, Calendar, TrendingUp } from 'lucide-react';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';

export default function Reports() {
  const { setBreadcrumbs, clearSubmoduleNav } = useSubmoduleNav();

  // Setup breadcrumb navigation
  useEffect(() => {
    setBreadcrumbs([
      { label: 'Home', href: '/' },
      { label: 'Reports' }
    ]);
    return () => clearSubmoduleNav();
  }, [setBreadcrumbs, clearSubmoduleNav]);

  return (
    <div className="p-6">
      {/* Header */}
      <div className="mb-8">
        <h1 className="text-xl font-semibold text-foreground mb-1">Reports & Analytics</h1>
        <p className="text-xs text-gray-400">
          Generate and view detailed reports about your organization
        </p>
      </div>

      {/* Action Buttons */}
      <div className="flex justify-end gap-3 mb-6">
        <button 
          className="flex items-center gap-2 px-4 py-2 rounded-lg border transition-colors"
          style={{ 
            backgroundColor: 'white',
            borderColor: '#E5E7EB',
            color: '#6B7280'
          }}
        >
          <Calendar style={{ width: '16px', height: '16px' }} />
          Date Range
        </button>
        <button 
          className="flex items-center gap-2 px-4 py-2 rounded-lg transition-colors"
          style={{ 
            backgroundColor: '#14B8A6',
            color: 'white'
          }}
        >
          <Download style={{ width: '16px', height: '16px' }} />
          Export
        </button>
      </div>

        {/* Report Categories */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        {[
          {
            title: 'Employee Reports',
            description: 'Headcount, demographics, and performance metrics',
            icon: FileText,
            count: '12 reports',
            color: '#14B8A6'
          },
          {
            title: 'Financial Reports',
            description: 'Payroll, benefits costs, and budget analysis',
            icon: TrendingUp,
            count: '8 reports',
            color: '#3B82F6'
          },
          {
            title: 'Time & Attendance',
            description: 'Work hours, overtime, and leave tracking',
            icon: Calendar,
            count: '6 reports',
            color: '#F59E0B'
          }
        ].map((category, index) => (
          <div key={index} className="bg-white rounded-lg border p-6 hover:shadow-lg transition-shadow cursor-pointer" style={{ borderColor: '#E5E7EB' }}>
            <div className="flex items-start gap-4">
              <div className="p-3 rounded-lg" style={{ backgroundColor: `${category.color}20` }}>
                <category.icon style={{ width: '24px', height: '24px', color: category.color }} />
              </div>
              <div className="flex-1">
                <h3 className="font-semibold mb-2" style={{ color: '#222222' }}>{category.title}</h3>
                <p className="text-sm mb-3" style={{ color: '#6B7280' }}>{category.description}</p>
                <span className="text-xs px-2 py-1 rounded-full" style={{ backgroundColor: '#F3F4F6', color: '#6B7280' }}>
                  {category.count}
                </span>
              </div>
            </div>
          </div>
        ))}
      </div>

      {/* Recent Reports */}
      <div className="bg-white rounded-lg border" style={{ borderColor: '#E5E7EB' }}>
        <div className="p-6">
          <div className="flex items-center gap-3 mb-4">
            <FileText style={{ width: '20px', height: '20px', color: '#14B8A6' }} />
            <h2 className="text-lg font-medium" style={{ color: '#222222' }}>Recent Reports</h2>
          </div>
          <div className="space-y-4">
            {[
              { name: 'Monthly Employee Report', type: 'Employee', generated: '2 hours ago', size: '2.4 MB' },
              { name: 'Q1 Financial Summary', type: 'Financial', generated: '1 day ago', size: '1.8 MB' },
              { name: 'Attendance Overview', type: 'Time & Attendance', generated: '3 days ago', size: '856 KB' },
              { name: 'Performance Metrics', type: 'Employee', generated: '1 week ago', size: '3.2 MB' }
            ].map((report, index) => (
              <div key={index} className="flex items-center justify-between p-4 rounded-lg hover:bg-gray-50 cursor-pointer" style={{ backgroundColor: '#F9FAFB' }}>
                <div className="flex items-center gap-4">
                  <div className="w-10 h-10 rounded-lg flex items-center justify-center" style={{ backgroundColor: '#14B8A6' }}>
                    <FileText style={{ width: '20px', height: '20px', color: 'white' }} />
                  </div>
                  <div>
                    <p className="font-medium" style={{ color: '#222222' }}>{report.name}</p>
                    <p className="text-sm" style={{ color: '#6B7280' }}>{report.type} • Generated {report.generated}</p>
                  </div>
                </div>
                <div className="flex items-center gap-4">
                  <span className="text-sm" style={{ color: '#6B7280' }}>{report.size}</span>
                  <button className="p-2 rounded-lg hover:bg-gray-200 transition-colors">
                    <Download style={{ width: '16px', height: '16px', color: '#6B7280' }} />
                  </button>
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}
