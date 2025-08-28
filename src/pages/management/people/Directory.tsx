import { useEffect, useState } from 'react';
import { useSubmoduleNav } from '../../../hooks/useSubmoduleNav';
import { Users, GitBranch, Search, Mail, Phone, MapPin, Filter } from 'lucide-react';

export default function Directory() {
  const { registerSubmodules } = useSubmoduleNav();
  const [searchTerm, setSearchTerm] = useState('');
  const [filterDepartment, setFilterDepartment] = useState('all');

  useEffect(() => {
    // Register submodule tabs for management people section
    registerSubmodules('People Directory', [
      { id: 'directory', label: 'Directory', href: '/management/people/directory', icon: Users },
      { id: 'org-chart', label: 'Organizational Chart', href: '/management/people/organizational-chart', icon: GitBranch }
    ]);
  }, [registerSubmodules]);

  const employees = [
    {
      id: 1,
      name: 'Sarah Johnson',
      position: 'Engineering Manager',
      department: 'Engineering',
      email: 'sarah.johnson@company.com',
      phone: '+1 (555) 234-5678',
      location: 'San Francisco, CA',
      avatar: null,
      status: 'active'
    },
    {
      id: 2,
      name: 'Mike Chen',
      position: 'Senior Frontend Developer',
      department: 'Engineering',
      email: 'mike.chen@company.com',
      phone: '+1 (555) 345-6789',
      location: 'San Francisco, CA',
      avatar: null,
      status: 'active'
    },
    {
      id: 3,
      name: 'Alex Rodriguez',
      position: 'Backend Developer',
      department: 'Engineering',
      email: 'alex.rodriguez@company.com',
      phone: '+1 (555) 456-7890',
      location: 'Austin, TX',
      avatar: null,
      status: 'active'
    },
    {
      id: 4,
      name: 'Emily Davis',
      position: 'Product Manager',
      department: 'Product',
      email: 'emily.davis@company.com',
      phone: '+1 (555) 567-8901',
      location: 'New York, NY',
      avatar: null,
      status: 'active'
    },
    {
      id: 5,
      name: 'David Wilson',
      position: 'UX Designer',
      department: 'Design',
      email: 'david.wilson@company.com',
      phone: '+1 (555) 678-9012',
      location: 'Los Angeles, CA',
      avatar: null,
      status: 'active'
    },
    {
      id: 6,
      name: 'Lisa Brown',
      position: 'HR Manager',
      department: 'Human Resources',
      email: 'lisa.brown@company.com',
      phone: '+1 (555) 789-0123',
      location: 'San Francisco, CA',
      avatar: null,
      status: 'active'
    }
  ];

  const departments = ['all', ...new Set(employees.map(emp => emp.department))];

  const filteredEmployees = employees.filter(employee => {
    const matchesSearch = employee.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
                         employee.position.toLowerCase().includes(searchTerm.toLowerCase()) ||
                         employee.department.toLowerCase().includes(searchTerm.toLowerCase());
    const matchesDepartment = filterDepartment === 'all' || employee.department === filterDepartment;
    return matchesSearch && matchesDepartment;
  });

  const getDepartmentStats = () => {
    const stats = employees.reduce((acc, emp) => {
      acc[emp.department] = (acc[emp.department] || 0) + 1;
      return acc;
    }, {} as Record<string, number>);
    return stats;
  };

  const departmentStats = getDepartmentStats();

  return (
    <div className="p-6">
      <div className="mb-8">
        <h1 className="text-2xl font-bold text-foreground mb-2">Employee Directory</h1>
        <p className="text-muted-foreground">Browse and manage company employees</p>
      </div>

      {/* Stats Cards */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-4 mb-6">
        <div className="bg-card border border-border rounded-lg p-4">
          <div className="text-2xl font-bold text-primary">{employees.length}</div>
          <div className="text-sm text-muted-foreground">Total Employees</div>
        </div>
        <div className="bg-card border border-border rounded-lg p-4">
          <div className="text-2xl font-bold text-green-600">{departmentStats['Engineering'] || 0}</div>
          <div className="text-sm text-muted-foreground">Engineering</div>
        </div>
        <div className="bg-card border border-border rounded-lg p-4">
          <div className="text-2xl font-bold text-blue-600">{departmentStats['Product'] || 0}</div>
          <div className="text-sm text-muted-foreground">Product</div>
        </div>
        <div className="bg-card border border-border rounded-lg p-4">
          <div className="text-2xl font-bold text-purple-600">{departmentStats['Design'] || 0}</div>
          <div className="text-sm text-muted-foreground">Design</div>
        </div>
      </div>

      {/* Search and Filter */}
      <div className="flex flex-col md:flex-row gap-4 mb-6">
        <div className="flex-1 relative">
          <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-muted-foreground" />
          <input
            type="text"
            placeholder="Search employees..."
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            className="w-full pl-10 pr-4 py-2 border border-border rounded-lg focus:outline-none focus:ring-2 focus:ring-primary focus:border-transparent"
          />
        </div>
        <div className="flex items-center gap-2">
          <Filter className="h-4 w-4 text-muted-foreground" />
          <select
            value={filterDepartment}
            onChange={(e) => setFilterDepartment(e.target.value)}
            className="px-3 py-2 border border-border rounded-lg focus:outline-none focus:ring-2 focus:ring-primary focus:border-transparent"
          >
            {departments.map(dept => (
              <option key={dept} value={dept}>
                {dept === 'all' ? 'All Departments' : dept}
              </option>
            ))}
          </select>
        </div>
      </div>

      {/* Employee Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        {filteredEmployees.map((employee) => (
          <div key={employee.id} className="bg-card border border-border rounded-lg p-6 hover:shadow-md transition-shadow">
            <div className="flex items-start gap-4">
              <div className="w-12 h-12 bg-primary/10 rounded-full flex items-center justify-center flex-shrink-0">
                <span className="text-primary font-semibold">
                  {employee.name.split(' ').map(n => n[0]).join('')}
                </span>
              </div>
              <div className="flex-1 min-w-0">
                <h3 className="font-semibold text-foreground mb-1">{employee.name}</h3>
                <p className="text-sm text-muted-foreground mb-1">{employee.position}</p>
                <p className="text-xs text-muted-foreground mb-3">{employee.department}</p>
                
                <div className="space-y-2">
                  <div className="flex items-center gap-2 text-sm text-muted-foreground">
                    <Mail className="h-3 w-3" />
                    <span className="truncate">{employee.email}</span>
                  </div>
                  <div className="flex items-center gap-2 text-sm text-muted-foreground">
                    <Phone className="h-3 w-3" />
                    <span>{employee.phone}</span>
                  </div>
                  <div className="flex items-center gap-2 text-sm text-muted-foreground">
                    <MapPin className="h-3 w-3" />
                    <span>{employee.location}</span>
                  </div>
                </div>

                <div className="mt-4 pt-3 border-t border-border">
                  <button className="text-sm text-primary hover:underline">
                    View Profile
                  </button>
                </div>
              </div>
            </div>
          </div>
        ))}
      </div>

      {filteredEmployees.length === 0 && (
        <div className="text-center py-12">
          <Users className="h-12 w-12 text-muted-foreground mx-auto mb-4" />
          <h3 className="text-lg font-semibold mb-2">No employees found</h3>
          <p className="text-muted-foreground">Try adjusting your search or filter criteria.</p>
        </div>
      )}
    </div>
  );
}
