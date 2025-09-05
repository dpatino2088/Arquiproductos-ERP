import { useEffect } from 'react';
import { useSubmoduleNav } from '../../../../../hooks/useSubmoduleNav';
import { Users, GitBranch, User, Mail, Phone } from 'lucide-react';

export default function OrganizationalChart() {
  const { registerSubmodules } = useSubmoduleNav();

  useEffect(() => {
    // Register submodule tabs for management people section
    registerSubmodules('Organizational Chart', [
      { id: 'directory', label: 'Directory', href: '/org/cmp/management/people/directory', icon: Users },
      { id: 'org-chart', label: 'Organizational Chart', href: '/org/cmp/management/people/organizational-chart', icon: GitBranch }
    ]);
  }, [registerSubmodules]);

  const orgData = {
    ceo: {
      id: 1,
      name: 'Robert Smith',
      position: 'Chief Executive Officer',
      email: 'robert.smith@company.com',
      phone: '+1 (555) 100-0001',
      reports: [
        {
          id: 2,
          name: 'Sarah Johnson',
          position: 'VP of Engineering',
          email: 'sarah.johnson@company.com',
          phone: '+1 (555) 234-5678',
          reports: [
            {
              id: 3,
              name: 'Mike Chen',
              position: 'Senior Frontend Developer',
              email: 'mike.chen@company.com',
              phone: '+1 (555) 345-6789',
              reports: []
            },
            {
              id: 4,
              name: 'Alex Rodriguez',
              position: 'Backend Developer',
              email: 'alex.rodriguez@company.com',
              phone: '+1 (555) 456-7890',
              reports: []
            }
          ]
        },
        {
          id: 5,
          name: 'Emily Davis',
          position: 'VP of Product',
          email: 'emily.davis@company.com',
          phone: '+1 (555) 567-8901',
          reports: [
            {
              id: 6,
              name: 'David Wilson',
              position: 'Senior UX Designer',
              email: 'david.wilson@company.com',
              phone: '+1 (555) 678-9012',
              reports: []
            }
          ]
        },
        {
          id: 7,
          name: 'Lisa Brown',
          position: 'VP of Human Resources',
          email: 'lisa.brown@company.com',
          phone: '+1 (555) 789-0123',
          reports: [
            {
              id: 8,
              name: 'John Doe',
              position: 'HR Specialist',
              email: 'john.doe@company.com',
              phone: '+1 (555) 890-1234',
              reports: []
            }
          ]
        }
      ]
    }
  };

  interface Employee {
    id: number;
    name: string;
    position: string;
    email: string;
    phone: string;
    reports: Employee[];
  }

  const EmployeeCard = ({ employee, level = 0 }: { employee: Employee; level?: number }) => {
    const hasReports = employee.reports && employee.reports.length > 0;
    
    return (
      <div className="flex flex-col items-center">
        {/* Employee Card */}
        <div className="bg-card border border-border rounded-lg p-4 shadow-sm hover:shadow-md transition-shadow min-w-64 max-w-64">
          <div className="flex items-center gap-3 mb-3">
            <div className="w-10 h-10 bg-primary/10 rounded-full flex items-center justify-center flex-shrink-0">
              <User className="h-5 w-5 text-primary" />
            </div>
            <div className="flex-1 min-w-0">
              <h3 className="font-semibold text-sm text-foreground truncate">{employee.name}</h3>
              <p className="text-xs text-muted-foreground truncate">{employee.position}</p>
            </div>
          </div>
          
          <div className="space-y-1">
            <div className="flex items-center gap-2 text-xs text-muted-foreground">
              <Mail className="h-3 w-3 flex-shrink-0" />
              <span className="truncate">{employee.email}</span>
            </div>
            <div className="flex items-center gap-2 text-xs text-muted-foreground">
              <Phone className="h-3 w-3 flex-shrink-0" />
              <span>{employee.phone}</span>
            </div>
          </div>

          {hasReports && (
            <div className="mt-3 pt-3 border-t border-border">
              <div className="text-xs text-muted-foreground">
                {employee.reports.length} direct report{employee.reports.length !== 1 ? 's' : ''}
              </div>
            </div>
          )}
        </div>

        {/* Connection Line and Reports */}
        {hasReports && (
          <div className="flex flex-col items-center mt-4">
            {/* Vertical line down */}
            <div className="w-px h-8 bg-border"></div>
            
            {/* Horizontal line */}
            {employee.reports.length > 1 && (
              <div className="flex items-center">
                <div className={`h-px bg-border`} style={{ width: `${(employee.reports.length - 1) * 280}px` }}></div>
              </div>
            )}
            
            {/* Reports */}
            <div className="flex gap-8 mt-4">
              {employee.reports.map((report: Employee) => (
                <div key={report.id} className="flex flex-col items-center">
                  {/* Vertical line up to horizontal line */}
                  {employee.reports.length > 1 && (
                    <div className="w-px h-8 bg-border"></div>
                  )}
                  <EmployeeCard employee={report} level={level + 1} />
                </div>
              ))}
            </div>
          </div>
        )}
      </div>
    );
  };

  return (
    <div className="p-6">
      <div className="mb-8">
        <h1 className="text-xl font-semibold text-foreground mb-1">Organizational Chart</h1>
        <p className="text-xs" style={{ color: '#6B7280' }}>View the company's organizational structure</p>
      </div>

      {/* Chart Stats */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-4 mb-8">
        <div className="bg-card border border-border rounded-lg p-4">
          <div className="text-2xl font-bold text-primary">8</div>
          <div className="text-sm text-muted-foreground">Total Employees</div>
        </div>
        <div className="bg-card border border-border rounded-lg p-4">
          <div className="text-2xl font-bold text-green-600">3</div>
          <div className="text-sm text-muted-foreground">Departments</div>
        </div>
        <div className="bg-card border border-border rounded-lg p-4">
          <div className="text-2xl font-bold text-blue-600">4</div>
          <div className="text-sm text-muted-foreground">Managers</div>
        </div>
        <div className="bg-card border border-border rounded-lg p-4">
          <div className="text-2xl font-bold text-purple-600">3</div>
          <div className="text-sm text-muted-foreground">Levels</div>
        </div>
      </div>

      {/* Organizational Chart */}
      <div className="bg-card border border-border rounded-lg p-8">
        <div className="overflow-x-auto">
          <div className="flex justify-center min-w-max">
            <EmployeeCard employee={orgData.ceo} />
          </div>
        </div>
      </div>

      {/* Legend */}
      <div className="mt-6 bg-card border border-border rounded-lg p-4">
        <h3 className="font-semibold mb-3">Chart Legend</h3>
        <div className="flex flex-wrap gap-6 text-sm">
          <div className="flex items-center gap-2">
            <div className="w-3 h-3 bg-primary/10 rounded-full"></div>
            <span className="text-muted-foreground">Employee</span>
          </div>
          <div className="flex items-center gap-2">
            <div className="w-6 h-px bg-border"></div>
            <span className="text-muted-foreground">Reporting Line</span>
          </div>
          <div className="flex items-center gap-2">
            <User className="h-4 w-4 text-primary" />
            <span className="text-muted-foreground">Profile Icon</span>
          </div>
        </div>
      </div>
    </div>
  );
}
