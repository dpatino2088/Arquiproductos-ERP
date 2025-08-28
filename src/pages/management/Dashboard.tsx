import { useEffect } from 'react';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { Home, Inbox, Users, TrendingUp, AlertTriangle, CheckCircle, Clock, DollarSign } from 'lucide-react';

export default function ManagementDashboard() {
  const { registerSubmodules } = useSubmoduleNav();

  useEffect(() => {
    // Register submodule tabs for management dashboard
    registerSubmodules('Management Dashboard', [
      { id: 'dashboard', label: 'Dashboard', href: '/management/dashboard', icon: Home },
      { id: 'inbox', label: 'Inbox', href: '/inbox', icon: Inbox }
    ]);
  }, [registerSubmodules]);

  const managementStats = [
    { title: 'Total Employees', value: '247', change: '+12', changeType: 'positive', icon: Users },
    { title: 'Open Positions', value: '8', change: '+3', changeType: 'neutral', icon: AlertTriangle },
    { title: 'Avg Performance', value: '4.2/5', change: '+0.3', changeType: 'positive', icon: TrendingUp },
    { title: 'Monthly Payroll', value: '$2.4M', change: '+5%', changeType: 'positive', icon: DollarSign }
  ];

  const pendingApprovals = [
    { type: 'PTO Request', employee: 'Sarah Johnson', details: '3 days - Feb 15-17', priority: 'medium' },
    { type: 'Expense Report', employee: 'Mike Chen', details: '$1,250 - Conference travel', priority: 'high' },
    { type: 'Promotion Review', employee: 'Alex Rodriguez', details: 'Senior Developer role', priority: 'high' },
    { type: 'Budget Request', employee: 'Emily Davis', details: 'Q1 Marketing budget', priority: 'medium' }
  ];

  const teamPerformance = [
    { department: 'Engineering', performance: 92, employees: 45, trend: 'up' },
    { department: 'Product', performance: 88, employees: 12, trend: 'up' },
    { department: 'Design', performance: 85, employees: 8, trend: 'stable' },
    { department: 'Sales', performance: 78, employees: 32, trend: 'down' }
  ];

  const recentActivities = [
    { action: 'New hire onboarded', details: 'Lisa Brown joined HR department', time: '2 hours ago' },
    { action: 'Performance review completed', details: 'Q4 reviews for Engineering team', time: '1 day ago' },
    { action: 'Policy updated', details: 'Remote work policy revision', time: '2 days ago' },
    { action: 'Training completed', details: 'Security awareness training', time: '3 days ago' }
  ];

  const getPriorityColor = (priority: string) => {
    switch (priority) {
      case 'high': return 'text-red-600 bg-red-50';
      case 'medium': return 'text-orange-600 bg-orange-50';
      default: return 'text-green-600 bg-green-50';
    }
  };

  const getTrendIcon = (trend: string) => {
    switch (trend) {
      case 'up': return <TrendingUp className="h-4 w-4 text-green-500" />;
      case 'down': return <TrendingUp className="h-4 w-4 text-red-500 rotate-180" />;
      default: return <div className="h-4 w-4 rounded-full bg-gray-400" />;
    }
  };

  return (
    <div className="p-6">
      {/* Management Header */}
      <div className="mb-8">
        <h1 className="text-2xl font-bold text-foreground mb-2">Management Dashboard</h1>
        <p className="text-muted-foreground">Overview of team performance, approvals, and key metrics.</p>
      </div>

      {/* Management Stats */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
        {managementStats.map((stat, index) => (
          <div key={index} className="bg-card border border-border rounded-lg p-6">
            <div className="flex items-center justify-between mb-4">
              <stat.icon className="h-8 w-8 text-primary" />
              <div className="text-right">
                <div className="text-2xl font-bold text-foreground">{stat.value}</div>
                <div className={`text-sm ${stat.changeType === 'positive' ? 'text-green-600' : stat.changeType === 'negative' ? 'text-red-600' : 'text-gray-600'}`}>
                  {stat.change}
                </div>
              </div>
            </div>
            <div className="text-sm font-medium text-muted-foreground">{stat.title}</div>
          </div>
        ))}
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-8">
        {/* Pending Approvals */}
        <div className="bg-card border border-border rounded-lg p-6">
          <div className="flex items-center justify-between mb-6">
            <h2 className="text-lg font-semibold">Pending Approvals</h2>
            <div className="bg-red-100 text-red-800 text-xs px-2 py-1 rounded-full">
              {pendingApprovals.length} pending
            </div>
          </div>
          <div className="space-y-4">
            {pendingApprovals.map((approval, index) => (
              <div key={index} className="flex items-center justify-between p-3 bg-muted/50 rounded-lg">
                <div className="flex-1">
                  <div className="flex items-center gap-2 mb-1">
                    <span className="font-medium">{approval.type}</span>
                    <span className={`text-xs px-2 py-1 rounded-full ${getPriorityColor(approval.priority)}`}>
                      {approval.priority}
                    </span>
                  </div>
                  <div className="text-sm text-muted-foreground">{approval.employee}</div>
                  <div className="text-xs text-muted-foreground">{approval.details}</div>
                </div>
                <div className="flex gap-2">
                  <button className="px-3 py-1 text-xs bg-green-100 text-green-800 rounded hover:bg-green-200">
                    Approve
                  </button>
                  <button className="px-3 py-1 text-xs bg-red-100 text-red-800 rounded hover:bg-red-200">
                    Reject
                  </button>
                </div>
              </div>
            ))}
          </div>
        </div>

        {/* Team Performance */}
        <div className="bg-card border border-border rounded-lg p-6">
          <h2 className="text-lg font-semibold mb-6">Team Performance</h2>
          <div className="space-y-4">
            {teamPerformance.map((team, index) => (
              <div key={index} className="p-3 bg-muted/50 rounded-lg">
                <div className="flex items-center justify-between mb-2">
                  <div className="font-medium">{team.department}</div>
                  <div className="flex items-center gap-2">
                    {getTrendIcon(team.trend)}
                    <span className="font-bold text-primary">{team.performance}%</span>
                  </div>
                </div>
                <div className="flex justify-between text-sm text-muted-foreground">
                  <span>{team.employees} employees</span>
                  <span className="capitalize">{team.trend} trend</span>
                </div>
                <div className="mt-2 bg-gray-200 rounded-full h-2">
                  <div 
                    className="bg-primary rounded-full h-2 transition-all duration-300"
                    style={{ width: `${team.performance}%` }}
                  />
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* Recent Management Activities */}
      <div className="bg-card border border-border rounded-lg p-6">
        <div className="flex items-center gap-3 mb-6">
          <Clock className="h-6 w-6 text-blue-500" />
          <h2 className="text-lg font-semibold">Recent Activities</h2>
        </div>
        <div className="space-y-4">
          {recentActivities.map((activity, index) => (
            <div key={index} className="flex items-start gap-4 p-3 hover:bg-muted/50 rounded-lg transition-colors">
              <CheckCircle className="h-5 w-5 text-green-500 mt-0.5 flex-shrink-0" />
              <div className="flex-1">
                <div className="font-medium">{activity.action}</div>
                <div className="text-sm text-muted-foreground">{activity.details}</div>
              </div>
              <div className="text-xs text-muted-foreground">{activity.time}</div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
