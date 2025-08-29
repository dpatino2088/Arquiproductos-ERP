import { useEffect } from 'react';
import { useSubmoduleNav } from '../../../hooks/useSubmoduleNav';
import { User, Mail, Phone, MapPin, Calendar, Edit } from 'lucide-react';

export default function MyInfo() {
  const { registerSubmodules } = useSubmoduleNav();

  useEffect(() => {
    // Register submodule tabs for personal people section
    registerSubmodules('My Information', [
      { id: 'my-info', label: 'My Info', href: '/personal/people/my-info', icon: User }
    ]);
  }, [registerSubmodules]);

  const userInfo = {
    name: 'John Doe',
    email: 'john.doe@company.com',
    phone: '+1 (555) 123-4567',
    location: 'San Francisco, CA',
    department: 'Engineering',
    position: 'Senior Software Developer',
    startDate: '2022-03-15',
    manager: 'Sarah Johnson',
    employeeId: 'EMP-2024-001'
  };

  return (
    <div className="p-6">
      <div className="mb-8">
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-xl font-semibold text-foreground mb-1">My Information</h1>
            <p className="text-xs text-gray-400">View and manage your personal information</p>
          </div>
          <button className="flex items-center gap-2 bg-primary text-primary-foreground px-4 py-2 rounded-lg hover:bg-primary/90">
            <Edit className="h-4 w-4" />
            Edit Profile
          </button>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Profile Card */}
        <div className="lg:col-span-1">
          <div className="bg-card border border-border rounded-lg p-6 text-center">
            <div className="w-24 h-24 bg-primary/10 rounded-full flex items-center justify-center mx-auto mb-4">
              <User className="h-12 w-12 text-primary" />
            </div>
            <h2 className="text-xl font-semibold mb-1">{userInfo.name}</h2>
            <p className="text-muted-foreground mb-2">{userInfo.position}</p>
            <p className="text-sm text-muted-foreground">{userInfo.department}</p>
            <div className="mt-4 pt-4 border-t border-border">
              <p className="text-sm text-muted-foreground">Employee ID</p>
              <p className="font-medium">{userInfo.employeeId}</p>
            </div>
          </div>
        </div>

        {/* Information Details */}
        <div className="lg:col-span-2">
          <div className="bg-card border border-border rounded-lg p-6">
            <h3 className="text-lg font-semibold mb-6">Contact Information</h3>
            <div className="space-y-6">
              <div className="flex items-center gap-4">
                <Mail className="h-5 w-5 text-muted-foreground" />
                <div>
                  <p className="text-sm text-muted-foreground">Email Address</p>
                  <p className="font-medium">{userInfo.email}</p>
                </div>
              </div>
              <div className="flex items-center gap-4">
                <Phone className="h-5 w-5 text-muted-foreground" />
                <div>
                  <p className="text-sm text-muted-foreground">Phone Number</p>
                  <p className="font-medium">{userInfo.phone}</p>
                </div>
              </div>
              <div className="flex items-center gap-4">
                <MapPin className="h-5 w-5 text-muted-foreground" />
                <div>
                  <p className="text-sm text-muted-foreground">Location</p>
                  <p className="font-medium">{userInfo.location}</p>
                </div>
              </div>
            </div>
          </div>

          <div className="bg-card border border-border rounded-lg p-6 mt-6">
            <h3 className="text-lg font-semibold mb-6">Employment Details</h3>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              <div>
                <p className="text-sm text-muted-foreground mb-1">Department</p>
                <p className="font-medium">{userInfo.department}</p>
              </div>
              <div>
                <p className="text-sm text-muted-foreground mb-1">Position</p>
                <p className="font-medium">{userInfo.position}</p>
              </div>
              <div>
                <p className="text-sm text-muted-foreground mb-1">Start Date</p>
                <div className="flex items-center gap-2">
                  <Calendar className="h-4 w-4 text-muted-foreground" />
                  <p className="font-medium">{userInfo.startDate}</p>
                </div>
              </div>
              <div>
                <p className="text-sm text-muted-foreground mb-1">Reports To</p>
                <p className="font-medium">{userInfo.manager}</p>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Additional Sections */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6 mt-6">
        <div className="bg-card border border-border rounded-lg p-6">
          <h3 className="text-lg font-semibold mb-4">Recent Activity</h3>
          <div className="space-y-3">
            <div className="text-sm">
              <p className="font-medium">Profile Updated</p>
              <p className="text-muted-foreground">Updated contact information</p>
              <p className="text-xs text-muted-foreground mt-1">2 days ago</p>
            </div>
            <div className="text-sm">
              <p className="font-medium">Password Changed</p>
              <p className="text-muted-foreground">Security password updated</p>
              <p className="text-xs text-muted-foreground mt-1">1 week ago</p>
            </div>
          </div>
        </div>

        <div className="bg-card border border-border rounded-lg p-6">
          <h3 className="text-lg font-semibold mb-4">Quick Actions</h3>
          <div className="space-y-2">
            <button className="w-full text-left p-3 rounded-lg border border-border hover:bg-muted/50 transition-colors">
              <p className="font-medium">Update Emergency Contact</p>
              <p className="text-sm text-muted-foreground">Manage emergency contact information</p>
            </button>
            <button className="w-full text-left p-3 rounded-lg border border-border hover:bg-muted/50 transition-colors">
              <p className="font-medium">Change Password</p>
              <p className="text-sm text-muted-foreground">Update your account password</p>
            </button>
            <button className="w-full text-left p-3 rounded-lg border border-border hover:bg-muted/50 transition-colors">
              <p className="font-medium">Download Profile</p>
              <p className="text-sm text-muted-foreground">Export your profile information</p>
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
