import { useEffect, useState, useRef } from 'react';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { router } from '../../lib/router';
import { 
  User, 
  Mail, 
  Phone, 
  MapPin, 
  Building, 
  Calendar,
  UserCheck,
  Briefcase,
  Clock,
  CreditCard,
  TrendingUp,
  FileText,
  Edit,
  MoreHorizontal,
  Camera,
  MessageSquare,
  Target,
  Star,
  Award,
  Heart,
  Minus,
  Download,
  Activity,
  Settings,
} from 'lucide-react';

// Default employee data - fallback if no employee is selected
const defaultEmployee = {
  id: 'EMP001',
  firstName: 'Sarah',
  lastName: 'Johnson',
  fullName: 'Sarah Johnson',
  email: 'sarah.johnson@company.com',
  phone: '+1 (555) 123-4567',
  position: 'Senior Software Engineer',
  department: 'Engineering',
  manager: 'John Smith',
  location: 'New York, NY',
  startDate: '2022-03-15',
  employeeId: 'EMP001',
  status: 'Active',
  avatar: null
};

type SectionType = 'overview' | 'personal' | 'job' | 'timeoff' | 'benefits' | 'deductions' | 'performance' | 'documents';

export default function EmployeeInfo() {
  const { setBreadcrumbs, clearSubmoduleNav } = useSubmoduleNav();
  const [activeSection, setActiveSection] = useState<SectionType>('overview');
  const [employee, setEmployee] = useState(defaultEmployee);
  const [showMoreMenu, setShowMoreMenu] = useState(false);
  const moreMenuRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    // Load employee data from sessionStorage if available
    const selectedEmployeeData = sessionStorage.getItem('selectedEmployee');
    if (selectedEmployeeData) {
      try {
        const parsedEmployee = JSON.parse(selectedEmployeeData);
        // Map Directory employee data to EmployeeInfo format
        const mappedEmployee = {
          id: parsedEmployee.id,
          firstName: parsedEmployee.firstName,
          lastName: parsedEmployee.lastName,
          fullName: `${parsedEmployee.firstName} ${parsedEmployee.lastName}`,
          email: parsedEmployee.email,
          phone: parsedEmployee.phone || '+1 (555) 000-0000',
          position: parsedEmployee.jobTitle,
          department: parsedEmployee.department,
          manager: 'John Smith', // Default manager - in real app this would come from API
          location: parsedEmployee.location,
          startDate: parsedEmployee.startDate,
          employeeId: parsedEmployee.id,
          status: parsedEmployee.status,
          avatar: parsedEmployee.avatar
        };
        setEmployee(mappedEmployee);
      } catch (error) {
        console.error('Error parsing employee data:', error);
        setEmployee(defaultEmployee);
      }
    }
  }, []);

  useEffect(() => {
    // Clear any existing submodule navigation and set breadcrumbs
    clearSubmoduleNav();
    
    // Create slug from employee name for breadcrumb URLs
    const slug = `${employee.firstName.toLowerCase()}-${employee.lastName.toLowerCase()}`;
    
    setBreadcrumbs([
      { label: 'Employees' }, // Not clickable - use sidebar button instead
      { label: 'Directory', href: '/employees/directory' },
      { label: employee.fullName }
    ]);

    // Clear breadcrumbs when component unmounts
    return () => clearSubmoduleNav();
  }, [setBreadcrumbs, clearSubmoduleNav, employee.fullName]);

  // Close more menu when clicking outside
  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (moreMenuRef.current && !moreMenuRef.current.contains(event.target as Node)) {
        setShowMoreMenu(false);
      }
    };

    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, []);

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'Active': return 'bg-green-50 text-status-green';
      case 'On Leave': return 'bg-orange-50 text-status-orange';
      case 'Onboarding': return 'bg-blue-50 text-status-blue';
      case 'Suspended': return 'bg-red-50 text-status-red';
      default: return 'bg-gray-50 text-status-gray';
    }
  };


  const sections = [
    { id: 'overview' as SectionType, label: 'Overview', icon: User },
    { id: 'personal' as SectionType, label: 'Personal Details', icon: FileText },
    { id: 'job' as SectionType, label: 'Job Information', icon: Briefcase },
    { id: 'timeoff' as SectionType, label: 'Time Off', icon: Clock },
    { id: 'benefits' as SectionType, label: 'Benefits', icon: Heart },
    { id: 'deductions' as SectionType, label: 'Deductions', icon: Minus },
    { id: 'performance' as SectionType, label: 'Performance', icon: TrendingUp },
    { id: 'documents' as SectionType, label: 'Documents', icon: Download }
  ];

  // Mock data for overview section
  const upcomingTasks = [
    { task: 'Submit monthly report', due: 'March 10', priority: 'High' },
    { task: 'Complete Q1 goals assessment', due: 'March 15', priority: 'Medium' },
    { task: 'Annual compliance training', due: 'March 20', priority: 'Low' }
  ];

  const getTaskPriorityColor = (priority: string) => {
    switch (priority) {
      case 'High': return 'bg-red-50 text-status-red';
      case 'Medium': return 'bg-orange-50 text-status-orange';
      case 'Low': return 'bg-green-50 text-status-green';
      default: return 'bg-gray-50 text-status-gray';
    }
  };

  return (
    <div className="p-6">
      {/* Page Header */}
      <div className="mb-8">
        <h1 className="text-title font-semibold text-foreground mb-1">Employee Profile</h1>
        <p className="text-small text-muted-foreground">
          View and manage {employee.firstName} {employee.lastName}'s information
        </p>
      </div>

      {/* Hero Section */}
      <div className="bg-gradient-to-r from-primary to-foreground text-white relative overflow-hidden rounded-xl p-6 mb-6">
        {/* Background Pattern */}
        <div className="absolute inset-0 opacity-10">
          <div className="absolute top-4 right-4 w-32 h-32 bg-white/20 rounded-full"></div>
          <div className="absolute bottom-4 left-4 w-24 h-24 bg-white/10 rounded-full"></div>
        </div>

        <div className="relative z-10 flex items-start justify-between">
          <div className="flex items-start gap-6">
            {/* Profile Picture */}
            <div className="relative">
              {employee.avatar ? (
                <img 
                  src={employee.avatar} 
                  alt={`${employee.firstName} ${employee.lastName}`}
                  className="rounded-full object-cover border-4 border-white/20"
                  style={{ width: '120px', height: '120px' }}
                />
              ) : (
                <div className="bg-white/20 rounded-full flex items-center justify-center text-white font-bold border-4 border-white/20"
                     style={{ width: '120px', height: '120px', fontSize: '2rem' }}>
                  {employee.firstName[0]}{employee.lastName[0]}
                </div>
              )}
              <button className="absolute bottom-2 right-2 bg-white text-foreground rounded-full p-2 hover:bg-muted transition-colors">
                <Camera className="w-4 h-4" />
              </button>
            </div>

            {/* Profile Info */}
            <div className="flex-1">
              <div className="mb-4">
                <div className="flex items-center gap-3 mb-2">
                  <h1 className="text-2xl font-bold text-white">{employee.firstName} {employee.lastName}</h1>
                  <div className={`px-2 py-1 rounded text-xs font-medium ${getStatusColor(employee.status)}`}>
                    {employee.status}
                  </div>
                </div>
                <p className="text-white/80 text-lg mb-2">{employee.position}</p>
                <p className="text-white/60">{employee.department}</p>
              </div>

              <div className="grid grid-cols-1 md:grid-cols-2 gap-4 text-white/80">
                <div className="flex items-center gap-2">
                  <Mail className="w-4 h-4" />
                  <span>{employee.email}</span>
                </div>
                <div className="flex items-center gap-2">
                  <Phone className="w-4 h-4" />
                  <span>{employee.phone}</span>
                </div>
                <div className="flex items-center gap-2">
                  <Calendar className="w-4 h-4" />
                  <span>Started {new Date(employee.startDate).toLocaleDateString()}</span>
                </div>
                <div className="flex items-center gap-2">
                  <MapPin className="w-4 h-4" />
                  <span>{employee.location}</span>
                </div>
              </div>
            </div>
          </div>

          {/* Actions */}
          <div className="flex gap-2">
            <button className="bg-white/20 hover:bg-white/30 text-white rounded-lg transition-colors flex items-center gap-2 px-4 py-2">
              <MessageSquare className="w-4 h-4" />
              Message
            </button>
            <button className="bg-white/20 hover:bg-white/30 text-white rounded-lg transition-colors flex items-center gap-2 px-4 py-2">
              <Edit className="w-4 h-4" />
              Edit Profile
            </button>
            <div className="relative" ref={moreMenuRef}>
              <button
                onClick={() => setShowMoreMenu(!showMoreMenu)}
                className="bg-white/20 hover:bg-white/30 text-white rounded-lg transition-colors flex items-center justify-center w-10 h-10">
                <MoreHorizontal className="w-4 h-4" />
              </button>
              {showMoreMenu && (
                <div className="absolute right-0 top-12 bg-card border border-border rounded-lg shadow-lg py-2 min-w-48 z-50">
                  {employee.status === 'Active' ? (
                    <>
                      <button className="w-full px-4 py-2 text-left text-sm text-foreground hover:bg-muted transition-colors">
                        Suspend Employee
                      </button>
                      <button className="w-full px-4 py-2 text-left text-sm text-destructive hover:bg-muted transition-colors">
                        Terminate Employee
                      </button>
                    </>
                  ) : employee.status === 'Suspended' ? (
                    <>
                      <button className="w-full px-4 py-2 text-left text-sm text-status-green hover:bg-muted transition-colors">
                        Activate Employee
                      </button>
                      <button className="w-full px-4 py-2 text-left text-sm text-destructive hover:bg-muted transition-colors">
                        Terminate Employee
                      </button>
                    </>
                  ) : (
                    <button className="w-full px-4 py-2 text-left text-sm text-muted-foreground cursor-not-allowed">
                      No actions available
                    </button>
                  )}
                </div>
              )}
            </div>
          </div>
        </div>
      </div>

      {/* Section Navigation */}
      <div className="flex flex-wrap gap-2 bg-card border border-border rounded-lg p-3 mb-6">
        {sections.map((section) => {
          const Icon = section.icon;
          return (
            <button
              key={section.id}
              onClick={() => setActiveSection(section.id)}
              className={`btn ${
                activeSection === section.id ? 'btn-primary' : 'btn-secondary'
              }`}
            >
              <Icon className="w-4 h-4 mr-2" />
              {section.label}
            </button>
          );
        })}
      </div>

      {/* Section Content */}
      {activeSection === 'overview' && (
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          {/* Quick Stats */}
          <div className="lg:col-span-2 space-y-6">
            {/* Performance Metrics */}
            <div className="bg-card border border-border rounded-lg p-6">
              <h2 className="text-heading font-semibold text-foreground mb-4">{employee.firstName}'s Performance</h2>
              <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                <div className="text-center">
                  <div className="rounded-lg p-4 mb-2 bg-primary/10">
                    <Target className="mx-auto w-6 h-6 text-primary" />
                  </div>
                  <h3 className="text-body font-semibold text-foreground">92%</h3>
                  <p className="text-small text-muted-foreground">Goal Achievement</p>
                </div>
                <div className="text-center">
                  <div className="bg-blue-50 rounded-lg p-4 mb-2">
                    <Star className="text-status-blue mx-auto w-6 h-6" />
                  </div>
                  <h3 className="text-body font-semibold text-foreground">4.8</h3>
                  <p className="text-small text-muted-foreground">Average Rating</p>
                </div>
                <div className="text-center">
                  <div className="bg-orange-50 rounded-lg p-4 mb-2">
                    <Award className="text-status-orange mx-auto w-6 h-6" />
                  </div>
                  <h3 className="text-body font-semibold text-foreground">3</h3>
                  <p className="text-small text-muted-foreground">Awards This Year</p>
                </div>
              </div>
            </div>

            {/* Recent Activity */}
            <div className="bg-card border border-border rounded-lg p-6">
              <h2 className="text-heading font-semibold text-foreground mb-4">Recent Activity</h2>
              <div className="space-y-3">
                <div className="flex items-start gap-3">
                  <div className="w-2 h-2 bg-primary rounded-full mt-2"></div>
                  <div>
                    <p className="text-body text-foreground">Completed monthly performance review</p>
                    <p className="text-small text-muted-foreground">2 hours ago</p>
                  </div>
                </div>
                <div className="flex items-start gap-3">
                  <div className="w-2 h-2 bg-foreground rounded-full mt-2"></div>
                  <div>
                    <p className="text-body text-foreground">Updated personal information</p>
                    <p className="text-small text-muted-foreground">1 day ago</p>
                  </div>
                </div>
                <div className="flex items-start gap-3">
                  <div className="w-2 h-2 bg-status-blue rounded-full mt-2"></div>
                  <div>
                    <p className="text-body text-foreground">Submitted expense report</p>
                    <p className="text-small text-muted-foreground">3 days ago</p>
                  </div>
                </div>
              </div>
            </div>
          </div>

          {/* Sidebar */}
          <div className="space-y-6">
            {/* Upcoming Tasks */}
            <div className="bg-card border border-border rounded-lg p-6">
              <h2 className="text-heading font-semibold text-foreground mb-4">{employee.firstName}'s Tasks</h2>
              <div className="space-y-3">
                {upcomingTasks.map((task, index) => (
                  <div key={index} className="flex items-start justify-between">
                    <div className="flex-1">
                      <p className="text-body text-foreground">{task.task}</p>
                      <p className="text-small text-muted-foreground">Due {task.due}</p>
                    </div>
                    <span className={`px-2 py-1 rounded text-xs font-medium ${getTaskPriorityColor(task.priority)}`}>
                      {task.priority}
                    </span>
                  </div>
                ))}
              </div>
            </div>

            {/* Quick Actions */}
            <div className="bg-card border border-border rounded-lg p-6">
              <h2 className="text-heading font-semibold text-foreground mb-4">Quick Actions</h2>
              <div className="space-y-2">
                <button className="w-full btn btn-secondary justify-start">
                  <MessageSquare className="w-4 h-4 mr-2" />
                  Send Message
                </button>
                <button className="w-full btn btn-secondary justify-start">
                  <Calendar className="w-4 h-4 mr-2" />
                  Schedule Meeting
                </button>
                <button className="w-full btn btn-secondary justify-start">
                  <Award className="w-4 h-4 mr-2" />
                  Give Recognition
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {activeSection === 'personal' && (
        <div className="bg-card border border-border rounded-lg p-6">
          <h2 className="text-heading font-semibold text-foreground mb-6">Personal Details</h2>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div>
              <label className="text-body font-medium text-foreground mb-2 block">Employee ID</label>
              <p className="text-body text-muted-foreground mb-4">{employee.employeeId}</p>
              
              <label className="text-body font-medium text-foreground mb-2 block">Email</label>
              <p className="text-body text-muted-foreground mb-4">{employee.email}</p>
              
              <label className="text-body font-medium text-foreground mb-2 block">Phone</label>
              <p className="text-body text-muted-foreground mb-4">{employee.phone}</p>
            </div>
            <div>
              <label className="text-body font-medium text-foreground mb-2 block">Start Date</label>
              <p className="text-body text-muted-foreground mb-4">{new Date(employee.startDate).toLocaleDateString()}</p>
              
              <label className="text-body font-medium text-foreground mb-2 block">Location</label>
              <p className="text-body text-muted-foreground mb-4">{employee.location}</p>
              
              <label className="text-body font-medium text-foreground mb-2 block">Status</label>
              <span className={`px-2 py-1 rounded text-xs font-medium ${getStatusColor(employee.status)}`}>
                {employee.status}
              </span>
            </div>
          </div>
        </div>
      )}

      {activeSection === 'job' && (
        <div className="bg-card border border-border rounded-lg p-6">
          <h2 className="text-heading font-semibold text-foreground mb-6">Job Information</h2>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div>
              <label className="text-body font-medium text-foreground mb-2 block">Job Title</label>
              <p className="text-body text-muted-foreground mb-4">{employee.position}</p>

              <label className="text-body font-medium text-foreground mb-2 block">Department</label>
              <p className="text-body text-muted-foreground mb-4">{employee.department}</p>

              <label className="text-body font-medium text-foreground mb-2 block">Manager</label>
              <p className="text-body text-muted-foreground mb-4">{employee.manager}</p>
            </div>
            <div>
              <label className="text-body font-medium text-foreground mb-2 block">Start Date</label>
              <p className="text-body text-muted-foreground mb-4">{new Date(employee.startDate).toLocaleDateString()}</p>

              <label className="text-body font-medium text-foreground mb-2 block">Employee ID</label>
              <p className="text-body text-muted-foreground mb-4">{employee.employeeId}</p>

              <label className="text-body font-medium text-foreground mb-2 block">Location</label>
              <p className="text-body text-muted-foreground mb-4">{employee.location}</p>
            </div>
          </div>
        </div>
      )}

      {/* Coming Soon sections */}
      {['timeoff', 'benefits', 'deductions', 'performance', 'documents'].includes(activeSection) && (
        <div className="bg-card border border-border rounded-lg p-6">
          <h2 className="text-heading font-semibold text-foreground mb-6">
            {sections.find(s => s.id === activeSection)?.label}
          </h2>
          <div className="text-center py-12">
            {activeSection === 'timeoff' && <Clock className="w-12 h-12 text-muted-foreground mx-auto mb-4" />}
            {activeSection === 'benefits' && <Heart className="w-12 h-12 text-muted-foreground mx-auto mb-4" />}
            {activeSection === 'deductions' && <Minus className="w-12 h-12 text-muted-foreground mx-auto mb-4" />}
            {activeSection === 'performance' && <TrendingUp className="w-12 h-12 text-muted-foreground mx-auto mb-4" />}
            {activeSection === 'documents' && <FileText className="w-12 h-12 text-muted-foreground mx-auto mb-4" />}
            <h3 className="text-heading font-medium text-foreground mb-2">Coming Soon</h3>
            <p className="text-muted-foreground">This section is under development.</p>
          </div>
        </div>
      )}
    </div>
  );
}
