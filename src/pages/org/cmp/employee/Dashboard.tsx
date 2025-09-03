import { useEffect } from 'react';
import { useSubmoduleNav } from '../../../../hooks/useSubmoduleNav';
import { Home, Inbox, Calendar, TrendingUp, Gift, Clock, Users, Award } from 'lucide-react';

export default function PersonalDashboard() {
  const { registerSubmodules } = useSubmoduleNav();

  useEffect(() => {
    // Register submodule tabs for employee dashboard
    registerSubmodules('Employee Dashboard', [
      { id: 'dashboard', label: 'Dashboard', href: '/employee/dashboard', icon: Home },
      { id: 'inbox', label: 'Inbox', href: '/inbox', icon: Inbox }
    ]);
  }, [registerSubmodules]);

  const upcomingBirthdays = [
    { name: 'Sarah Johnson', date: 'Today', department: 'Engineering' },
    { name: 'Mike Chen', date: 'Tomorrow', department: 'Engineering' },
    { name: 'Emily Davis', date: 'Jan 15', department: 'Product' },
    { name: 'David Wilson', date: 'Jan 18', department: 'Design' }
  ];

  const personalStats = [
    { title: 'Days Until Next Review', value: '45', icon: Calendar, color: 'text-status-blue' },
    { title: 'Performance Score', value: '4.8/5', icon: TrendingUp, color: 'text-status-green' },
    { title: 'PTO Days Left', value: '12', icon: Clock, color: 'text-status-amber' },
    { title: 'Team Size', value: '8', icon: Users, color: 'text-primary' }
  ];

  const recentAchievements = [
    { title: 'Project Milestone', description: 'Completed Q4 security audit', date: '2 days ago' },
    { title: 'Team Recognition', description: 'Received peer nomination for collaboration', date: '1 week ago' },
    { title: 'Skill Development', description: 'Completed React Advanced certification', date: '2 weeks ago' }
  ];

  return (
    <div className="p-6">
      {/* Welcome Header */}
      <div className="mb-8">
        <h1 className="text-xl font-semibold text-foreground mb-1">Welcome back, John!</h1>
        <p className="text-xs text-muted-foreground">Here's your personal overview and important updates</p>
      </div>

      {/* Personal Stats */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
        {personalStats.map((stat, index) => (
          <div key={index} className="bg-white border border-gray-200 rounded-lg p-6 hover:shadow-lg transition-all duration-200 hover:border-primary/20">
            <div className="flex items-center justify-between mb-4">
              <stat.icon className={`h-8 w-8 ${stat.color}`} />
              <div className={`text-2xl font-bold ${stat.color}`}>{stat.value}</div>
            </div>
            <div className="text-sm font-medium text-muted-foreground">{stat.title}</div>
          </div>
        ))}
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-8">
        {/* Upcoming Birthdays */}
        <div className="bg-white border border-gray-200 rounded-lg p-6">
          <div className="flex items-center gap-3 mb-6">
            <Gift className="h-6 w-6 text-status-amber" />
            <h2 className="text-lg font-semibold">Upcoming Birthdays</h2>
          </div>
          <div className="space-y-4">
            {upcomingBirthdays.map((birthday, index) => (
              <div key={index} className="flex items-center justify-between p-3 hover:bg-gray-50 rounded-lg transition-colors">
                <div>
                  <div className="font-medium">{birthday.name}</div>
                  <div className="text-sm text-muted-foreground">{birthday.department}</div>
                </div>
                <div className="text-sm font-medium text-status-red">{birthday.date}</div>
              </div>
            ))}
          </div>
        </div>

        {/* Recent Achievements */}
        <div className="bg-white border border-gray-200 rounded-lg p-6">
          <div className="flex items-center gap-3 mb-6">
            <Award className="h-6 w-6 text-status-amber" />
            <h2 className="text-lg font-semibold">Recent Achievements</h2>
          </div>
          <div className="space-y-4">
            {recentAchievements.map((achievement, index) => (
              <div key={index} className="p-3 hover:bg-gray-50 rounded-lg transition-colors">
                <div className="font-medium mb-1">{achievement.title}</div>
                <div className="text-sm text-muted-foreground mb-2">{achievement.description}</div>
                <div className="text-xs text-muted-foreground">{achievement.date}</div>
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* Quick Actions */}
      <div className="bg-white border border-gray-200 rounded-lg p-6">
        <h2 className="text-lg font-semibold mb-6">Quick Actions</h2>
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          <button className="p-4 border border-gray-200 rounded-lg hover:bg-gray-50 transition-colors text-left hover:border-primary/20">
            <div className="font-medium mb-1">Request Time Off</div>
            <div className="text-sm text-muted-foreground">Submit PTO or sick leave request</div>
          </button>
          <button className="p-4 border border-gray-200 rounded-lg hover:bg-gray-50 transition-colors text-left hover:border-primary/20">
            <div className="font-medium mb-1">Update Profile</div>
            <div className="text-sm text-muted-foreground">Edit your personal information</div>
          </button>
          <button className="p-4 border border-gray-200 rounded-lg hover:bg-gray-50 transition-colors text-left hover:border-primary/20">
            <div className="font-medium mb-1">View Payslips</div>
            <div className="text-sm text-muted-foreground">Access your payment history</div>
          </button>
        </div>
      </div>
    </div>
  );
}
