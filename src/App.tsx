import React, { useState, useEffect, Suspense, lazy } from 'react';
import { useAuth } from './hooks/useAuth';
import { SecureForm } from './components/ui/SecureForm';
import Layout from './components/Layout';
import ErrorBoundary from './components/ErrorBoundary';
import { router } from './lib/router';
import { SubmoduleNavProvider } from './hooks/useSubmoduleNav';
import { logger } from './lib/logger';
import { useUIStore } from './stores/ui-store';

// Code splitting with React.lazy
const EmployeeDashboard = lazy(() => {
  logger.debug('Loading EmployeeDashboard component');
  return import('./pages/org/cmp/employee/Dashboard');
});

const ManagementDashboard = lazy(() => {
  logger.debug('Loading ManagementDashboard component');
  return import('./pages/org/cmp/management/Dashboard');
});

const GroupDashboard = lazy(() => {
  logger.debug('Loading GroupDashboard component');
  return import('./pages/org/grp/Dashboard');
});

const GroupCompanies = lazy(() => {
  logger.debug('Loading GroupCompanies component');
  return import('./pages/org/grp/Companies');
});

const GroupReports = lazy(() => {
  logger.debug('Loading GroupReports component');
  return import('./pages/org/grp/Reports');
});

const GroupSettings = lazy(() => {
  logger.debug('Loading GroupSettings component');
  return import('./pages/org/grp/Settings');
});

const VapDashboard = lazy(() => {
  logger.debug('Loading VapDashboard component');
  return import('./pages/org/vap/Dashboard');
});

const VapCompanies = lazy(() => {
  logger.debug('Loading VapCompanies component');
  return import('./pages/org/vap/Companies');
});

const VapReports = lazy(() => {
  logger.debug('Loading VapReports component');
  return import('./pages/org/vap/Reports');
});

const VapSettings = lazy(() => {
  logger.debug('Loading VapSettings component');
  return import('./pages/org/vap/Settings');
});

const RpDashboard = lazy(() => {
  logger.debug('Loading RpDashboard component');
  return import('./pages/org/rp/Dashboard');
});

const RpCompanies = lazy(() => {
  logger.debug('Loading RpCompanies component');
  return import('./pages/org/rp/Companies');
});

const RpReports = lazy(() => {
  logger.debug('Loading RpReports component');
  return import('./pages/org/rp/Reports');
});

const RpSettings = lazy(() => {
  logger.debug('Loading RpSettings component');
  return import('./pages/org/rp/Settings');
});


const Inbox = lazy(() => {
  logger.debug('Loading Inbox component');
  return import('./pages/org/cmp/Inbox');
});

// Auth pages
const Login = lazy(() => {
  logger.debug('Loading Login component');
  return import('./pages/auth/Login');
});

const ResetPassword = lazy(() => {
  logger.debug('Loading ResetPassword component');
  return import('./pages/auth/ResetPassword');
});

const NewPassword = lazy(() => {
  logger.debug('Loading NewPassword component');
  return import('./pages/auth/NewPassword');
});

// Error pages
const BadRequest = lazy(() => {
  logger.debug('Loading BadRequest component');
  return import('./pages/error-pages/BadRequest');
});

const Unauthorized = lazy(() => {
  logger.debug('Loading Unauthorized component');
  return import('./pages/error-pages/Unauthorized');
});

const Forbidden = lazy(() => {
  logger.debug('Loading Forbidden component');
  return import('./pages/error-pages/Forbidden');
});

const NotFound = lazy(() => {
  logger.debug('Loading NotFound component');
  return import('./pages/error-pages/NotFound');
});

const InternalServerError = lazy(() => {
  logger.debug('Loading InternalServerError component');
  return import('./pages/error-pages/InternalServerError');
});

const BadGateway = lazy(() => {
  logger.debug('Loading BadGateway component');
  return import('./pages/error-pages/BadGateway');
});

const ServiceUnavailable = lazy(() => {
  logger.debug('Loading ServiceUnavailable component');
  return import('./pages/error-pages/ServiceUnavailable');
});

const GatewayTimeout = lazy(() => {
  logger.debug('Loading GatewayTimeout component');
  return import('./pages/error-pages/GatewayTimeout');
});

const MyInfo = lazy(() => {
  logger.debug('Loading MyInfo component');
  return import('./pages/org/cmp/employee/MyInfo');
});

const Directory = lazy(() => {
  logger.debug('Loading Directory component');
  return import('./pages/org/cmp/management/employees/Directory');
});

const EmployeeInfo = lazy(() => {
  logger.debug('Loading EmployeeInfo component');
  return import('./pages/org/cmp/management/employees/EmployeeInfo');
});

const OrganizationalChart = lazy(() => {
  logger.debug('Loading OrganizationalChart component');
  return import('./pages/org/cmp/management/employees/OrganizationalChart');
});

const WhosWorking = lazy(() => {
  logger.debug('Loading Whos Working component');
  return import('./pages/org/cmp/management/time-and-attendance/WhosWorking');
});

const TeamSchedule = lazy(() => {
  logger.debug('Loading Team Schedule component');
  return import('./pages/org/cmp/management/time-and-attendance/TeamSchedule');
});

const TeamAttendance = lazy(() => {
  logger.debug('Loading Team Attendance component');
  return import('./pages/org/cmp/management/time-and-attendance/TeamAttendance');
});

const AttendanceFlags = lazy(() => {
  logger.debug('Loading Attendance Flags component');
  return import('./pages/org/cmp/management/time-and-attendance/AttendanceFlags');
});


const EmployeeTimesheet = lazy(() => {
  logger.debug('Loading Employee Timesheet component');
  return import('./pages/org/cmp/management/time-and-attendance/EmployeeTimesheet');
});


const TeamLeaveCalendar = lazy(() => {
  logger.debug('Loading Team Leave Calendar component');
  return import('./pages/org/cmp/management/pto-and-leaves/TeamLeaveCalendar');
});

const TeamLeaveRequests = lazy(() => {
  logger.debug('Loading Team Leave Requests component');
  return import('./pages/org/cmp/management/pto-and-leaves/TeamLeaveRequests');
});

const TeamBalances = lazy(() => {
  logger.debug('Loading Team Balances component');
  return import('./pages/org/cmp/management/pto-and-leaves/TeamBalances');
});

const TeamDevices = lazy(() => {
  logger.debug('Loading Team Devices component');
  return import('./pages/org/cmp/management/it-management/TeamDevices');
});

const TeamLicenses = lazy(() => {
  logger.debug('Loading Team Licenses component');
  return import('./pages/org/cmp/management/it-management/TeamLicenses');
});

const TeamITRequests = lazy(() => {
  logger.debug('Loading Team IT Requests component');
  return import('./pages/org/cmp/management/it-management/TeamITRequests');
});

const TeamExpenses = lazy(() => {
  logger.debug('Loading Team Expenses component');
  return import('./pages/org/cmp/management/expenses/TeamExpenses');
});

const TeamGoalsAndPerformance = lazy(() => {
  logger.debug('Loading Team Goals and Performance component');
  return import('./pages/org/cmp/management/performance/TeamGoalsAndPerformance');
});

const TeamReviews = lazy(() => {
  logger.debug('Loading Team Reviews component');
  return import('./pages/org/cmp/management/performance/TeamReviews');
});

const TeamFeedbackAndRecognition = lazy(() => {
  logger.debug('Loading Team Feedback and Recognition component');
  return import('./pages/org/cmp/management/performance/TeamFeedbackAndRecognition');
});

const TeamOneOnOne = lazy(() => {
  logger.debug('Loading Team One-on-One component');
  return import('./pages/org/cmp/management/performance/TeamOneOnOne');
});

const TeamResponsibilities = lazy(() => {
  logger.debug('Loading Team Responsibilities component');
  return import('./pages/org/cmp/management/company-knowledge/TeamResponsibilities');
});

const TeamKnowledgeCompliance = lazy(() => {
  logger.debug('Loading Team Knowledge Compliance component');
  return import('./pages/org/cmp/management/company-knowledge/TeamKnowledgeCompliance');
});

const AboutTheCompany = lazy(() => {
  logger.debug('Loading About the Company component');
  return import('./pages/org/cmp/AboutTheCompany');
});

const TeamBenefits = lazy(() => {
  logger.debug('Loading Team Benefits component');
  return import('./pages/org/cmp/management/benefits/TeamBenefits');
});

const TeamRequests = lazy(() => {
  logger.debug('Loading Team Requests component');
  return import('./pages/org/cmp/management/benefits/TeamRequests');
});

const PayrollWizards = lazy(() => {
  logger.debug('Loading Payroll Wizards component');
  return import('./pages/org/cmp/management/payroll/PayrollWizards');
});

const CompanyReports = lazy(() => {
  logger.debug('Loading Company Reports component');
  return import('./pages/org/cmp/management/reports/CompanyReports');
});

const CompanySettings = lazy(() => {
  logger.debug('Loading Company Settings component');
  return import('./pages/org/cmp/management/settings/CompanySettings');
});

const JobOpenings = lazy(() => {
  logger.debug('Loading Job Openings component');
  return import('./pages/org/cmp/management/recruitment/JobOpenings');
});

const Candidates = lazy(() => {
  logger.debug('Loading Candidates component');
  return import('./pages/org/cmp/management/recruitment/Candidates');
});

const Onboarding = lazy(() => {
  logger.debug('Loading Onboarding component');
  return import('./pages/org/cmp/management/recruitment/Onboarding');
});

const MyClock = lazy(() => {
  logger.debug('Loading My Clock component');
  return import('./pages/org/cmp/employee/time-and-attendance/MyClock');
});

const MyPlanner = lazy(() => {
  logger.debug('Loading My Planner component');
  return import('./pages/org/cmp/employee/time-and-attendance/MyPlanner');
});

const MyAttendance = lazy(() => {
  logger.debug('Loading My Attendance component');
  return import('./pages/org/cmp/employee/time-and-attendance/MyAttendance');
});

const MyRequests = lazy(() => {
  logger.debug('Loading My Requests component');
  return import('./pages/org/cmp/employee/pto-and-leaves/MyRequests');
});

const MyBalance = lazy(() => {
  logger.debug('Loading My Balance component');
  return import('./pages/org/cmp/employee/pto-and-leaves/MyBalance');
});

const MyResponsibility = lazy(() => {
  logger.debug('Loading My Responsibility component');
  return import('./pages/org/cmp/employee/company-knowledge/MyResponsibility');
});

const ProcessesAndPolicies = lazy(() => {
  logger.debug('Loading Processes and Policies component');
  return import('./pages/org/cmp/employee/company-knowledge/ProcessesAndPolicies');
});

const DocumentsAndFiles = lazy(() => {
  logger.debug('Loading Documents and Files component');
  return import('./pages/org/cmp/employee/company-knowledge/DocumentsAndFiles');
});

const CoursesAndTraining = lazy(() => {
  logger.debug('Loading Courses and Training component');
  return import('./pages/org/cmp/employee/company-knowledge/CoursesAndTraining');
});

const MyPerformance = lazy(() => {
  logger.debug('Loading My Performance component');
  return import('./pages/org/cmp/employee/performance/MyPerformance');
});

const MyFeedbackAndRecognition = lazy(() => {
  logger.debug('Loading My Feedback and Recognition component');
  return import('./pages/org/cmp/employee/performance/MyFeedbackAndRecognition');
});

const MyOneOnOne = lazy(() => {
  logger.debug('Loading My One-on-One component');
  return import('./pages/org/cmp/employee/performance/MyOneOnOne');
});

const MyBenefits = lazy(() => {
  logger.debug('Loading My Benefits component');
  return import('./pages/org/cmp/employee/benefits/MyBenefits');
});

const MyExpenses = lazy(() => {
  logger.debug('Loading My Expenses component');
  return import('./pages/org/cmp/employee/expenses/MyExpenses');
});

const MyDevices = lazy(() => {
  logger.debug('Loading My Devices component');
  return import('./pages/org/cmp/employee/it-management/MyDevices');
});

const MyLicenses = lazy(() => {
  logger.debug('Loading My Licenses component');
  return import('./pages/org/cmp/employee/it-management/MyLicenses');
});

const MyITRequests = lazy(() => {
  logger.debug('Loading My IT Requests component');
  return import('./pages/org/cmp/employee/it-management/MyITRequests');
});

const FinancialWellness = lazy(() => {
  logger.debug('Loading Financial Wellness component');
  return import('./pages/org/cmp/employee/wellness/FinancialWellness');
});

const MentalHealth = lazy(() => {
  logger.debug('Loading Mental Health component');
  return import('./pages/org/cmp/employee/wellness/MentalHealth');
});

const Fitness = lazy(() => {
  logger.debug('Loading Fitness component');
  return import('./pages/org/cmp/employee/wellness/Fitness');
});

const Nutrition = lazy(() => {
  logger.debug('Loading Nutrition component');
  return import('./pages/org/cmp/employee/wellness/Nutrition');
});



function ThemeToggle() {
  const [theme, setTheme] = React.useState(() => localStorage.getItem('theme') || 'light');
  React.useEffect(() => {
    document.documentElement.setAttribute('data-theme', theme);
    localStorage.setItem('theme', theme);
  }, [theme]);
  return (
    <button
      className="rounded-xl px-4 py-2 shadow-card border border-border bg-primary text-primary-foreground"
      onClick={() => setTheme(theme === 'light' ? 'dark' : 'light')}
      aria-label="Toggle theme"
    >
      Toggle theme
    </button>
  );
}

function AuthForms() {
  const [isLogin, setIsLogin] = useState(true);
  const { login, register, isLoading, error, clearError } = useAuth();

  const handleSubmit = (data: { email: string; password: string; name?: string; confirmPassword?: string }) => {
    if (import.meta.env.DEV) {
    console.log('Form submitted:', data);
    }
    if (isLogin) {
      login({ email: data.email, password: data.password });
    } else {
      register({
        email: data.email,
        password: data.password,
        name: data.name || '',
        confirmPassword: data.confirmPassword || ''
      });
    }
  };

  return (
    <div className="w-full max-w-md mx-auto">
      <div className="mb-6 text-center">
        <h2 className="text-2xl font-bold text-foreground mb-2">
          {isLogin ? 'Welcome Back' : 'Create Account'}
        </h2>
        <p className="text-muted-foreground">
          {isLogin ? 'Sign in to your secure account' : 'Get started with your secure account'}
        </p>
      </div>

      <SecureForm
        type={isLogin ? 'login' : 'register'}
        onSubmit={handleSubmit}
        isLoading={isLoading}
        error={error}
        onClearError={clearError}
      />

      <div className="mt-6 text-center">
        <button
          type="button"
          onClick={() => setIsLogin(!isLogin)}
          className="text-primary hover:underline text-sm"
        >
          {isLogin ? "Don't have an account? Sign up" : 'Already have an account? Sign in'}
        </button>
      </div>
    </div>
  );
}

function _UserDashboard() {
  const { user, logout } = useAuth();

  return (
    <div className="w-full max-w-4xl mx-auto">
      <div className="bg-card border border-border rounded-lg p-6 shadow-card">
        <div className="flex items-center justify-between mb-6">
          <div>
            <h2 className="text-2xl font-bold text-foreground">Welcome, {user?.name}!</h2>
            <p className="text-muted-foreground">Your secure dashboard</p>
          </div>
          <div className="flex items-center gap-4">
            <ThemeToggle />
            <button
              onClick={logout}
              className="px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 transition-colors"
            >
              Sign Out
            </button>
          </div>
        </div>

        <div className="grid md:grid-cols-2 gap-6">
          <div className="bg-muted p-4 rounded-lg">
            <h3 className="font-semibold text-foreground mb-2">Account Information</h3>
            <div className="space-y-2 text-sm">
              <p><span className="text-muted-foreground">Email:</span> {user?.email}</p>
              <p><span className="text-muted-foreground">Role:</span> {user?.role}</p>
              <p><span className="text-muted-foreground">User ID:</span> {user?.id}</p>
            </div>
          </div>

          <div className="bg-muted p-4 rounded-lg">
            <h3 className="font-semibold text-foreground mb-2">Security Status</h3>
            <div className="space-y-2 text-sm">
              <p className="flex items-center gap-2">
                <span className="w-2 h-2 bg-green-500 rounded-full"></span>
                Authentication: Active
              </p>
              <p className="flex items-center gap-2">
                <span className="w-2 h-2 bg-green-500 rounded-full"></span>
                Session: Valid
              </p>
              <p className="flex items-center gap-2">
                <span className="w-2 h-2 bg-green-500 rounded-full"></span>
                CSRF Protection: Enabled
              </p>
            </div>
          </div>
        </div>

        <div className="mt-6 p-4 bg-blue-50 border border-blue-200 rounded-lg">
          <h3 className="font-semibold text-blue-900 mb-2">Security Features Implemented</h3>
          <ul className="text-sm text-blue-800 space-y-1">
            <li>• Input validation and sanitization</li>
            <li>• CSRF token protection</li>
            <li>• Secure password requirements</li>
            <li>• Rate limiting capabilities</li>
            <li>• Content Security Policy (CSP)</li>
            <li>• XSS protection headers</li>
          </ul>
        </div>
      </div>
    </div>
  );
}

function App() {
  const { isAuthenticated, user, isLoading } = useAuth();
  const { setViewMode } = useUIStore();
  const [currentPage, setCurrentPage] = useState('dashboard');

  if (import.meta.env.DEV) {
  console.log('App render - isAuthenticated:', isAuthenticated, 'user:', user, 'isLoading:', isLoading);
  }

  // Setup routing
  useEffect(() => {
    if (isAuthenticated) {
      // Initialize router view mode to match UI store
      const { viewMode } = useUIStore.getState();
      router.setViewMode(viewMode);
      if (import.meta.env.DEV) {
      console.log('Router initialized with view mode:', viewMode);
      }
      
      // Set up view mode change handler to sync router changes with UI store
      router.setViewModeChangeHandler((newViewMode) => {
        if (import.meta.env.DEV) {
        console.log('Router detected view mode change, updating UI store:', newViewMode);
        }
        setViewMode(newViewMode);
      });
      
      // Set up unauthorized redirect handler
      router.setUnauthorizedRedirectHandler(() => {
        if (import.meta.env.DEV) {
        console.log('Unauthorized access attempt blocked - redirecting to employee dashboard');
        }
        setCurrentPage('employee-dashboard');
      });
      
      // Set up routes - default route goes to employee dashboard
      router.addRoute('/', () => setCurrentPage('employee-dashboard'));
      
      // Auth routes
      router.addRoute('/login', () => setCurrentPage('login'));
      router.addRoute('/reset-password', () => setCurrentPage('reset-password'));
      router.addRoute('/new-password', () => setCurrentPage('new-password'));
      
      // Error routes
      router.addRoute('/400', () => setCurrentPage('bad-request'));
      router.addRoute('/401', () => setCurrentPage('unauthorized'));
      router.addRoute('/403', () => setCurrentPage('forbidden'));
      router.addRoute('/404', () => setCurrentPage('not-found'));
      router.addRoute('/500', () => setCurrentPage('internal-server-error'));
      router.addRoute('/502', () => setCurrentPage('bad-gateway'));
      router.addRoute('/503', () => setCurrentPage('service-unavailable'));
      router.addRoute('/504', () => setCurrentPage('gateway-timeout'));
      
      // 404 route handler for unknown routes
      router.addRoute('*', () => setCurrentPage('not-found'));
      // Specific inbox routes for each view mode
      router.addRoute('/org/cmp/management/inbox', () => setCurrentPage('inbox'));
      router.addRoute('/org/cmp/employee/inbox', () => setCurrentPage('inbox'));
      
      // Employee view routes
      router.addRoute('/org/cmp/employee/dashboard', () => setCurrentPage('employee-dashboard'));
      router.addRoute('/org/cmp/employee/my-info', () => setCurrentPage('my-info'));
      
      
      // Legacy employee routes (redirect to new path)
      router.addRoute('/org/cmp/employee/my-info', () => setCurrentPage('my-info'));
      
      // Management view routes
      router.addRoute('/org/cmp/management/dashboard', () => setCurrentPage('management-dashboard'));
      router.addRoute('/org/cmp/management/employees/directory', () => setCurrentPage('directory'));
      router.addRoute('/org/cmp/management/it-management/team-devices', () => setCurrentPage('team-devices'));
        router.addRoute('/org/cmp/management/employees/employee-info/:slug', () => setCurrentPage('employee-info'));
        router.addRoute('/org/cmp/management/employees/employee-info', () => setCurrentPage('employee-info'));
      router.addRoute('/org/cmp/management/employees/organizational-chart', () => setCurrentPage('org-chart'));

      // Group view routes (viewMode auto-inferred from URL)
      router.addRoute('/org/grp/dashboard', () => setCurrentPage('group-dashboard'));
      router.addRoute('/org/grp/companies', () => setCurrentPage('group-companies'));
      router.addRoute('/org/grp/reports', () => setCurrentPage('group-reports'));
      router.addRoute('/org/grp/settings', () => setCurrentPage('group-settings'));

      // VAP view routes (viewMode auto-inferred from URL)
      router.addRoute('/org/vap/dashboard', () => setCurrentPage('vap-dashboard'));
      router.addRoute('/org/vap/companies', () => setCurrentPage('vap-companies'));
      router.addRoute('/org/vap/reports', () => setCurrentPage('vap-reports'));
      router.addRoute('/org/vap/settings', () => setCurrentPage('vap-settings'));

      // RP view routes (viewMode auto-inferred from URL)
      router.addRoute('/org/rp/dashboard', () => setCurrentPage('rp-dashboard'));
      router.addRoute('/org/rp/companies', () => setCurrentPage('rp-companies'));
      router.addRoute('/org/rp/reports', () => setCurrentPage('rp-reports'));
      router.addRoute('/org/rp/settings', () => setCurrentPage('rp-settings'));

      
      // Management routes
      router.addRoute('/org/cmp/management/reports', () => setCurrentPage('reports'));
      
      // Time & Attendance routes
      router.addRoute('/org/cmp/management/time-and-attendance/whos-working', () => setCurrentPage('whos-working'));
      router.addRoute('/org/cmp/management/time-and-attendance/team-schedule', () => setCurrentPage('team-schedule'));
      router.addRoute('/org/cmp/management/time-and-attendance/team-attendance', () => setCurrentPage('team-attendance'));
      router.addRoute('/org/cmp/management/time-and-attendance/attendance-flags', () => setCurrentPage('attendance-flags'));
      router.addRoute('/org/cmp/management/time-and-attendance/employee-timesheet/:slug', () => setCurrentPage('employee-timesheet'));
      router.addRoute('/org/cmp/management/time-and-attendance/employee-timesheet', () => setCurrentPage('employee-timesheet'));
      
      // PTO & Leaves routes
      router.addRoute('/org/cmp/management/pto-and-leaves/team-leave-calendar', () => setCurrentPage('team-leave-calendar'));
      router.addRoute('/org/cmp/management/pto-and-leaves/team-leave-requests', () => setCurrentPage('team-leave-requests'));
      router.addRoute('/org/cmp/management/pto-and-leaves/team-balances', () => setCurrentPage('team-balances'));
      
      // Performance routes
      router.addRoute('/org/cmp/management/performance/team-goals-and-performance', () => setCurrentPage('team-goals'));
      router.addRoute('/org/cmp/management/performance/team-reviews', () => setCurrentPage('team-reviews'));
      router.addRoute('/org/cmp/management/performance/team-feedback-and-recognition', () => setCurrentPage('team-feedback-and-recognition'));
      router.addRoute('/org/cmp/management/performance/team-one-on-one', () => setCurrentPage('team-one-on-one'));
      
      // Company Knowledge routes
      router.addRoute('/org/cmp/management/company-knowledge/about-the-company', () => setCurrentPage('about-company'));
      router.addRoute('/org/cmp/employee/company-knowledge/about-the-company', () => setCurrentPage('about-company'));
      router.addRoute('/org/cmp/management/company-knowledge/team-responsibilities', () => setCurrentPage('team-responsibilities'));
      router.addRoute('/org/cmp/management/company-knowledge/team-knowledge-compliance', () => setCurrentPage('team-knowledge-compliance'));
      
      // Benefits routes
      router.addRoute('/org/cmp/management/benefits/team-benefits', () => setCurrentPage('team-benefits'));
      router.addRoute('/org/cmp/management/benefits/team-requests', () => setCurrentPage('team-requests'));
      
      // Expenses routes
      router.addRoute('/org/cmp/management/expenses/team-expenses', () => setCurrentPage('team-expenses'));
      
      // IT Management routes
      router.addRoute('/org/cmp/management/it-management/team-devices', () => setCurrentPage('team-devices'));
      router.addRoute('/org/cmp/management/it-management/team-licenses', () => setCurrentPage('team-licenses'));
      router.addRoute('/org/cmp/management/it-management/team-it-requests', () => setCurrentPage('team-it-requests'));
      
      // Payroll routes
      router.addRoute('/org/cmp/management/payroll/payroll-wizards', () => setCurrentPage('payroll-wizards'));
      
      // Reports routes
      router.addRoute('/org/cmp/management/reports/company-reports', () => setCurrentPage('company-reports'));
      
      // Settings routes
      router.addRoute('/org/cmp/management/settings/company-settings', () => setCurrentPage('company-settings'));
      
      // Recruitment routes
      router.addRoute('/org/cmp/management/recruitment/job-openings', () => setCurrentPage('job-openings'));
      router.addRoute('/org/cmp/management/recruitment/candidates', () => setCurrentPage('candidates'));
      router.addRoute('/org/cmp/management/recruitment/onboarding', () => setCurrentPage('onboarding'));
      
      // Employee Time & Attendance routes
      router.addRoute('/org/cmp/employee/time-and-attendance/my-clock', () => setCurrentPage('my-clock'));
      router.addRoute('/org/cmp/employee/time-and-attendance/my-planner', () => setCurrentPage('my-planner'));
      router.addRoute('/org/cmp/employee/time-and-attendance/my-attendance', () => setCurrentPage('my-attendance'));
      
      // Employee PTO & Leaves routes
      router.addRoute('/org/cmp/employee/pto-and-leaves/my-requests', () => setCurrentPage('my-requests'));
      router.addRoute('/org/cmp/employee/pto-and-leaves/my-balance', () => setCurrentPage('my-balance'));
      
      // Employee Company Knowledge routes
      router.addRoute('/org/cmp/employee/company-knowledge/my-responsibility', () => setCurrentPage('my-responsibility'));
      router.addRoute('/org/cmp/employee/company-knowledge/processes-and-policies', () => setCurrentPage('processes-policies'));
      router.addRoute('/org/cmp/employee/company-knowledge/documents-and-files', () => setCurrentPage('documents-files'));
      router.addRoute('/org/cmp/employee/company-knowledge/courses-and-training', () => setCurrentPage('courses-training'));
      
      // Employee Performance routes
      router.addRoute('/org/cmp/employee/performance/my-performance', () => setCurrentPage('my-performance'));
      router.addRoute('/org/cmp/employee/performance/my-feedback-and-recognition', () => setCurrentPage('my-feedback-recognition'));
      router.addRoute('/org/cmp/employee/performance/my-one-on-one', () => setCurrentPage('my-one-on-one'));
      
      // Employee Benefits routes
      router.addRoute('/org/cmp/employee/benefits/my-benefits', () => setCurrentPage('my-benefits'));
      
      // Employee Expenses routes
      router.addRoute('/org/cmp/employee/expenses/my-expenses', () => setCurrentPage('my-expenses'));
      
      // Employee IT Management routes
      router.addRoute('/org/cmp/employee/it-management/my-devices', () => setCurrentPage('my-devices'));
      router.addRoute('/org/cmp/employee/it-management/my-licenses', () => setCurrentPage('my-licenses'));
      router.addRoute('/org/cmp/employee/it-management/my-it-requests', () => setCurrentPage('my-it-requests'));

      // Employee Wellness routes
      router.addRoute('/org/cmp/employee/wellness/financial-wellness', () => setCurrentPage('financial-wellness'));
      router.addRoute('/org/cmp/employee/wellness/mental-health', () => setCurrentPage('mental-health'));
      router.addRoute('/org/cmp/employee/wellness/fitness', () => setCurrentPage('fitness'));
      router.addRoute('/org/cmp/employee/wellness/nutrition', () => setCurrentPage('nutrition'));
      
      // Legacy routes (still supported)
      router.addRoute('/employees', () => setCurrentPage('employees'));
      router.addRoute('/reports', () => setCurrentPage('reports')); // Legacy route redirects to same page
      
      // Protected routes (management only)
      router.addRoute('/payroll', () => setCurrentPage('employee-dashboard')); // This will be blocked by route guard
      
      // Other routes - redirect to employee dashboard for now
      router.addRoute('/time-tracking', () => setCurrentPage('employee-dashboard'));
      router.addRoute('/pto', () => setCurrentPage('employee-dashboard'));
      router.addRoute('/knowledge-hub', () => setCurrentPage('employee-dashboard'));
      router.addRoute('/performance', () => setCurrentPage('employee-dashboard'));
      router.addRoute('/benefits', () => setCurrentPage('employee-dashboard'));
      router.addRoute('/wellness', () => setCurrentPage('fitness'));
      router.addRoute('/expenses', () => setCurrentPage('employee-dashboard'));
      router.addRoute('/it-management', () => setCurrentPage('employee-dashboard'));
      router.addRoute('/settings', () => setCurrentPage('employee-dashboard'));
      
      // Initialize router
      router.init();
      
      // Add listener for route changes to sync with current page
      const unsubscribe = router.addListener(() => {
        // This ensures the UI updates when router redirects
        const currentRoute = router.getCurrentRoute();
        if (import.meta.env.DEV) {
        console.log('Route changed to:', currentRoute);
        }
      });
      
      return () => {
        if (unsubscribe) unsubscribe();
      };
    }
  }, [isAuthenticated]);

  // Monitor URL changes and trigger router navigation (for direct navigation like tests)
  useEffect(() => {
    if (!isAuthenticated) return;

    const handleLocationChange = () => {
      const currentPath = window.location.pathname;
      const routerPath = router.getCurrentRoute();
      
      // If URL changed but router hasn't been notified, trigger navigation
      if (currentPath !== routerPath) {
        if (import.meta.env.DEV) {
        console.log('Direct navigation detected:', currentPath, '-> triggering router navigation');
        }
        router.navigate(currentPath, false);
      }
    };

    // Check on initial load and when URL changes
    handleLocationChange();
    
    // Set up interval to check for URL changes (fallback for direct navigation)
    const interval = setInterval(handleLocationChange, 100);
    
    return () => clearInterval(interval);
  }, [isAuthenticated, currentPage]);

  if (isLoading) {
    return (
      <div className="min-h-screen bg-background flex items-center justify-center">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary mx-auto mb-4"></div>
          <p className="text-muted-foreground">Loading...</p>
        </div>
      </div>
    );
  }

  const renderPage = () => {
    switch (currentPage) {
      // Auth pages
      case 'login':
        return <Login />;
      case 'reset-password':
        return <ResetPassword />;
      case 'new-password':
        return <NewPassword />;
      
      // Error pages
      case 'bad-request':
        return <BadRequest />;
      case 'unauthorized':
        return <Unauthorized />;
      case 'forbidden':
        return <Forbidden />;
      case 'not-found':
        return <NotFound />;
      case 'internal-server-error':
        return <InternalServerError />;
      case 'bad-gateway':
        return <BadGateway />;
      case 'service-unavailable':
        return <ServiceUnavailable />;
      case 'gateway-timeout':
        return <GatewayTimeout />;
      
      // Dashboard pages
      case 'employee-dashboard':
        return <EmployeeDashboard />;
      case 'management-dashboard':
        return <ManagementDashboard />;
      case 'group-dashboard':
        return <GroupDashboard />;
      case 'group-companies':
        return <GroupCompanies />;
      case 'group-reports':
        return <GroupReports />;
      case 'group-settings':
        return <GroupSettings />;
      case 'vap-dashboard':
        return <VapDashboard />;
      case 'vap-companies':
        return <VapCompanies />;
      case 'vap-reports':
        return <VapReports />;
      case 'vap-settings':
        return <VapSettings />;
      case 'rp-dashboard':
        return <RpDashboard />;
      case 'rp-companies':
        return <RpCompanies />;
      case 'rp-reports':
        return <RpReports />;
      case 'rp-settings':
        return <RpSettings />;
      case 'inbox':
        return <Inbox />;
      case 'my-info':
        return <MyInfo />;
      case 'directory':
        return <Directory />;
      case 'team-devices':
        return <TeamDevices />;
      case 'employee-info':
        return <EmployeeInfo />;
      case 'org-chart':
        return <OrganizationalChart />;

      case 'reports':
        return <CompanyReports />;
      case 'whos-working':
        return <WhosWorking />;
      case 'team-schedule':
        return <TeamSchedule />;
      case 'team-attendance':
        return <TeamAttendance />;
      case 'attendance-flags':
        return <AttendanceFlags />;
      case 'employee-timesheet':
        return <EmployeeTimesheet />;
      case 'team-leave-calendar':
        return <TeamLeaveCalendar />;
      case 'team-leave-requests':
        return <TeamLeaveRequests />;
      case 'team-balances':
        return <TeamBalances />;
      case 'team-goals':
        return <TeamGoalsAndPerformance />;
      case 'team-reviews':
        return <TeamReviews />;
      case 'team-feedback-and-recognition':
        return <TeamFeedbackAndRecognition />;
      case 'team-one-on-one':
        return <TeamOneOnOne />;
      case 'about-company':
        return <AboutTheCompany />;
      case 'team-responsibilities':
        return <TeamResponsibilities />;
      case 'team-knowledge-compliance':
        return <TeamKnowledgeCompliance />;
      case 'team-benefits':
        return <TeamBenefits />;
      case 'team-requests':
        return <TeamRequests />;
      case 'team-expenses':
        return <TeamExpenses />;
      case 'team-licenses':
        return <TeamLicenses />;
      case 'team-it-requests':
        return <TeamITRequests />;
      case 'payroll-wizards':
        return <PayrollWizards />;
      case 'company-reports':
        return <CompanyReports />;
      case 'company-settings':
        return <CompanySettings />;
      case 'job-openings':
        return <JobOpenings />;
      case 'candidates':
        return <Candidates />;
      case 'onboarding':
        return <Onboarding />;
      case 'my-clock':
        return <MyClock />;
      case 'my-planner':
        return <MyPlanner />;
      case 'my-attendance':
        return <MyAttendance />;
      case 'my-requests':
        return <MyRequests />;
      case 'my-balance':
        return <MyBalance />;
      case 'my-responsibility':
        return <MyResponsibility />;
      case 'processes-policies':
        return <ProcessesAndPolicies />;
      case 'documents-files':
        return <DocumentsAndFiles />;
      case 'courses-training':
        return <CoursesAndTraining />;
      case 'my-performance':
        return <MyPerformance />;
      case 'my-feedback-recognition':
        return <MyFeedbackAndRecognition />;
      case 'my-one-on-one':
        return <MyOneOnOne />;
      case 'my-benefits':
        return <MyBenefits />;
      case 'my-expenses':
        return <MyExpenses />;
      case 'my-devices':
        return <MyDevices />;
      case 'my-licenses':
        return <MyLicenses />;
      case 'my-it-requests':
        return <MyITRequests />;
      case 'financial-wellness':
        return <FinancialWellness />;
      case 'mental-health':
        return <MentalHealth />;
      case 'fitness':
        return <Fitness />;
      case 'nutrition':
        return <Nutrition />;
      default:
        return <EmployeeDashboard />;
    }
  };

  // Check if current page is auth or error page
  const isAuthOrErrorPage = [
    'login', 'reset-password', 'new-password',
    'bad-request', 'unauthorized', 'forbidden', 'not-found',
    'internal-server-error', 'bad-gateway', 'service-unavailable', 'gateway-timeout'
  ].includes(currentPage);

  return (
    <ErrorBoundary>
      <div className="min-h-dvh bg-background">
        {!isAuthenticated ? (
          <div className="min-h-dvh flex items-center justify-center p-6">
            <AuthForms />
          </div>
        ) : isAuthOrErrorPage ? (
          // Auth and error pages without layout
          <ErrorBoundary>
            <Suspense fallback={
              <div className="flex items-center justify-center min-h-[400px]">
                <div className="flex flex-col items-center gap-4">
                  <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary"></div>
                  <p className="text-sm text-muted-foreground">Loading...</p>
                </div>
              </div>
            }>
              {renderPage()}
            </Suspense>
          </ErrorBoundary>
        ) : currentPage === 'company-settings' ? (
          <ErrorBoundary>
            <Suspense fallback={
              <div className="flex items-center justify-center min-h-[400px]">
                <div className="flex flex-col items-center gap-4">
                  <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary"></div>
                  <p className="text-sm text-muted-foreground">Loading...</p>
                </div>
              </div>
            }>
              <CompanySettings />
            </Suspense>
          </ErrorBoundary>
        ) : (
          // Regular pages with layout
          <SubmoduleNavProvider>
            <Layout>
              <ErrorBoundary>
                <Suspense fallback={
                  <div className="flex items-center justify-center min-h-[400px]">
                    <div className="flex flex-col items-center gap-4">
                      <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary"></div>
                      <p className="text-sm text-muted-foreground">Loading...</p>
                    </div>
                  </div>
                }>
                  {renderPage()}
                </Suspense>
              </ErrorBoundary>
            </Layout>
          </SubmoduleNavProvider>
        )}
      </div>
    </ErrorBoundary>
  );
}

export default App;

