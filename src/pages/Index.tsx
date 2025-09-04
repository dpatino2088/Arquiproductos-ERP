import { useEffect, useCallback, useMemo } from 'react';
import {
  Users,
  Clock,
  Calendar,
  DollarSign,
  FileText,
  CheckCircle,
  UserPlus,
  Award,
  Home,
  Inbox,
  CheckSquare
} from 'lucide-react';
import { getWidgetIconColors } from '../lib/colors';
import { useSubmoduleNav } from '../hooks/useSubmoduleNav';

// Types for better type safety
interface Stat {
  title: string;
  value: string;
  change: string;
  changeType: 'positive' | 'negative' | 'neutral';
  icon: React.ComponentType<{ className?: string }>;
  type: 'total' | 'active' | 'pending' | 'urgent';
}

interface QuickAction {
  title: string;
  icon: React.ComponentType<{ className?: string }>;
  type: 'active' | 'total' | 'pending';
  onClick?: () => void;
}

interface Activity {
  action: string;
  time: string;
  type: 'timesheet' | 'onboarding' | 'review' | 'payroll';
}

interface Event {
  title: string;
  date: string;
  type: 'meeting' | 'deadline' | 'orientation';
}

interface PerformanceMetric {
  label: string;
  value: number;
  color: string;
}

export default function Dashboard() {
  const { registerSubmodules } = useSubmoduleNav();

  // Setup submodule navigation
  useEffect(() => {
    registerSubmodules('Dashboard', [
      { id: 'dashboard', label: 'Dashboard', href: '/home/dashboard', icon: Home },
      { id: 'inbox', label: 'Inbox', href: '/home/inbox', icon: Inbox },
      { id: 'tasks', label: 'Tasks', href: '/home/tasks', icon: CheckSquare }
    ]);
  }, [registerSubmodules]);

  // Memoized data to prevent recreations
  const stats: Stat[] = useMemo(() => [
    {
      title: 'Total Employees',
      value: '247',
      change: '+12',
      changeType: 'positive',
      icon: Users,
      type: 'total'
    },
    {
      title: 'Active Today',
      value: '189',
      change: '+5',
      changeType: 'positive',
      icon: Clock,
      type: 'active'
    },
    {
      title: 'On Leave',
      value: '8',
      change: '-2',
      changeType: 'positive',
      icon: Calendar,
      type: 'pending'
    },
    {
      title: 'Payroll Due',
      value: '$124.5K',
      change: 'Today',
      changeType: 'neutral',
      icon: DollarSign,
      type: 'urgent'
    }
  ], []);

  const quickActions: QuickAction[] = useMemo(() => [
    { 
      title: 'Add New Employee', 
      icon: UserPlus, 
      type: 'active',
      onClick: () => {
        if (import.meta.env.DEV) {
          console.log('Add employee clicked');
        }
      }
    },
    { 
      title: 'Process Payroll', 
      icon: DollarSign, 
      type: 'total',
      onClick: () => {
        if (import.meta.env.DEV) {
          console.log('Process payroll clicked');
        }
      }
    },
    { 
      title: 'Generate Reports', 
      icon: FileText, 
      type: 'pending',
      onClick: () => {
        if (import.meta.env.DEV) {
          console.log('Generate reports clicked');
        }
      }
    },
    { 
      title: 'Review Performance', 
      icon: Award, 
      type: 'active',
      onClick: () => {
        if (import.meta.env.DEV) {
          console.log('Review performance clicked');
        }
      }
    }
  ], []);

  const recentActivities: Activity[] = useMemo(() => [
    { action: 'Sarah Johnson submitted timesheet', time: '2 minutes ago', type: 'timesheet' },
    { action: 'New employee onboarding completed', time: '1 hour ago', type: 'onboarding' },
    { action: 'Performance review due for 5 employees', time: '3 hours ago', type: 'review' },
    { action: 'Payroll processed for March 2024', time: '1 day ago', type: 'payroll' }
  ], []);

  const upcomingEvents: Event[] = useMemo(() => [
    { title: 'Team All-Hands Meeting', date: 'Today, 2:00 PM', type: 'meeting' },
    { title: 'Q1 Performance Reviews Due', date: 'Tomorrow', type: 'deadline' },
    { title: 'New Hire Orientation', date: 'March 15, 9:00 AM', type: 'orientation' },
    { title: 'Benefits Enrollment Ends', date: 'March 20', type: 'deadline' }
  ], []);

  const performanceMetrics: PerformanceMetric[] = useMemo(() => [
    { label: 'Team Productivity', value: 92, color: 'bg-status-green' },
    { label: 'Goal Completion', value: 78, color: 'bg-neutral-gray' },
    { label: 'Employee Satisfaction', value: 85, color: 'bg-status-blue' }
  ], []);

  // Memoized dashboard content
  const renderDashboardContent = useCallback(() => (
    <>
      {/* Header */}
      <header className="flex items-center justify-between">
        <div>
          <h1 className="text-title font-semibold text-foreground">Good morning, Alex!</h1>
          <p className="text-muted-foreground" style={{ marginTop: '4px' }}>
            Here's what's happening with your team today.
          </p>
        </div>
        <div className="flex gap-2">
          <button 
            className="btn btn-primary"
            aria-label="Add new employee"
          >
            Add Employee
          </button>
          <button 
            className="btn btn-secondary"
            aria-label="Export data"
          >
            Export Data
          </button>
        </div>
      </header>

      {/* Stats Cards */}
      <section aria-label="Key statistics" className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
        {stats.map((stat, index) => {
          const Icon = stat.icon;
          return (
            <article key={index} className="bg-card rounded-lg p-4 border border-border hover:shadow-lg transition-shadow">
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-3">
                  <div className={`p-2 rounded-lg ${getWidgetIconColors(stat.type)}`}>
                    <Icon className="w-4 h-4" />
                  </div>
                  <div>
                    <h3 className="text-body font-semibold text-foreground">{stat.title}</h3>
                    <span className={`text-small font-medium ${
                      stat.changeType === 'positive' ? 'text-status-green' :
                      stat.changeType === 'negative' ? 'text-status-red' :
                      'text-muted-foreground'
                    }`}>
                      {stat.change}
                    </span>
                  </div>
                </div>
                <p className="text-xl font-bold text-foreground">{stat.value}</p>
              </div>
            </article>
          );
        })}
      </section>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Quick Actions */}
        <section aria-label="Quick actions" className="bg-card rounded-xl p-6 border border-border">
          <h2 className="text-lg font-semibold text-foreground mb-4">Quick Actions</h2>
          <div className="grid grid-cols-2 gap-4">
            {quickActions.map((action, index) => {
              const Icon = action.icon;
              return (
                <button
                  key={index}
                  className="p-4 border border-border rounded-lg hover:bg-muted transition-colors text-left group"
                  onClick={action.onClick}
                  aria-label={action.title}
                >
                  <div className={`w-10 h-10 rounded-lg flex items-center justify-center mb-3 transition-colors ${
                    getWidgetIconColors(action.type)
                  }`}>
                    <Icon className="w-5 h-5" />
                  </div>
                  <p className="text-sm font-medium text-foreground">{action.title}</p>
                </button>
              );
            })}
          </div>
        </section>

        {/* Recent Activity */}
        <section aria-label="Recent activity" className="bg-card rounded-xl p-6 border border-border">
          <h2 className="text-lg font-semibold text-foreground mb-4">Recent Activity</h2>
          <div className="space-y-4">
            {recentActivities.map((activity, index) => (
              <article key={index} className="flex items-start space-x-3">
                <div className="w-2 h-2 bg-status-green rounded-full mt-2" aria-hidden="true"></div>
                <div className="flex-1 min-w-0">
                  <p className="text-sm text-foreground">{activity.action}</p>
                  <p className="text-xs text-muted-foreground mt-1">{activity.time}</p>
                </div>
              </article>
            ))}
          </div>
          <button 
            className="mt-4 text-sm text-status-green font-medium hover:text-status-green/80"
            aria-label="View all activity"
          >
            View all activity
          </button>
        </section>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Upcoming Events */}
        <section aria-label="Upcoming events" className="lg:col-span-2 bg-card rounded-xl p-6 border border-border">
          <h2 className="text-lg font-semibold text-foreground mb-4">Upcoming Events</h2>
          <div className="space-y-4">
            {upcomingEvents.map((event, index) => (
              <article key={index} className="flex items-center justify-between p-4 bg-muted rounded-lg">
                <div className="flex items-center space-x-3">
                  <div className={`w-3 h-3 rounded-full ${
                    event.type === 'meeting' ? 'bg-status-green' :
                    event.type === 'deadline' ? 'bg-status-red' :
                    'bg-status-blue'
                  }`} aria-hidden="true"></div>
                  <div>
                    <p className="text-sm font-medium text-foreground">{event.title}</p>
                    <p className="text-xs text-muted-foreground mt-1">{event.date}</p>
                  </div>
                </div>
                <button 
                  className="text-muted-foreground hover:text-foreground"
                  aria-label={`Mark ${event.title} as complete`}
                >
                  <CheckCircle className="w-4 h-4" />
                </button>
              </article>
            ))}
          </div>
        </section>

        {/* Performance Overview */}
        <section aria-label="Performance overview" className="bg-card rounded-xl p-6 border border-border">
          <h2 className="text-lg font-semibold text-foreground mb-4">Performance Overview</h2>
          <div className="space-y-4">
            {performanceMetrics.map((metric, index) => (
              <div key={index} className="space-y-2">
                <div className="flex items-center justify-between">
                  <span className="text-sm text-muted-foreground">{metric.label}</span>
                  <span className="text-sm font-medium text-status-green">{metric.value}%</span>
                </div>
                <div className="w-full bg-muted rounded-full h-2">
                  <div 
                    className={`${metric.color} h-2 rounded-full transition-all duration-300`} 
                    style={{ width: `${metric.value}%` }}
                    role="progressbar"
                    aria-valuenow={metric.value}
                    aria-valuemin={0}
                    aria-valuemax={100}
                    aria-label={`${metric.label}: ${metric.value}%`}
                  ></div>
                </div>
              </div>
            ))}
          </div>
          
          <button 
            className="mt-4 text-sm text-foreground font-medium hover:text-foreground/80"
            aria-label="View detailed reports"
          >
            View detailed reports
          </button>
        </section>
      </div>
    </>
  ), [stats, quickActions, recentActivities, upcomingEvents, performanceMetrics]);

  // Memoized content renderer - always show dashboard content for this page
  const renderContent = useCallback(() => {
    return renderDashboardContent();
  }, [renderDashboardContent]);

  return (
    <main className="flex flex-col space-y-6" role="main">
      {/* Content */}
      {renderContent()}
    </main>
  );
}

// Placeholder components for other modules (unused but kept for reference)
function _InboxContent() {
  return (
    <div className="space-y-6">
      <h2 className="text-2xl font-bold text-foreground">Inbox</h2>
      <div className="bg-card border border-border rounded-lg p-6">
        <p className="text-muted-foreground">No new messages at this time.</p>
      </div>
    </div>
  );
}

function _TasksContent() {
  return (
    <div className="space-y-6">
      <h2 className="text-2xl font-bold text-foreground">Tasks</h2>
      <div className="bg-card border border-border rounded-lg p-6">
        <p className="text-muted-foreground">All tasks are up to date.</p>
      </div>
    </div>
  );
}
