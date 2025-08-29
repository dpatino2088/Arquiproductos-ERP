import { useEffect } from 'react';
import { useSubmoduleNav } from '../hooks/useSubmoduleNav';
import { Home, Inbox as InboxIcon, Mail, Clock, User } from 'lucide-react';
import { router } from '../lib/router';

export default function Inbox() {
  const { registerSubmodules } = useSubmoduleNav();

  useEffect(() => {
    // Get current view mode from router and register appropriate dashboard
    const viewMode = router.getViewMode();
    const dashboardHref = viewMode === 'personal' ? '/personal/dashboard' : '/management/dashboard';
    
    // Register submodule tabs for inbox
    registerSubmodules('Inbox', [
      { id: 'dashboard', label: 'Dashboard', href: dashboardHref, icon: Home },
      { id: 'inbox', label: 'Inbox', href: '/inbox', icon: InboxIcon }
    ]);
  }, [registerSubmodules]);

  const messages = [
    {
      id: 1,
      from: 'Sarah Johnson',
      subject: 'Project Update Required',
      preview: 'Hi, could you please provide an update on the current project status...',
      time: '2 hours ago',
      unread: true
    },
    {
      id: 2,
      from: 'Mike Chen',
      subject: 'Team Meeting Tomorrow',
      preview: 'Just a reminder about our team meeting scheduled for tomorrow at 3 PM...',
      time: '4 hours ago',
      unread: true
    },
    {
      id: 3,
      from: 'HR Department',
      subject: 'Performance Review Schedule',
      preview: 'Your annual performance review has been scheduled for next week...',
      time: '1 day ago',
      unread: false
    },
    {
      id: 4,
      from: 'Alex Rodriguez',
      subject: 'Code Review Request',
      preview: 'Could you please review the latest pull request when you have a moment...',
      time: '2 days ago',
      unread: false
    }
  ];

  return (
    <div className="p-6">
      <div className="mb-8">
        <h1 className="text-xl font-semibold text-foreground mb-1">Inbox</h1>
        <p className="text-xs" style={{ color: '#6B7280' }}>Manage your messages and communications</p>
      </div>

      {/* Inbox Stats */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mb-6">
        <div className="bg-card border border-border rounded-lg p-4">
          <div className="flex items-center gap-3">
            <Mail className="h-5 w-5 text-primary" />
            <div>
              <div className="text-2xl font-bold">5</div>
              <div className="text-sm text-muted-foreground">Unread</div>
            </div>
          </div>
        </div>
        <div className="bg-card border border-border rounded-lg p-4">
          <div className="flex items-center gap-3">
            <Clock className="h-5 w-5 text-orange-500" />
            <div>
              <div className="text-2xl font-bold">12</div>
              <div className="text-sm text-muted-foreground">Today</div>
            </div>
          </div>
        </div>
        <div className="bg-card border border-border rounded-lg p-4">
          <div className="flex items-center gap-3">
            <User className="h-5 w-5 text-green-500" />
            <div>
              <div className="text-2xl font-bold">3</div>
              <div className="text-sm text-muted-foreground">Important</div>
            </div>
          </div>
        </div>
      </div>

      {/* Messages List */}
      <div className="bg-card border border-border rounded-lg">
        <div className="p-4 border-b border-border">
          <h2 className="text-lg font-semibold">Messages</h2>
        </div>
        <div className="divide-y divide-border">
          {messages.map((message) => (
            <div
              key={message.id}
              className={`p-4 hover:bg-muted/50 cursor-pointer transition-colors ${
                message.unread ? 'bg-muted/20' : ''
              }`}
            >
              <div className="flex items-start justify-between gap-4">
                <div className="flex-1 min-w-0">
                  <div className="flex items-center gap-2 mb-1">
                    <span className={`font-medium ${message.unread ? 'text-foreground' : 'text-muted-foreground'}`}>
                      {message.from}
                    </span>
                    {message.unread && (
                      <div className="w-2 h-2 bg-primary rounded-full"></div>
                    )}
                  </div>
                  <div className={`font-medium mb-1 ${message.unread ? 'text-foreground' : 'text-muted-foreground'}`}>
                    {message.subject}
                  </div>
                  <div className="text-sm text-muted-foreground truncate">
                    {message.preview}
                  </div>
                </div>
                <div className="text-xs text-muted-foreground whitespace-nowrap">
                  {message.time}
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
