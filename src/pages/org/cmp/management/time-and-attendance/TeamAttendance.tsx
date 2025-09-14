import { useEffect, useState, useMemo } from 'react';
import { useSubmoduleNav } from '../../../../../hooks/useSubmoduleNav';
import { router } from '../../../../../lib/router';
import { 
  Clock, 
  Calendar, 
  MapPin, 
  Search, 
  Filter, 
  ChevronLeft, 
  ChevronRight,
  CheckCircle,
  XCircle,
  AlertTriangle,
  Clock as ClockIcon,
  MoreVertical,
  Eye,
  SortAsc,
  SortDesc,
  ChevronDown,
  ChevronRight as ChevronRightIcon,
  X,
  CalendarCheck,
  CheckCircle2,
  AlertCircle,
  Calendar as ScheduleIcon,
  Edit3,
  Flag,
  Check,
  Minus,
  MessageSquare
} from 'lucide-react';

// Function to generate avatar initials (100% reliable, works everywhere)
const generateAvatarInitials = (firstName: string, lastName: string) => {
  return `${firstName.charAt(0)}${lastName.charAt(0)}`.toUpperCase();
};

// Function to generate a consistent background color based on name
// Using primary Teal 700 for all avatars for consistency
const generateAvatarColor = (firstName: string, lastName: string) => {
  return '#008383'; // Primary Teal 700
};

interface TimeEntry {
  id: string;
  clockIn: string;
  clockOut: string | null;
  project: string;
  activity: string;
  hours: number;
  notes?: string;
  type: 'work' | 'break' | 'lunch';
}

interface BreakEntry {
  id: string;
  breakStart: string;
  breakEnd: string | null;
  breakType: 'lunch' | 'coffee' | 'personal' | 'meeting' | 'other';
  duration: number; // in minutes
  notes?: string;
}

interface TransferEntry {
  id: string;
  transferStart: string;
  transferEnd: string | null;
  fromLocation: string;
  toLocation: string;
  transferType: 'branch' | 'site' | 'client' | 'other';
  duration: number; // in minutes
  notes?: string;
}

interface AttendanceRecord {
  id: string;
  employeeId: string;
  employeeName: string;
  role: string;
  department: string;
  date: string;
  timeEntries: TimeEntry[];
  breaks: BreakEntry[];
  transfers: TransferEntry[];
  totalHours: number;
  totalBreakTime: number; // in minutes
  totalTransferTime: number; // in minutes
  status: 'present' | 'absent' | 'late' | 'partial' | 'on-break' | 'on-leave' | 'on-transfer';
  location: string;
  notes?: string;
  avatar?: string;
  // Scheduled information
  scheduledClockIn?: string;
  scheduledClockOut?: string;
  scheduledLocation?: string;
  // Modified times (manual edits)
  modifiedClockIn?: string;
  modifiedClockOut?: string;
  // Original times (before modification)
  originalClockIn?: string;
  originalClockOut?: string;
}

// New hierarchical structure for better attendance management
interface Punch {
  id: string;
  timestamp: string;
  type: 'in' | 'out';
  location: string;
  activity?: string;
  notes?: string;
}

interface WorkSession {
  id: string;
  sessionStart: string;
  sessionEnd: string | null;
  location: string;
  punches: Punch[];
  breaks: BreakEntry[];
  transfers: TransferEntry[];
  totalWorkHours: number;
  totalBreakTime: number; // in minutes
  totalTransferTime: number; // in minutes
  isActive: boolean;
  notes?: string;
}

interface NewAttendanceRecord {
  id: string;
  employeeId: string;
  employeeName: string;
  role: string;
  department: string;
  date: string;
  workSessions: WorkSession[];
  totalHours: number;
  totalBreakTime: number; // in minutes
  totalTransferTime: number; // in minutes
  status: 'present' | 'absent' | 'late' | 'partial' | 'on-break' | 'on-leave' | 'on-transfer';
  primaryLocation: string;
  notes?: string;
  avatar?: string;
}

export default function TeamAttendance() {
  const { registerSubmodules } = useSubmoduleNav();
  const [searchTerm, setSearchTerm] = useState('');
  const [selectedDate, setSelectedDate] = useState(new Date().toISOString().split('T')[0]);
  const [showFilters, setShowFilters] = useState(false);
  const [currentPage, setCurrentPage] = useState(1);
  const [itemsPerPage, setItemsPerPage] = useState(10);
  const [sortBy, setSortBy] = useState<'employeeName' | 'department' | 'clockIn' | 'totalHours' | 'status' | 'location'>('employeeName');
  const [sortOrder, setSortOrder] = useState<'asc' | 'desc'>('asc');
  const [selectedDepartment, setSelectedDepartment] = useState<string>('');
  const [selectedStatus, setSelectedStatus] = useState<string>('');
  const [selectedLocation, setSelectedLocation] = useState<string>('');
  const [selectedFlags, setSelectedFlags] = useState<string>('');
  const [selectedRecord, setSelectedRecord] = useState<AttendanceRecord | null>(null);
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [selectedRecords, setSelectedRecords] = useState<Set<string>>(new Set());
  const [selectAll, setSelectAll] = useState(false);
  const [expandedRecords, setExpandedRecords] = useState<Set<string>>(new Set());
  const [activeTab, setActiveTab] = useState<'sessions' | 'comments' | 'log'>('sessions');
  const [activeTooltip, setActiveTooltip] = useState<string | null>(null);
  const [activeFloatingMenu, setActiveFloatingMenu] = useState<string | null>(null);
  const [editingRecord, setEditingRecord] = useState<string | null>(null);
  const [editingSession, setEditingSession] = useState<string | null>(null);
  const [editClockIn, setEditClockIn] = useState('');
  const [editClockOut, setEditClockOut] = useState('');
  const [showOriginalTimes, setShowOriginalTimes] = useState<Set<string>>(new Set());

  useEffect(() => {
    // Register submodule tabs for time and attendance
    registerSubmodules('Time & Attendance', [
      { id: 'team-planner', label: 'Team Planner', href: '/org/cmp/management/time-and-attendance/team-planner', icon: Calendar },
      { id: 'team-attendance', label: 'Team Attendance', href: '/org/cmp/management/time-and-attendance/team-attendance', icon: Clock },
      { id: 'team-geolocation', label: 'Team Geolocation', href: '/org/cmp/management/time-and-attendance/team-geolocation', icon: MapPin }
    ]);
  }, [registerSubmodules]);

  // Close tooltips and floating menus when clicking outside
  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (activeTooltip) {
        setActiveTooltip(null);
      }
      if (activeFloatingMenu) {
        setActiveFloatingMenu(null);
      }
    };

    if (activeTooltip || activeFloatingMenu) {
      document.addEventListener('click', handleClickOutside);
      return () => document.removeEventListener('click', handleClickOutside);
    }
  }, [activeTooltip, activeFloatingMenu]);

  // Example of new hierarchical structure (for future implementation)
  const newAttendanceRecords: NewAttendanceRecord[] = [
    {
      id: 'new-1',
      employeeId: 'EMP001',
      employeeName: 'Sarah Johnson',
      role: 'UI/UX Designer',
      department: 'Design',
      date: selectedDate as string,
      workSessions: [
        {
          id: 'session-1',
          sessionStart: '08:00',
          sessionEnd: '17:00',
          location: 'Main Office',
          punches: [
            { id: 'p1', timestamp: '08:00', type: 'in', location: 'Main Office', activity: 'Start work' },
            { id: 'p2', timestamp: '12:00', type: 'out', location: 'Main Office', activity: 'Lunch break' },
            { id: 'p3', timestamp: '13:00', type: 'in', location: 'Main Office', activity: 'Back from lunch' },
            { id: 'p4', timestamp: '17:00', type: 'out', location: 'Main Office', activity: 'End work' }
          ],
          breaks: [
            { id: 'b1', breakStart: '12:00', breakEnd: '13:00', breakType: 'lunch', duration: 60, notes: 'Lunch break' }
          ],
          transfers: [],
          totalWorkHours: 8.0,
          totalBreakTime: 60,
          totalTransferTime: 0,
          isActive: false,
          notes: 'Regular work session'
        }
      ],
      totalHours: 8.0,
      totalBreakTime: 60,
      totalTransferTime: 0,
      status: 'present',
      primaryLocation: 'Main Office',
      notes: 'Single session day'
    },
    {
      id: 'new-2',
      employeeId: 'EMP002',
      employeeName: 'Alex Rodriguez',
      role: 'Project Manager',
      department: 'Management',
      date: selectedDate as string,
      workSessions: [
        {
          id: 'session-1',
          sessionStart: '09:30',
          sessionEnd: '12:00',
          location: 'Main Office',
          punches: [
            { id: 'p1', timestamp: '09:30', type: 'in', location: 'Main Office', activity: 'Team meeting' },
            { id: 'p2', timestamp: '12:00', type: 'out', location: 'Main Office', activity: 'Transfer to client' }
          ],
          breaks: [],
          transfers: [
            { id: 't1', transferStart: '12:00', transferEnd: '12:20', fromLocation: 'Main Office', toLocation: 'Client Site A', transferType: 'client', duration: 20, notes: 'Travel to client' }
          ],
          totalWorkHours: 2.5,
          totalBreakTime: 0,
          totalTransferTime: 20,
          isActive: false,
          notes: 'Morning session at office'
        },
        {
          id: 'session-2',
          sessionStart: '12:20',
          sessionEnd: '15:00',
          location: 'Client Site A',
          punches: [
            { id: 'p3', timestamp: '12:20', type: 'in', location: 'Client Site A', activity: 'Client meeting' },
            { id: 'p4', timestamp: '15:00', type: 'out', location: 'Client Site A', activity: 'Transfer back' }
          ],
          breaks: [],
          transfers: [
            { id: 't2', transferStart: '15:00', transferEnd: '15:30', fromLocation: 'Client Site A', toLocation: 'Branch Office B', transferType: 'branch', duration: 30, notes: 'Travel to branch' }
          ],
          totalWorkHours: 2.67,
          totalBreakTime: 0,
          totalTransferTime: 30,
          isActive: false,
          notes: 'Client site session'
        },
        {
          id: 'session-3',
          sessionStart: '15:30',
          sessionEnd: '18:00',
          location: 'Branch Office B',
          punches: [
            { id: 'p5', timestamp: '15:30', type: 'in', location: 'Branch Office B', activity: 'Documentation' },
            { id: 'p6', timestamp: '18:00', type: 'out', location: 'Branch Office B', activity: 'End work' }
          ],
          breaks: [],
          transfers: [],
          totalWorkHours: 2.5,
          totalBreakTime: 0,
          totalTransferTime: 0,
          isActive: false,
          notes: 'Branch office session'
        }
      ],
      totalHours: 7.67,
      totalBreakTime: 0,
      totalTransferTime: 50,
      status: 'present',
      primaryLocation: 'Main Office',
      notes: 'Multiple locations - client and branch visits'
    }
  ];

  // Mock attendance data with various states for testing (current structure)
  const attendanceRecords: AttendanceRecord[] = [
    {
      id: '1',
      employeeId: '1',
      employeeName: 'Sarah Johnson',
      role: 'Senior Developer',
      department: 'Engineering',
      date: selectedDate as string,
      timeEntries: [
        {
          id: '1-1',
          clockIn: '09:15',
          clockOut: '12:00',
          project: 'Project Alpha',
          activity: 'Frontend Development',
          hours: 2.75,
          notes: 'Working on user interface',
          type: 'work' as const
        },
        {
          id: '1-2',
          clockIn: '13:00',
          clockOut: '17:30',
          project: 'Project Beta',
          activity: 'Code Review',
          hours: 4.5,
          notes: 'Reviewing team code',
          type: 'work' as const
        }
      ],
      breaks: [
        {
          id: '1-b1',
          breakStart: '12:00',
          breakEnd: '13:00',
          breakType: 'lunch',
          duration: 60,
          notes: 'Lunch break'
        },
        {
          id: '1-b2',
          breakStart: '15:30',
          breakEnd: '15:45',
          breakType: 'coffee',
          duration: 15,
          notes: 'Coffee break'
        }
      ],
      transfers: [
        {
          id: '1-t1',
          transferStart: '10:30',
          transferEnd: '10:45',
          fromLocation: 'Main Office',
          toLocation: 'Client Site A',
          transferType: 'client',
          duration: 15,
          notes: 'Travel to client site for meeting'
        }
      ],
      totalHours: 7.25,
      totalBreakTime: 75,
      totalTransferTime: 15,
      status: 'present',
      location: 'Office',
      notes: 'Regular day',
      // Scheduled information
      scheduledClockIn: '09:00',
      scheduledClockOut: '17:00',
      scheduledLocation: 'Main Office'
    },
    {
      id: '2',
      employeeId: '2',
      employeeName: 'Mike Chen',
      role: 'UX Designer',
      department: 'Design',
      date: selectedDate as string,
      timeEntries: [
        {
          id: '2-1',
          clockIn: '08:45',
          clockOut: '12:30',
          project: 'Project Alpha',
          activity: 'UI Design',
          hours: 3.75,
          notes: 'Creating wireframes',
          type: 'work' as const
        },
        {
          id: '2-2',
          clockIn: '13:30',
          clockOut: '17:15',
          project: 'Project Gamma',
          activity: 'User Research',
          hours: 3.75,
          notes: 'Conducting user interviews',
          type: 'work' as const
        }
      ],
      breaks: [
        {
          id: '2-b1',
          breakStart: '12:30',
          breakEnd: '13:30',
          breakType: 'lunch',
          duration: 60,
          notes: 'Lunch break'
        }
      ],
      transfers: [],
      totalHours: 7.5,
      totalBreakTime: 60,
      totalTransferTime: 0,
      status: 'present',
      location: 'Office',
      // Scheduled information - late start
      scheduledClockIn: '08:30',
      scheduledClockOut: '17:00',
      scheduledLocation: 'Office'
    },
    {
      id: '3',
      employeeId: '3',
      employeeName: 'Alex Rodriguez',
      role: 'Project Manager',
      department: 'Management',
      date: selectedDate as string,
      timeEntries: [
        {
          id: '3-1',
          clockIn: '09:30',
          clockOut: '12:00',
          project: 'Main Office',
          activity: 'Team Meeting',
          hours: 2.5,
          notes: 'Sprint planning',
          type: 'work' as const
        },
        {
          id: '3-2',
          clockIn: '13:00',
          clockOut: '15:00',
          project: 'Client Site A',
          activity: 'Client Call',
          hours: 2,
          notes: 'Project status update',
          type: 'work' as const
        },
        {
          id: '3-3',
          clockIn: '15:30',
          clockOut: '18:00',
          project: 'Branch Office B',
          activity: 'Documentation',
          hours: 2.5,
          notes: 'Creating project reports',
          type: 'work' as const
        }
      ],
      breaks: [
        {
          id: '3-b1',
          breakStart: '12:00',
          breakEnd: '13:00',
          breakType: 'lunch',
          duration: 60,
          notes: 'Lunch break'
        },
        {
          id: '3-b2',
          breakStart: '15:00',
          breakEnd: '15:30',
          breakType: 'personal',
          duration: 30,
          notes: 'Personal break'
        }
      ],
      transfers: [
        {
          id: '3-t1',
          transferStart: '12:00',
          transferEnd: '12:20',
          fromLocation: 'Main Office',
          toLocation: 'Client Site A',
          transferType: 'client',
          duration: 20,
          notes: 'Transfer to client site'
        },
        {
          id: '3-t2',
          transferStart: '15:00',
          transferEnd: '15:30',
          fromLocation: 'Client Site A',
          toLocation: 'Branch Office B',
          transferType: 'branch',
          duration: 30,
          notes: 'Transfer to branch office'
        }
      ],
      totalHours: 7,
      totalBreakTime: 90,
      totalTransferTime: 50,
      status: 'late',
      location: 'Main Office',
      notes: 'Traffic delay'
    },
    {
      id: '4',
      employeeId: '4',
      employeeName: 'Emma Wilson',
      role: 'Marketing Specialist',
      department: 'Marketing',
      date: selectedDate as string,
      timeEntries: [],
      breaks: [],
      transfers: [],
      totalHours: 0,
      totalBreakTime: 0,
      totalTransferTime: 0,
      status: 'absent',
      location: 'Remote',
      notes: 'Sick leave'
    },
    {
      id: '5',
      employeeId: '5',
      employeeName: 'David Kim',
      role: 'DevOps Engineer',
      department: 'Engineering',
      date: selectedDate as string,
      timeEntries: [
        {
          id: '5-1',
          clockIn: '10:00',
          clockOut: '12:00',
          project: 'Project Alpha',
          activity: 'Deployment',
          hours: 2,
          notes: 'Production deployment',
          type: 'work' as const
        },
        {
          id: '5-2',
          clockIn: '14:00',
          clockOut: '16:00',
          project: 'Project Beta',
          activity: 'Infrastructure',
          hours: 2,
          notes: 'Server maintenance',
          type: 'work' as const
        }
      ],
      breaks: [
        {
          id: '5-b1',
          breakStart: '12:00',
          breakEnd: '14:00',
          breakType: 'personal',
          duration: 120,
          notes: 'Doctor appointment'
        }
      ],
      transfers: [],
      totalHours: 4,
      totalBreakTime: 120,
      totalTransferTime: 0,
      status: 'partial',
      location: 'Office',
      notes: 'Doctor appointment'
    },
    {
      id: '8',
      employeeId: '8',
      employeeName: 'Jennifer Lee',
      role: 'Product Manager',
      department: 'Product',
      date: selectedDate as string,
      timeEntries: [
        {
          id: '8-1',
          clockIn: '09:00',
          clockOut: '12:00',
          project: 'Project Alpha',
          activity: 'Product Planning',
          hours: 3,
          notes: 'Feature roadmap',
          type: 'work' as const
        }
      ],
      breaks: [
        {
          id: '8-b1',
          breakStart: '12:00',
          breakEnd: null, // Currently on break
          breakType: 'lunch',
          duration: 0, // Will be calculated when break ends
          notes: 'Lunch break - currently active'
        }
      ],
      transfers: [],
      totalHours: 3,
      totalBreakTime: 0,
      totalTransferTime: 0,
      status: 'on-break',
      location: 'Office',
      notes: 'Currently on lunch break'
    },
    {
      id: '6',
      employeeId: '6',
      employeeName: 'Lisa Thompson',
      role: 'HR Manager',
      department: 'Human Resources',
      date: selectedDate as string,
      timeEntries: [],
      breaks: [],
      transfers: [],
      totalHours: 0,
      totalBreakTime: 0,
      totalTransferTime: 0,
      status: 'on-leave',
      location: 'Remote',
      notes: 'Vacation'
    },
    {
      id: '19',
      employeeId: '19',
      employeeName: 'Robert Garcia',
      role: 'Sales Director',
      department: 'Sales',
      date: selectedDate as string,
      timeEntries: [],
      breaks: [],
      transfers: [],
      totalHours: 0,
      totalBreakTime: 0,
      totalTransferTime: 0,
      status: 'on-leave',
      location: 'Remote',
      notes: 'Personal leave'
    },
    // EMPLOYEE CURRENTLY PRESENT (no clock out)
    {
      id: '17',
      employeeId: '17',
      employeeName: 'Maria Garcia',
      role: 'Product Manager',
      department: 'Product',
      date: selectedDate as string,
      timeEntries: [
        {
          id: '5-1',
          clockIn: '08:30',
          clockOut: '', // Still working
          project: 'Product Strategy',
          activity: 'Planning',
          hours: 0,
          notes: 'Working on Q2 roadmap',
          type: 'work' as const
        }
      ],
      breaks: [
        {
          id: '5-b1',
          breakStart: '10:30',
          breakEnd: '10:45',
          duration: 15,
          breakType: 'coffee',
          notes: 'Coffee break'
        }
      ],
      transfers: [],
      totalHours: 0, // Will be calculated at end of day
      totalBreakTime: 15,
      totalTransferTime: 0,
      status: 'present',
      location: 'Main Office',
      notes: 'Currently working'
    },
    // EMPLOYEE ON BREAK (no break end time)
    {
      id: '18',
      employeeId: '18',
      employeeName: 'James Wilson',
      role: 'UX Designer',
      department: 'Design',
      date: selectedDate as string,
      timeEntries: [
        {
          id: '6-1',
          clockIn: '09:00',
          clockOut: '',
          project: 'Mobile App',
          activity: 'Design',
          hours: 0,
          notes: 'Working on new UI components',
          type: 'work' as const
        }
      ],
      breaks: [
        {
          id: '6-b1',
          breakStart: '10:00',
          breakEnd: '10:15',
          duration: 15,
          breakType: 'coffee'
        },
        {
          id: '6-b2',
          breakStart: '12:00',
          breakEnd: '', // Currently on lunch break
          duration: 0,
          breakType: 'lunch',
          notes: 'Lunch break'
        }
      ],
      transfers: [],
      totalHours: 0,
      totalBreakTime: 15,
      totalTransferTime: 0,
      status: 'on-break',
      location: 'Main Office',
      notes: 'Currently on lunch break'
    },
    // EMPLOYEE IN TRANSFER (no transfer end time)
    {
      id: '7',
      employeeId: '7',
      employeeName: 'Lisa Chen',
      role: 'Account Manager',
      department: 'Sales',
      date: selectedDate as string,
      timeEntries: [
        {
          id: '7-1',
          clockIn: '08:00',
          clockOut: '',
          project: 'Client Visit',
          activity: 'Meeting',
          hours: 0,
          notes: 'Client presentation',
          type: 'work' as const
        }
      ],
      breaks: [],
      transfers: [
        {
          id: '7-t1',
          transferStart: '10:30',
          transferEnd: '', // Currently in transfer
          fromLocation: 'Main Office',
          toLocation: 'Client Site',
          duration: 0,
          transferType: 'client',
          notes: 'Going to client presentation'
        }
      ],
      totalHours: 0,
      totalBreakTime: 0,
      totalTransferTime: 0,
      status: 'on-transfer',
      location: 'Main Office',
      notes: 'Currently traveling to client',
      // Scheduled information - supposed to be at client site
      scheduledClockIn: '08:00',
      scheduledClockOut: '16:00',
      scheduledLocation: 'Client Site',
      // Modified times for demo
      modifiedClockIn: '08:15',
      // Original times (what was actually clocked before modification)
      originalClockIn: '08:45'
    },
    // More employees to test pagination
    {
      id: '9',
      employeeId: '9',
      employeeName: 'David Brown',
      role: 'Software Engineer',
      department: 'Engineering',
      date: selectedDate as string,
      timeEntries: [
        {
          id: '8-1',
          clockIn: '09:00',
          clockOut: '17:30',
          project: 'Backend API',
          activity: 'Development',
          hours: 8.5,
          type: 'work' as const
        }
      ],
      breaks: [
        {
          id: '8-b1',
          breakStart: '12:00',
          breakEnd: '13:00',
          duration: 60,
          breakType: 'lunch'
        }
      ],
      transfers: [],
      totalHours: 8.5,
      totalBreakTime: 60,
      totalTransferTime: 0,
      status: 'present',
      location: 'Remote',
      notes: 'Completed development tasks',
      // Modified times for demo
      modifiedClockOut: '18:00',
      // Original times (what was actually clocked before modification)
      originalClockOut: '17:15'
    },
    {
      id: '20',
      employeeId: '20',
      employeeName: 'Amanda Taylor',
      role: 'Marketing Specialist',
      department: 'Marketing',
      date: selectedDate as string,
      timeEntries: [
        {
          id: '9-1',
          clockIn: '08:15',
          clockOut: '16:45',
          project: 'Campaign Launch',
          activity: 'Marketing',
          hours: 8.5,
          type: 'work' as const
        }
      ],
      breaks: [
        {
          id: '9-b1',
          breakStart: '10:30',
          breakEnd: '10:45',
          duration: 15,
          breakType: 'coffee'
        },
        {
          id: '9-b2',
          breakStart: '12:30',
          breakEnd: '13:30',
          duration: 60,
          breakType: 'lunch'
        }
      ],
      transfers: [],
      totalHours: 8.5,
      totalBreakTime: 75,
      totalTransferTime: 0,
      status: 'present',
      location: 'Main Office',
      notes: 'Campaign launch successful'
    },
    {
      id: '10',
      employeeId: '10',
      employeeName: 'Robert Miller',
      role: 'Data Analyst',
      department: 'Analytics',
      date: selectedDate as string,
      timeEntries: [],
      breaks: [],
      transfers: [],
      totalHours: 0,
      totalBreakTime: 0,
      totalTransferTime: 0,
      status: 'on-leave',
      location: 'Remote',
      notes: 'Sick leave'
    },
    {
      id: '11',
      employeeId: '11',
      employeeName: 'Jennifer Davis',
      role: 'HR Manager',
      department: 'Human Resources',
      date: selectedDate as string,
      timeEntries: [
        {
          id: '11-1',
          clockIn: '08:45',
          clockOut: '',
          project: 'Recruitment',
          activity: 'Interviews',
          hours: 0,
          type: 'work' as const
        }
      ],
      breaks: [
        {
          id: '11-b1',
          breakStart: '14:00',
          breakEnd: '', // Currently on break
          duration: 0,
          breakType: 'coffee',
          notes: 'Afternoon break'
        }
      ],
      transfers: [],
      totalHours: 0,
      totalBreakTime: 0,
      totalTransferTime: 0,
      status: 'on-break',
      location: 'Main Office',
      notes: 'Conducting interviews today'
    },
    {
      id: '12',
      employeeId: '12',
      employeeName: 'Kevin Anderson',
      role: 'DevOps Engineer',
      department: 'Engineering',
      date: selectedDate as string,
      timeEntries: [
        {
          id: '12-1',
          clockIn: '07:30',
          clockOut: '16:00',
          project: 'Infrastructure',
          activity: 'Maintenance',
          hours: 8.5,
          type: 'work' as const
        }
      ],
      breaks: [
        {
          id: '12-b1',
          breakStart: '11:00',
          breakEnd: '11:15',
          duration: 15,
          breakType: 'coffee'
        },
        {
          id: '12-b2',
          breakStart: '12:30',
          breakEnd: '13:30',
          duration: 60,
          breakType: 'lunch'
        }
      ],
      transfers: [
        {
          id: '12-t1',
          transferStart: '14:00',
          transferEnd: '14:20',
          fromLocation: 'Main Office',
          toLocation: 'Data Center',
          duration: 20,
          transferType: 'site',
          notes: 'Server maintenance'
        }
      ],
      totalHours: 8.5,
      totalBreakTime: 75,
      totalTransferTime: 20,
      status: 'present',
      location: 'Main Office',
      notes: 'Server maintenance completed'
    },
    {
      id: '13',
      employeeId: '13',
      employeeName: 'Michelle White',
      role: 'Quality Assurance',
      department: 'Engineering',
      date: selectedDate as string,
      timeEntries: [
        {
          id: '13-1',
          clockIn: '09:30',
          clockOut: '',
          project: 'Testing Suite',
          activity: 'Testing',
          hours: 0,
          type: 'work' as const
        }
      ],
      breaks: [],
      transfers: [
        {
          id: '13-t1',
          transferStart: '11:00',
          transferEnd: '11:30',
          fromLocation: 'Main Office',
          toLocation: 'Testing Lab',
          duration: 30,
          transferType: 'branch',
          notes: 'Moving to testing environment'
        },
        {
          id: '13-t2',
          transferStart: '15:00',
          transferEnd: '', // Currently in transfer
          fromLocation: 'Testing Lab',
          toLocation: 'Main Office',
          duration: 0,
          transferType: 'branch',
          notes: 'Returning to main office'
        }
      ],
      totalHours: 0,
      totalBreakTime: 0,
      totalTransferTime: 30,
      status: 'on-transfer',
      location: 'Testing Lab',
      notes: 'Testing new features'
    },
    {
      id: '14',
      employeeId: '14',
      employeeName: 'Christopher Lee',
      role: 'Sales Representative',
      department: 'Sales',
      date: selectedDate as string,
      timeEntries: [
        {
          id: '14-1',
          clockIn: '08:00',
          clockOut: '17:00',
          project: 'Client Outreach',
          activity: 'Sales',
          hours: 9,
          type: 'work' as const
        }
      ],
      breaks: [
        {
          id: '14-b1',
          breakStart: '10:15',
          breakEnd: '10:30',
          duration: 15,
          breakType: 'coffee'
        },
        {
          id: '14-b2',
          breakStart: '12:00',
          breakEnd: '13:00',
          duration: 60,
          breakType: 'lunch'
        },
        {
          id: '14-b3',
          breakStart: '15:30',
          breakEnd: '15:45',
          duration: 15,
          breakType: 'coffee'
        }
      ],
      transfers: [],
      totalHours: 9,
      totalBreakTime: 90,
      totalTransferTime: 0,
      status: 'present',
      location: 'Remote',
      notes: 'Excellent sales performance today'
    },
    {
      id: '15',
      employeeId: '15',
      employeeName: 'Sandra Martinez',
      role: 'Finance Manager',
      department: 'Finance',
      date: selectedDate as string,
      timeEntries: [],
      breaks: [],
      transfers: [],
      totalHours: 0,
      totalBreakTime: 0,
      totalTransferTime: 0,
      status: 'on-leave',
      location: 'Remote',
      notes: 'Vacation day'
    },
    // EMPLOYEE ABSENT (scheduled but didn't clock in)
    {
      id: '16',
      employeeId: '16',
      employeeName: 'Carlos Rodriguez',
      role: 'Marketing Coordinator',
      department: 'Marketing',
      date: selectedDate as string,
      timeEntries: [], // No clock in entries
      breaks: [],
      transfers: [],
      totalHours: 0,
      totalBreakTime: 0,
      totalTransferTime: 0,
      status: 'present', // Will be overridden by getCurrentStatus
      location: 'Main Office',
      notes: 'Scheduled to work but no show',
      // Scheduled information - expected to work
      scheduledClockIn: '09:00',
      scheduledClockOut: '17:00',
      scheduledLocation: 'Main Office',
      // Modified times for demo
      modifiedClockIn: '09:15',
      modifiedClockOut: '17:30',
      // Original times (what was actually clocked before modification)
      originalClockIn: '09:45',
      originalClockOut: '16:45'
    }
  ];

  // Helper functions for approval status (moved before useMemo to avoid initialization errors)
  const getOvertimeHours = (totalHours: number) => {
    const standardHours = 8;
    const overtime = Math.max(0, totalHours - standardHours);
    return overtime;
  };

  const getWorkSessionsCount = (record: AttendanceRecord) => {
    // For now, we'll estimate sessions based on transfers + 1
    // A transfer creates a new session, so sessions = transfers + 1
    const baseSessions = 1; // At least one session
    const additionalSessions = record.transfers.length; // Each transfer creates a new session
    return baseSessions + additionalSessions;
  };

  // Helper function to get approval status for a single work session
  const getSessionApprovalStatus = (sessionId: string, record: AttendanceRecord): 'approved_without_modifications' | 'approved_with_modifications' | 'pending_without_incidents' | 'pending_with_incidents' | 'rejected' => {
    // For demo purposes, create different approval statuses for different sessions
    // In real implementation, this would come from the backend
    const sessionNumber = parseInt(sessionId.split('-').pop() || '1');
    
    // Check if record has incidents (overtime, late arrival, early departure, etc.)
    const hasIncidents = (record: AttendanceRecord) => {
      const overtimeHours = getOvertimeHours(record.totalHours);
      const hasOvertime = overtimeHours > 0;
      const isLate = record.scheduledClockIn && record.timeEntries[0]?.clockIn && record.timeEntries[0].clockIn > record.scheduledClockIn;
      const isEarly = record.scheduledClockOut && record.timeEntries[0]?.clockOut && record.timeEntries[0].clockOut < record.scheduledClockOut;
      const wrongLocation = record.scheduledLocation && record.location !== record.scheduledLocation;
      
      return hasOvertime || isLate || isEarly || wrongLocation;
    };
    
    // Check if record has been modified (simulated for demo)
    const isModified = (record: AttendanceRecord, sessionId: string) => {
      // In real implementation, this would check if original hours were edited
      return record.employeeName === 'Lisa Chen' || (record.employeeName === 'Jane Smith' && sessionNumber === 2);
    };
    
    if (record.employeeName === 'John Doe') {
      // John Doe: Session 1 approved without modifications, Session 2 pending without incidents
      return sessionNumber === 1 ? 'approved_without_modifications' : 'pending_without_incidents';
    } else if (record.employeeName === 'Jane Smith') {
      // Jane Smith: Session 1 pending with incidents (overtime), Session 2 approved with modifications
      return sessionNumber === 1 ? 'pending_with_incidents' : 'approved_with_modifications';
    } else if (record.employeeName === 'Mike Johnson') {
      // Mike Johnson: All sessions rejected
      return 'rejected';
    } else if (record.employeeName === 'Lisa Chen') {
      // Lisa Chen: Session 1 approved with modifications, Session 2 pending with incidents
      return sessionNumber === 1 ? 'approved_with_modifications' : 'pending_with_incidents';
    } else if (record.employeeName === 'Emma Wilson') {
      // Emma Wilson: Pending without incidents (normal attendance, no issues)
      return 'pending_without_incidents';
    }
    
    // Default for other employees - check if they have incidents
    const incidents = hasIncidents(record);
    const modified = isModified(record, sessionId);
    
    if (incidents) {
      return 'pending_with_incidents';
    } else if (modified) {
      return 'approved_with_modifications';
    } else {
      return 'approved_without_modifications';
    }
  };

  // Helper function to get flags for incidents
  const getRecordFlags = (record: AttendanceRecord): { type: 'incident' | 'resolved' | 'rejected' | 'acknowledged', message: string }[] => {
    const flags: { type: 'incident' | 'resolved' | 'rejected' | 'acknowledged', message: string }[] = [];
    
    // Check for overtime
    const overtimeHours = getOvertimeHours(record.totalHours);
    if (overtimeHours > 0) {
      flags.push({ type: 'incident', message: `Overtime: ${overtimeHours.toFixed(2)} hours` });
    }
    
    // Check for late arrival
    if (record.scheduledClockIn && record.timeEntries[0]?.clockIn && record.timeEntries[0].clockIn > record.scheduledClockIn) {
      flags.push({ type: 'incident', message: 'Late arrival' });
    }
    
    // Check for early departure
    if (record.scheduledClockOut && record.timeEntries[0]?.clockOut && record.timeEntries[0].clockOut < record.scheduledClockOut) {
      flags.push({ type: 'incident', message: 'Early departure' });
    }
    
    // Check for wrong location
    if (record.scheduledLocation && record.location !== record.scheduledLocation) {
      flags.push({ type: 'incident', message: 'Wrong location' });
    }
    
    // Check for missing clock out (if clock in exists but no clock out)
    if (record.timeEntries[0]?.clockIn && !record.timeEntries[0]?.clockOut) {
      flags.push({ type: 'incident', message: 'Missing clock out' });
    }
    
    // Check for missing clock in (if scheduled but no clock in)
    if (record.scheduledClockIn && !record.timeEntries[0]?.clockIn) {
      flags.push({ type: 'incident', message: 'Missing clock in' });
    }
    
    // Add some resolved, rejected, and acknowledged flags for demo (in real app, this would come from backend)
    // Only add these if no incidents were detected (resolved/rejected/acknowledged replace incidents)
    if (record.employeeName === 'Emma Wilson' && flags.length === 0) {
      flags.push({ type: 'resolved', message: 'Late arrival - Approved' });
    }
    if (record.employeeName === 'Mike Chen' && flags.length === 0) {
      flags.push({ type: 'resolved', message: 'Overtime - Approved' });
    }
    if (record.employeeName === 'Robert Garcia' && flags.length === 0) {
      flags.push({ type: 'rejected', message: 'Overtime - Rejected' });
    }
    if (record.employeeName === 'Jennifer Davis' && flags.length === 0) {
      flags.push({ type: 'rejected', message: 'Late arrival - Rejected' });
    }
    if (record.employeeName === 'David Kim' && flags.length === 0) {
      flags.push({ type: 'acknowledged', message: 'Late arrival - Acknowledged' });
    }
    if (record.employeeName === 'Lisa Thompson' && flags.length === 0) {
      flags.push({ type: 'acknowledged', message: 'Early departure - Acknowledged' });
    }
    
    return flags;
  };

  // Helper function to check if record has any flags
  const hasFlags = (record: AttendanceRecord): boolean => {
    return getRecordFlags(record).length > 0;
  };

  // Helper function to check if record was manually modified
  const isRecordModified = (record: AttendanceRecord): boolean => {
    // Check if times were manually edited
    const hasModifiedTimes = Boolean(record.modifiedClockIn || record.modifiedClockOut);
    
    // For demo purposes, also mark some records as manually entered
    const manuallyEnteredEmployees = ['Lisa Chen', 'David Brown', 'Amanda Taylor'];
    const isManuallyEntered = manuallyEnteredEmployees.includes(record.employeeName);
    
    return hasModifiedTimes || isManuallyEntered;
  };

  // Helper function to render modified icon with tooltip
  const renderModifiedIcon = (record: AttendanceRecord, tooltipId: string) => {
    if (!isRecordModified(record)) {
      return null;
    }

    const tooltipKey = `modified-${tooltipId}-${record.employeeName.replace(/\s+/g, '-')}`;

    return (
      <div className="relative">
        <div 
          className="w-4 h-4 rounded-full bg-status-blue flex items-center justify-center cursor-pointer select-none"
          title="Hold to see original times"
          onMouseDown={(e) => {
            e.stopPropagation();
            setShowOriginalTimes(prev => new Set([...prev, record.id]));
          }}
          onMouseUp={(e) => {
            e.stopPropagation();
            setShowOriginalTimes(prev => {
              const newSet = new Set(prev);
              newSet.delete(record.id);
              return newSet;
            });
          }}
          onMouseLeave={(e) => {
            e.stopPropagation();
            // Also hide original times if mouse leaves while pressed
            setShowOriginalTimes(prev => {
              const newSet = new Set(prev);
              newSet.delete(record.id);
              return newSet;
            });
          }}
        >
          <span className="text-[10px] font-medium text-white">M</span>
        </div>
      </div>
    );
  };

  // Helper function to render flag icon with tooltip
  const renderFlagIcon = (record: AttendanceRecord, tooltipId: string) => {
    const flags = getRecordFlags(record);
    
    if (flags.length === 0) {
      return null; // No flag if no incidents
    }

    const hasIncidents = flags.some(flag => flag.type === 'incident');
    const hasResolved = flags.some(flag => flag.type === 'resolved');
    const hasRejected = flags.some(flag => flag.type === 'rejected');
    const hasAcknowledged = flags.some(flag => flag.type === 'acknowledged');
    
    const tooltipKey = `flag-${tooltipId}-${record.employeeName.replace(/\s+/g, '-')}`;
    
    // Priority: incidents (red) > rejected (gray) > acknowledged (blue) > resolved (green)
    let flagColor, bgColor, borderColor;
    if (hasIncidents) {
      flagColor = 'text-status-red hover:text-red-700';
      bgColor = 'bg-status-red';
      borderColor = 'border-t-status-red';
    } else if (hasRejected) {
      flagColor = 'text-status-gray hover:text-gray-600';
      bgColor = 'bg-status-gray';
      borderColor = 'border-t-gray-500';
    } else if (hasAcknowledged) {
      flagColor = 'text-status-blue hover:text-blue-700';
      bgColor = 'bg-status-blue';
      borderColor = 'border-t-status-blue';
    } else {
      flagColor = 'text-status-green hover:text-green-800';
      bgColor = 'bg-status-green';
      borderColor = 'border-t-status-green';
    }
    
    return (
      <div className="flex items-center cursor-pointer"
        onClick={(e) => {
          e.stopPropagation();
          setActiveTooltip(activeTooltip === tooltipKey ? null : tooltipKey);
        }}
      >
        <div className="relative">
          <Flag 
            className={`w-4 h-4 transition-colors ${flagColor}`}
          />
          {activeTooltip === tooltipKey && (
            <div className={`absolute bottom-full left-1/2 transform -translate-x-1/2 mb-2 px-2 py-1 text-white text-xs rounded whitespace-nowrap z-50 ${bgColor}`}>
              <div className="space-y-1">
                {flags.map((flag, index) => (
                  <div key={index}>{flag.message}</div>
                ))}
              </div>
              <div className={`absolute top-full left-1/2 transform -translate-x-1/2 w-0 h-0 border-l-4 border-r-4 border-t-4 border-transparent ${
                hasIncidents ? 'border-t-[#b91c1c]' : hasRejected ? 'border-t-[#6b7280]' : hasAcknowledged ? 'border-t-[#2563eb]' : 'border-t-[#15803d]'
              }`}></div>
            </div>
          )}
        </div>
                 {hasResolved && (
                   <Check
                     className="w-3 h-3 text-status-green ml-1"
                   />
                 )}
                 {hasRejected && !hasIncidents && !hasResolved && !hasAcknowledged && (
                   <X
                     className="w-3 h-3 text-status-gray ml-1"
                   />
                 )}
                 {hasAcknowledged && !hasIncidents && !hasResolved && !hasRejected && (
                   <Minus
                     className="w-3 h-3 text-status-blue ml-1"
                   />
                 )}
      </div>
    );
  };

  const filteredRecords = useMemo(() => {
    let filtered = attendanceRecords.filter(record => {
      const matchesSearch = 
        record.employeeName.toLowerCase().includes(searchTerm.toLowerCase()) ||
        record.role.toLowerCase().includes(searchTerm.toLowerCase()) ||
        record.department.toLowerCase().includes(searchTerm.toLowerCase());
      
      const matchesDepartment = !selectedDepartment || record.department === selectedDepartment;
      const matchesStatus = !selectedStatus || record.status === selectedStatus;
      const matchesLocation = !selectedLocation || record.location === selectedLocation;
      const matchesFlags = !selectedFlags || (selectedFlags === 'flagged' ? hasFlags(record) : !hasFlags(record));
      
      return matchesSearch && matchesDepartment && matchesStatus && matchesLocation && matchesFlags;
    });

    // Sort records
    filtered.sort((a, b) => {
      const aValue = a[sortBy as keyof AttendanceRecord];
      const bValue = b[sortBy as keyof AttendanceRecord];
      
      if (sortOrder === 'asc') {
        return (aValue || '') > (bValue || '') ? 1 : -1;
      } else {
        return (aValue || '') < (bValue || '') ? 1 : -1;
      }
    });

    return filtered;
  }, [attendanceRecords, searchTerm, selectedDepartment, selectedStatus, selectedLocation, selectedFlags, sortBy, sortOrder]);

  const totalPages = Math.ceil(filteredRecords.length / itemsPerPage);

  // Ensure currentPage is within valid range
  const validCurrentPage = Math.min(Math.max(1, currentPage), Math.max(1, totalPages));

  const paginatedRecords = useMemo(() => {
    const startIndex = (validCurrentPage - 1) * itemsPerPage;
    return filteredRecords.slice(startIndex, startIndex + itemsPerPage);
  }, [filteredRecords, validCurrentPage, itemsPerPage]);

  // Update currentPage if it's out of range
  useEffect(() => {
    if (currentPage !== validCurrentPage) {
      setCurrentPage(validCurrentPage);
    }
  }, [currentPage, validCurrentPage]);

  // Function to get status dot color for avatars
  const getStatusDotColor = (record: AttendanceRecord) => {
    const currentStatus = getCurrentStatus(record);
    
    switch (currentStatus) {
      case 'present':
        return 'var(--status-green)';
      case 'on-break':
        return 'var(--status-yellow)';
      case 'on-transfer':
        return 'var(--status-blue)';
      case 'on-leave':
        return 'var(--status-purple)';
      case 'absent':
        return 'var(--status-red)';
      default:
        return 'var(--status-gray)'; // #6b7280
    }
  };

  // Function to determine current status based on activity
  const getCurrentStatus = (record: AttendanceRecord) => {
    const now = new Date();
    const currentTime = now.toTimeString().slice(0, 5); // HH:MM format
    
    // Check if currently on break
    const activeBreak = record.breaks.find(breakItem => {
      if (!breakItem.breakEnd) return true; // Break without end time means currently on break
      return breakItem.breakStart <= currentTime && currentTime <= breakItem.breakEnd;
    });
    
    if (activeBreak) return 'on-break';
    
    // Check if currently on transfer
    const activeTransfer = record.transfers.find(transfer => {
      if (!transfer.transferEnd) return true; // Transfer without end time means currently in transfer
      return transfer.transferStart <= currentTime && currentTime <= transfer.transferEnd;
    });
    
    if (activeTransfer) return 'on-transfer';
    
    // Check if on leave
    if (record.status === 'on-leave') return 'on-leave';
    
    // Check if present (has clock in but no clock out for today)
    const hasClockIn = record.timeEntries.some(entry => entry.clockIn);
    const hasClockOut = record.timeEntries.some(entry => entry.clockOut);
    
    if (hasClockIn && !hasClockOut) return 'present';
    if (hasClockIn && hasClockOut) return null; // No status for completed work
    
    // Check if absent (was scheduled to work but didn't clock in)
    if (record.scheduledClockIn && record.scheduledLocation) {
      if (!hasClockIn) return 'absent';
    }
    
    // Default to no status if no clock in and no schedule
    return null;
  };

  const getStatusBadge = (record: AttendanceRecord) => {
    const currentStatus = getCurrentStatus(record);
    
    switch (currentStatus) {
      case 'present':
        return (
          <span className="px-1.5 py-0.5 rounded-full text-xs font-medium bg-green-50 text-status-green">
            Present
          </span>
        );
      case 'on-break':
        return (
          <span className="px-1.5 py-0.5 rounded-full text-xs font-medium bg-yellow-50 text-status-yellow">
            On Break
          </span>
        );
      case 'on-transfer':
        return (
          <span className="px-1.5 py-0.5 rounded-full text-xs font-medium bg-blue-50 text-status-blue">
            In Transfer
          </span>
        );
      case 'on-leave':
        return (
          <span className="px-1.5 py-0.5 rounded-full text-xs font-medium bg-purple-50 text-status-purple">
            On Leave
          </span>
        );
      case 'absent':
        return (
          <span className="px-1.5 py-0.5 rounded-full text-xs font-medium bg-red-50 text-status-red">
            Absent
          </span>
        );
      default:
        return null; // No mostrar nada para estados desconocidos
    }
  };

  const getStatusIcon = (record: AttendanceRecord) => {
    const currentStatus = getCurrentStatus(record);
    
    switch (currentStatus) {
      case 'present':
        return <CheckCircle className="w-4 h-4 text-status-green" />;
      case 'on-break':
        return <ClockIcon className="w-4 h-4 text-status-yellow" />;
      case 'on-transfer':
        return <MapPin className="w-4 h-4 text-status-blue" />;
      case 'on-leave':
        return <CalendarCheck className="w-4 h-4 text-status-purple" />;
      case 'absent':
        return <XCircle className="w-4 h-4 text-status-red" />;
      default:
        return null; // No mostrar ícono para estados desconocidos
    }
  };

  // Helper function to format status with aligned icon and badge
  const formatStatusWithIcon = (record: AttendanceRecord) => {
    const statusIcon = getStatusIcon(record);
    const statusBadge = getStatusBadge(record);
    
    if (!statusBadge) {
      // When no badge, show nothing (for employees with no status)
      return null;
    }
    
    return (
      <div className="flex items-center">
        <div className="-ml-4 mr-1">
          {statusIcon}
        </div>
        {statusBadge}
      </div>
    );
  };

  // Handle individual record selection
  const handleRecordSelect = (recordId: string) => {
    const newSelected = new Set(selectedRecords);
    if (newSelected.has(recordId)) {
      newSelected.delete(recordId);
    } else {
      newSelected.add(recordId);
    }
    setSelectedRecords(newSelected);
    
    // Update select all state based on all selectable items
    const allSelectableIds = getAllSelectableIds();
    const selectedFromCurrentPage = allSelectableIds.filter(id => newSelected.has(id));
    setSelectAll(selectedFromCurrentPage.length === allSelectableIds.length && allSelectableIds.length > 0);
  };

  // Handle select all toggle
  const handleSelectAll = () => {
    if (selectAll) {
      // Deselect all and collapse all records
      setSelectedRecords(new Set());
      setSelectAll(false);
      setExpandedRecords(new Set());
    } else {
      // Expand all multi-session records and select all items
      const recordsToExpand = new Set<string>();
      const allSelectableIds: string[] = [];
      
      paginatedRecords.forEach(record => {
        const workSessionsCount = getWorkSessionsCount(record);
        const hasMultipleSessions = workSessionsCount > 1;
        
        if (hasMultipleSessions) {
          recordsToExpand.add(record.id);
          // Add work session IDs for expanded records
          const workSessions = generateWorkSessions(record);
          workSessions.forEach(session => allSelectableIds.push(session.id));
        } else {
          // Add single record ID
          allSelectableIds.push(record.id);
        }
      });
      
      setExpandedRecords(recordsToExpand);
      setSelectedRecords(new Set(allSelectableIds));
      setSelectAll(true);
    }
  };

  // Get all selectable IDs including work sessions
  const getAllSelectableIds = () => {
    const allIds: string[] = [];
    
    paginatedRecords.forEach(record => {
      const workSessionsCount = getWorkSessionsCount(record);
      const hasMultipleSessions = workSessionsCount > 1;
      
      if (hasMultipleSessions) {
        // For records with multiple sessions, add work session IDs
        const workSessions = generateWorkSessions(record);
        workSessions.forEach(session => allIds.push(session.id));
      } else {
        // For single session records, add the record ID
        allIds.push(record.id);
      }
    });
    
    return allIds;
  };

  // Update select all state when pagination changes
  useEffect(() => {
    const allSelectableIds = getAllSelectableIds();
    const selectedFromCurrentPage = allSelectableIds.filter(id => selectedRecords.has(id));
    setSelectAll(selectedFromCurrentPage.length === allSelectableIds.length && allSelectableIds.length > 0);
  }, [paginatedRecords, selectedRecords, expandedRecords]);

  // Handle record expansion
  const handleRecordExpansion = (recordId: string) => {
    const newExpanded = new Set(expandedRecords);
    if (newExpanded.has(recordId)) {
      newExpanded.delete(recordId);
    } else {
      newExpanded.add(recordId);
    }
    setExpandedRecords(newExpanded);
  };

  // Handle work session selection
  const handleWorkSessionSelect = (sessionId: string) => {
    const newSelected = new Set(selectedRecords);
    if (newSelected.has(sessionId)) {
      newSelected.delete(sessionId);
    } else {
      newSelected.add(sessionId);
    }
    setSelectedRecords(newSelected);
    
    // Update select all state based on all selectable items
    const allSelectableIds = getAllSelectableIds();
    const selectedFromCurrentPage = allSelectableIds.filter(id => newSelected.has(id));
    setSelectAll(selectedFromCurrentPage.length === allSelectableIds.length && allSelectableIds.length > 0);
  };

  // Generate individual work sessions for expanded records
  const generateWorkSessions = (record: AttendanceRecord) => {
    const sessions = organizeIntoSessions(record);
    return sessions.map((session: any, index: number) => ({
      id: `${record.id}-session-${index + 1}`,
      parentId: record.id,
      sessionNumber: index + 1,
      clockIn: session.punches.find((p: any) => p.type === 'in')?.timestamp || '--',
      clockOut: session.punches.find((p: any) => p.type === 'out')?.timestamp || '--',
      totalHours: session.totalHours || 0,
      location: session.location || '--',
      breaks: session.breaks || [],
      transfers: session.transfers || []
    }));
  };

  const handleSort = (field: typeof sortBy) => {
    if (sortBy === field) {
      setSortOrder(sortOrder === 'asc' ? 'desc' : 'asc');
    } else {
      setSortBy(field);
      setSortOrder('asc');
    }
  };

  const clearFilters = () => {
    setSelectedDepartment('');
    setSelectedStatus('');
    setSelectedLocation('');
    setSelectedFlags('');
    setSearchTerm('');
  };

  const openDetailsModal = (record: AttendanceRecord) => {
    setSelectedRecord(record);
    setIsModalOpen(true);
    setActiveTab('sessions'); // Reset to sessions tab when opening modal
  };

  // Handle floating menu actions  
  const handleMenuAction = (action: string, recordId: string, sessionId?: string) => {
    console.log(`Action: ${action}, Record: ${recordId}`, sessionId ? `Session: ${sessionId}` : '');
    setActiveFloatingMenu(null);
    
    switch (action) {
      case 'edit':
        startInlineEdit(recordId, sessionId);
        break;
      case 'save':
        saveInlineEdit();
        break;
      case 'save_and_approve':
        saveInlineEdit(true);
        break;
      case 'approve':
        // Approve the session/record
        break;
      case 'reject':
        // Reject the session/record
        break;
      case 'reject_with_comment':
        // Open comment modal and reject
        break;
      case 'reset':
        // Reset the session/record to original state
        break;
    }
  };

  // Start inline editing
  const startInlineEdit = (recordId: string, sessionId?: string) => {
    const record = attendanceRecords.find(r => r.id === recordId);
    if (!record) return;

    setEditingRecord(recordId);
    setEditingSession(sessionId || null);

    // Get current times (prioritize modified times) and keep in display format
    const currentClockIn = record.modifiedClockIn || getFirstClockIn(record.timeEntries) || '';
    const currentClockOut = record.modifiedClockOut || getLastClockOut(record.timeEntries) || '';

    // Keep in display format (HH:MM) - don't convert to editable format yet
    setEditClockIn(currentClockIn);
    setEditClockOut(currentClockOut);
  };

  // Convert time string to editable format (remove AM/PM, convert to HHMM)
  const convertTimeToEditableFormat = (timeString: string): string => {
    if (!timeString || timeString === '--') return '';
    
    try {
      // Parse various time formats and convert to HHMM
      const cleanTime = timeString.replace(/[^\d:]/g, '');
      const [hours, minutes] = cleanTime.split(':');
      return `${(hours || '0').padStart(2, '0')}${(minutes || '0').padStart(2, '0')}`;
    } catch {
      return '';
    }
  };

  // Convert input to military time format (HH:MM)
  const convertToMilitaryTime = (input: string): string => {
    if (!input) return '';
    
    // Remove any non-digits
    const digits = input.replace(/\D/g, '');
    
    if (digits.length === 0) return '';
    
    let hours, minutes;
    
    if (digits.length <= 2) {
      // 1-2 digits: treat as hours
      hours = parseInt(digits);
      minutes = 0;
    } else if (digits.length === 3) {
      // 3 digits: first digit is hour, last two are minutes (e.g., 300 = 3:00)
      hours = parseInt(digits.charAt(0));
      minutes = parseInt(digits.slice(1));
    } else if (digits.length === 4) {
      // 4 digits: first two are hours, next two are minutes (e.g., 1300 = 13:00)
      hours = parseInt(digits.slice(0, 2));
      minutes = parseInt(digits.slice(2, 4));
    } else {
      // More than 4 digits is invalid
      return '';
    }
    
    // Validate ranges
    if (hours > 23 || minutes > 59) {
      return ''; // Invalid time
    }
    
    // Return in HH:MM format
    return `${hours.toString().padStart(2, '0')}:${minutes.toString().padStart(2, '0')}`;
  };

  // Save inline edit
  const saveInlineEdit = (approve: boolean = false) => {
    if (!editingRecord) return;

    const record = attendanceRecords.find(r => r.id === editingRecord);
    if (!record) return;

    // Convert input values to display format
    const newClockIn = editClockIn ? convertToMilitaryTime(editClockIn) : undefined;
    const newClockOut = editClockOut ? convertToMilitaryTime(editClockOut) : undefined;

    // In real app, this would be an API call
    console.log('Saving modified times:', {
      recordId: editingRecord,
      sessionId: editingSession,
      modifiedClockIn: newClockIn,
      modifiedClockOut: newClockOut,
      approve
    });

    // Update the record (in real app, this would update the state/database)
    record.modifiedClockIn = newClockIn;
    record.modifiedClockOut = newClockOut;

    // If approving, mark as approved with modifications
    if (approve) {
      // This would update the approval status in real implementation
      console.log('Approving with modifications');
    }

    // Exit edit mode
    cancelInlineEdit();
  };

  // Cancel inline edit
  const cancelInlineEdit = () => {
    setEditingRecord(null);
    setEditingSession(null);
    setEditClockIn('');
    setEditClockOut('');
    setActiveFloatingMenu(null);
  };

  // Get display time (prioritize modified times)
  const getDisplayTime = (record: AttendanceRecord, type: 'clockIn' | 'clockOut'): string => {
    if (type === 'clockIn') {
      return record.modifiedClockIn || getFirstClockIn(record.timeEntries) || '--';
    } else {
      return record.modifiedClockOut || getLastClockOut(record.timeEntries) || '--';
    }
  };

  // Helper function to render time with asterisk if modified
  const renderTimeWithModifiedIndicator = (record: AttendanceRecord, type: 'clockIn' | 'clockOut') => {
    const isModified = type === 'clockIn' ? record.modifiedClockIn : record.modifiedClockOut;
    const showOriginal = showOriginalTimes.has(record.id);
    
    // Get the appropriate time based on whether we're showing original or modified
    let time;
    if (isModified && !showOriginal) {
      // Show modified time
      time = type === 'clockIn' ? record.modifiedClockIn : record.modifiedClockOut;
    } else if (isModified && showOriginal) {
      // Show original time (before modification)
      time = type === 'clockIn' ? record.originalClockIn : record.originalClockOut;
    } else {
      // Show regular time (no modifications)
      time = getDisplayTime(record, type);
    }
    
    if (!time || time === '--') return <span className="text-sm text-gray-500 pl-1">--</span>;
    
    return (
               <div className="relative inline-block">
                 <span className="text-sm text-gray-900">{time}</span>
                 {isModified && !showOriginal && (
                   <span className="absolute -top-1 -right-2 text-xs text-gray-900 font-bold">*</span>
                 )}
               </div>
    );
  };

  // Check if record is being edited
  const isRecordEditing = (recordId: string, sessionId?: string): boolean => {
    const editingKey = sessionId ? `${recordId}-${sessionId}` : recordId;
    const currentEditingKey = editingSession ? `${editingRecord}-${editingSession}` : editingRecord;
    return editingKey === currentEditingKey;
  };

  // Smart time input component
  const SmartTimeInput = ({ 
    value, 
    onChange, 
    className = ""
  }: {
    value: string;
    onChange: (value: string) => void;
    className?: string;
  }) => {
    const [inputValue, setInputValue] = useState(value);
    const [isFocused, setIsFocused] = useState(false);

    useEffect(() => {
      // Always show the formatted value when not focused
      setInputValue(value);
    }, [value]);

    const handleInputChange = (e: React.ChangeEvent<HTMLInputElement>) => {
      const rawInput = e.target.value;
      
      // While focused, allow digits only and limit to 4 characters
      const digitsOnly = rawInput.replace(/\D/g, '').slice(0, 4);
      setInputValue(digitsOnly);
    };

    const handleFocus = () => {
      setIsFocused(true);
      // Only NOW convert formatted time back to digits for editing
      const digitsOnly = inputValue.replace(/\D/g, '');
      setInputValue(digitsOnly);
    };

    const handleBlur = () => {
      setIsFocused(false);
      
      if (inputValue === '') {
        onChange('');
        setInputValue('');
        return;
      }
      
      // Convert to military time format on blur
      const militaryTime = convertToMilitaryTime(inputValue);
      
      if (militaryTime === '') {
        // Invalid time - clear the input
        setInputValue('');
        onChange('');
      } else {
        // Valid time - show in HH:MM format and save
        setInputValue(militaryTime);
        onChange(militaryTime);
      }
    };

    const handleKeyDown = (e: React.KeyboardEvent) => {
      if (e.key === 'Enter') {
        (e.target as HTMLInputElement).blur();
      } else if (e.key === 'Escape') {
        // Restore original formatted value
        setInputValue(value);
        setIsFocused(false);
        (e.target as HTMLInputElement).blur();
      }
    };

      return (
        <input
          type="text"
          value={inputValue}
          onChange={handleInputChange}
          onFocus={handleFocus}
          onBlur={handleBlur}
          onKeyDown={handleKeyDown}
          className={`w-16 px-1 py-1 text-sm text-center border border-gray-300 rounded focus:ring-2 focus:ring-primary focus:border-primary transition-colors ${className}`}
        />
      );
  };

  const toggleFloatingMenu = (menuId: string, e: React.MouseEvent) => {
    e.stopPropagation();
    // Always close any open menu first, then open the new one if it's different
    if (activeFloatingMenu === menuId) {
      setActiveFloatingMenu(null);
    } else {
      setActiveFloatingMenu(menuId);
    }
  };

  // Render floating menu component
  const renderFloatingMenu = (menuId: string, sessionId?: string, recordIndex?: number) => {
    if (activeFloatingMenu !== menuId) return null;
    
    // Extract recordId from menuId for action handling
    const recordId = menuId.includes('-') ? menuId.split('-')[0] : menuId;
    const actualSessionId: string | undefined = sessionId;
    
    // Check if this record is being edited
    // @ts-ignore - actualSessionId can be undefined, which is handled correctly by the function
    const isEditing = isRecordEditing(recordId, actualSessionId);

    // Calculate smart alignment based on menu options count
    const getMenuOptionsCount = () => {
      if (isEditing) {
        return 3; // Save, Save & Approve, Cancel
      } else {
        return 5; // Edit, Approve, Reject, Reject with Comment, Reset
      }
    };
    
    const menuOptionsCount = getMenuOptionsCount();
    const recordsForBottomAlignment = Math.ceil(menuOptionsCount / 2);
    const isLastRecords = recordIndex !== undefined && recordIndex >= paginatedRecords.length - recordsForBottomAlignment;
    const menuAlignment = isLastRecords ? 'bottom-0' : 'top-0';

    return (
      <div className={`absolute right-full ${menuAlignment} mr-1 bg-white border border-gray-200 rounded-md shadow-lg z-50 py-1 min-w-48`}>
        {isEditing ? (
          // Editing menu
          <>
            <button
              // @ts-ignore - actualSessionId can be undefined, which is handled correctly
              onClick={() => handleMenuAction('save', recordId, actualSessionId)}
              className="w-full text-left px-4 py-2 text-sm text-gray-900 hover:bg-gray-100 transition-colors"
            >
              Save
            </button>
            <button
              // @ts-ignore - actualSessionId can be undefined, which is handled correctly
              onClick={() => handleMenuAction('save_and_approve', recordId, actualSessionId)}
              className="w-full text-left px-4 py-2 text-sm text-gray-900 hover:bg-gray-100 transition-colors"
            >
              Save & Approve
            </button>
            <div className="border-t border-gray-100 my-1"></div>
            <button
              onClick={cancelInlineEdit}
              className="w-full text-left px-4 py-2 text-sm text-gray-500 hover:bg-gray-100 transition-colors"
            >
              Cancel
            </button>
          </>
        ) : (
          // Normal menu
          <>
            <button
              // @ts-ignore - actualSessionId can be undefined, which is handled correctly
              onClick={() => handleMenuAction('edit', recordId, actualSessionId)}
              className="w-full text-left px-4 py-2 text-sm text-gray-900 hover:bg-gray-100 transition-colors"
            >
              Edit
            </button>
            <button
              // @ts-ignore - actualSessionId can be undefined, which is handled correctly
              onClick={() => handleMenuAction('approve', recordId, actualSessionId)}
              className="w-full text-left px-4 py-2 text-sm text-gray-900 hover:bg-gray-100 transition-colors"
            >
              Approve
            </button>
            <button
              // @ts-ignore - actualSessionId can be undefined, which is handled correctly
              onClick={() => handleMenuAction('reject', recordId, actualSessionId)}
              className="w-full text-left px-4 py-2 text-sm text-gray-900 hover:bg-gray-100 transition-colors"
            >
              Reject
            </button>
            <button
              // @ts-ignore - actualSessionId can be undefined, which is handled correctly
              onClick={() => handleMenuAction('reject_with_comment', recordId, actualSessionId)}
              className="w-full text-left px-4 py-2 text-sm text-gray-900 hover:bg-gray-100 transition-colors"
            >
              Reject with Comment
            </button>
            <button
              // @ts-ignore - actualSessionId can be undefined, which is handled correctly
              onClick={() => handleMenuAction('reset', recordId, actualSessionId)}
              className="w-full text-left px-4 py-2 text-sm text-gray-900 hover:bg-gray-100 transition-colors"
            >
              Reset
            </button>
          </>
        )}
      </div>
    );
  };

  const closeDetailsModal = () => {
    setSelectedRecord(null);
    setIsModalOpen(false);
  };

  const getFirstClockIn = (timeEntries: TimeEntry[]) => {
    if (timeEntries.length === 0) return null;
    return timeEntries[0]?.clockIn || null;
  };

  const getLastClockOut = (timeEntries: TimeEntry[]) => {
    if (timeEntries.length === 0) return null;
    const lastEntry = timeEntries[timeEntries.length - 1];
    return lastEntry?.clockOut || null;
  };

  // Helper function to format actual vs scheduled time with plan icon
  const formatActualVsScheduled = (actual: string | null, scheduled?: string, tooltipId?: string, record?: AttendanceRecord, type?: 'clockIn' | 'clockOut') => {
    if (!scheduled) {
      return (
        <div className="flex items-center">
          <ScheduleIcon className="w-3 h-3 invisible -ml-4 mr-1" />
          {record && type ? renderTimeWithModifiedIndicator(record, type) : (
            <span className={`text-sm text-gray-900 ${!actual ? 'pl-1' : ''}`}>{actual || '--'}</span>
          )}
        </div>
      );
    }
    
    if (!actual) {
      const tooltipKey = `${tooltipId}-scheduled`;
      return (
        <div className="flex items-center">
          <div 
            className="-ml-4 mr-1 cursor-pointer relative"
            onClick={(e) => {
              e.stopPropagation();
              setActiveTooltip(activeTooltip === tooltipKey ? null : tooltipKey);
            }}
          >
            <ScheduleIcon className="w-3 h-3 text-status-gray" />
            {activeTooltip === tooltipKey && (
              <div className="absolute bottom-full left-1/2 transform -translate-x-1/2 mb-2 px-2 py-1 bg-status-gray text-white text-xs rounded whitespace-nowrap z-50">
                Scheduled: {scheduled}
                <div className="absolute top-full left-1/2 transform -translate-x-1/2 w-0 h-0 border-l-4 border-r-4 border-t-4 border-transparent border-t-[#6b7280]"></div>
              </div>
            )}
          </div>
          <span className="text-sm text-gray-900 pl-1">--</span>
        </div>
      );
    }

    // Convert time strings to comparable format (HH:MM)
    const actualTime = actual.replace(/[^\d:]/g, '');
    const scheduledTime = scheduled.replace(/[^\d:]/g, '');
    
    const isLate = actualTime > scheduledTime;
    const isEarly = actualTime < scheduledTime;
    const isOnTime = actualTime === scheduledTime;
    const tooltipKey = `${tooltipId}-${isOnTime ? 'ontime' : isLate ? 'late' : 'early'}`;
    
    return (
      <div className="flex items-center">
        <div 
          className="-ml-4 mr-1 cursor-pointer relative"
          onClick={(e) => {
            e.stopPropagation();
            setActiveTooltip(activeTooltip === tooltipKey ? null : tooltipKey);
          }}
        >
          <ScheduleIcon className={`w-3 h-3 ${isOnTime ? 'text-status-green' : isLate ? 'text-status-red' : 'text-status-blue'}`} />
          {activeTooltip === tooltipKey && (
            <div className={`absolute bottom-full left-1/2 transform -translate-x-1/2 mb-2 px-2 py-1 text-white text-xs rounded whitespace-nowrap z-50 ${
              isOnTime ? 'bg-status-green' : isLate ? 'bg-status-red' : 'bg-status-blue'
            }`}>
              {isOnTime ? `On time (scheduled: ${scheduled})` : isLate ? `Late (scheduled: ${scheduled})` : `Early (scheduled: ${scheduled})`}
              <div className={`absolute top-full left-1/2 transform -translate-x-1/2 w-0 h-0 border-l-4 border-r-4 border-t-4 border-transparent ${
                isOnTime ? 'border-t-[#15803d]' : isLate ? 'border-t-[#b91c1c]' : 'border-t-[#2563eb]'
              }`}></div>
            </div>
          )}
        </div>
        {record && type ? renderTimeWithModifiedIndicator(record, type) : (
          <span className="text-sm text-gray-900">{actual}</span>
        )}
      </div>
    );
  };

  // Helper function to format actual vs scheduled location with plan icon
  const formatLocationVsScheduled = (record: AttendanceRecord) => {
    const currentStatus = getCurrentStatus(record);
    const actualLocation = currentStatus === 'present' ? (record.location || 'Main Office') : null;
    const scheduledLocation = record.scheduledLocation;
    const tooltipId = `location-${record.id}`;

    if (!scheduledLocation) {
      return (
        <div className="flex items-center">
          <ScheduleIcon className="w-3 h-3 invisible -ml-4 mr-1" />
          <span className={`text-sm text-gray-900 ${!actualLocation ? 'pl-1' : ''}`}>{actualLocation || '--'}</span>
        </div>
      );
    }

    if (!actualLocation) {
      const tooltipKey = `${tooltipId}-scheduled`;
      return (
        <div className="flex items-center">
          <div 
            className="-ml-4 mr-1 cursor-pointer relative"
            onClick={(e) => {
              e.stopPropagation();
              setActiveTooltip(activeTooltip === tooltipKey ? null : tooltipKey);
            }}
          >
            <ScheduleIcon className="w-3 h-3 text-status-gray" />
            {activeTooltip === tooltipKey && (
              <div className="absolute bottom-full left-1/2 transform -translate-x-1/2 mb-2 px-2 py-1 bg-status-gray text-white text-xs rounded whitespace-nowrap z-50">
                Scheduled: {scheduledLocation}
                <div className="absolute top-full left-1/2 transform -translate-x-1/2 w-0 h-0 border-l-4 border-r-4 border-t-4 border-transparent border-t-[#6b7280]"></div>
              </div>
            )}
          </div>
          <span className="text-sm text-gray-900 pl-1">--</span>
        </div>
      );
    }

    const isCorrectLocation = actualLocation === scheduledLocation;
    const tooltipKey = `${tooltipId}-${isCorrectLocation ? 'correct' : 'wrong'}`;
    
    return (
      <div className="flex items-center">
        <div 
          className="-ml-4 mr-1 cursor-pointer relative"
          onClick={(e) => {
            e.stopPropagation();
            setActiveTooltip(activeTooltip === tooltipKey ? null : tooltipKey);
          }}
        >
          <ScheduleIcon className={`w-3 h-3 ${isCorrectLocation ? 'text-status-green' : 'text-status-orange'}`} />
          {activeTooltip === tooltipKey && (
            <div className={`absolute bottom-full left-1/2 transform -translate-x-1/2 mb-2 px-2 py-1 text-white text-xs rounded whitespace-nowrap z-50 ${
              isCorrectLocation ? 'bg-status-green' : 'bg-status-orange'
            }`}>
              {isCorrectLocation ? `Correct location (scheduled: ${scheduledLocation})` : `Wrong location (scheduled: ${scheduledLocation})`}
              <div className={`absolute top-full left-1/2 transform -translate-x-1/2 w-0 h-0 border-l-4 border-r-4 border-t-4 border-transparent ${
                isCorrectLocation ? 'border-t-[#15803d]' : 'border-t-[#c2410c]'
              }`}></div>
            </div>
          )}
        </div>
        <span className="text-sm text-gray-900">{actualLocation}</span>
      </div>
    );
  };




  const getLocationInfo = (record: AttendanceRecord) => {
    const locations = new Set<string>();
    
    // Add main location
    if (record.location) {
      locations.add(record.location);
    }
    
    // Add locations from time entries
    record.timeEntries.forEach(entry => {
      if (entry.project) {
        locations.add(entry.project);
      }
    });
    
    // Add transfer locations
    record.transfers.forEach(transfer => {
      locations.add(transfer.fromLocation);
      locations.add(transfer.toLocation);
    });
    
    const uniqueLocations = Array.from(locations);
    const hasMultipleLocations = uniqueLocations.length > 1;
    
    return {
      locations: uniqueLocations,
      hasMultipleLocations,
      primaryLocation: record.location || uniqueLocations[0] || 'Unknown',
      locationCount: uniqueLocations.length
    };
  };

  const organizeIntoSessions = (record: AttendanceRecord) => {
    const sessions: Array<{
      id: string;
      sessionNumber: number;
      location: string;
      startTime: string;
      endTime: string | null;
      punches: Array<{
        id: string;
        timestamp: string;
        type: 'in' | 'out';
        activity?: string;
      }>;
      breaks: BreakEntry[];
      transfers: TransferEntry[];
      totalWorkHours: number;
      totalBreakTime: number;
      totalTransferTime: number;
    }> = [];

    // Create first session
    let currentSession = {
      id: 'session-1',
      sessionNumber: 1,
      location: record.location,
      startTime: getFirstClockIn(record.timeEntries) || '--',
      endTime: getLastClockOut(record.timeEntries) || null,
      punches: [
        ...record.timeEntries.map(entry => ({
          id: entry.id,
          timestamp: entry.clockIn,
          type: 'in' as const,
          activity: entry.activity
        })),
        ...record.timeEntries
          .filter(entry => entry.clockOut)
          .map(entry => ({
            id: `${entry.id}-out`,
            timestamp: entry.clockOut!,
            type: 'out' as const,
            activity: entry.activity
          }))
      ].sort((a, b) => a.timestamp.localeCompare(b.timestamp)),
      breaks: record.breaks,
      transfers: [] as TransferEntry[],
      totalWorkHours: record.totalHours,
      totalBreakTime: record.totalBreakTime,
      totalTransferTime: 0
    };

    // If there are transfers, split into multiple sessions
    if (record.transfers.length > 0) {
      // For simplicity, we'll create one session per transfer + 1
      // In a real implementation, this would be more sophisticated
      record.transfers.forEach((transfer, index) => {
        if (index === 0) {
          // First session ends at transfer start
          currentSession.endTime = transfer.transferStart;
          currentSession.transfers = [transfer];
          currentSession.totalTransferTime = transfer.duration;
        }
        
        // Create new session for each transfer
        const newSession = {
          id: `session-${index + 2}`,
          sessionNumber: index + 2,
          location: transfer.toLocation,
          startTime: transfer.transferEnd || transfer.transferStart,
          endTime: index === record.transfers.length - 1 ? getLastClockOut(record.timeEntries) : record.transfers[index + 1]?.transferStart || null,
          punches: [
            {
              id: `transfer-in-${index}`,
              timestamp: transfer.transferEnd || transfer.transferStart,
              type: 'in' as const,
              activity: 'Transfer arrival'
            }
          ],
          breaks: [] as BreakEntry[], // Breaks would be distributed based on timing
          transfers: [] as TransferEntry[],
          totalWorkHours: 0, // Would be calculated based on actual work time
          totalBreakTime: 0,
          totalTransferTime: 0
        };
        
        sessions.push(newSession);
      });
    }

    sessions.unshift(currentSession);
    return sessions;
  };

  // Create chronological timeline of time entries, breaks, and transfers
  const getChronologicalTimeline = (record: AttendanceRecord) => {
    const timeline: Array<{
      id: string;
      type: 'work' | 'break' | 'transfer';
      startTime: string;
      endTime: string | null;
      duration: number;
      label: string;
      details: string;
      notes?: string;
      breakType?: string;
      transferType?: string;
      fromLocation?: string;
      toLocation?: string;
    }> = [];

    // Add time entries
    record.timeEntries.forEach((entry) => {
      timeline.push({
        id: entry.id,
        type: 'work',
        startTime: entry.clockIn,
        endTime: entry.clockOut,
        duration: entry.hours,
        label: 'Work',
        details: `${entry.project} - ${entry.activity}`,
        notes: entry.notes
      });
    });

    // Add breaks
    record.breaks.forEach((breakEntry) => {
      timeline.push({
        id: breakEntry.id,
        type: 'break',
        startTime: breakEntry.breakStart,
        endTime: breakEntry.breakEnd,
        duration: breakEntry.breakEnd ? breakEntry.duration / 60 : 0, // Convert minutes to hours
        label: 'Break',
        details: `${breakEntry.breakType.charAt(0).toUpperCase() + breakEntry.breakType.slice(1)} Break`,
        notes: breakEntry.notes,
        breakType: breakEntry.breakType
      });
    });

    // Add transfers
    record.transfers.forEach((transferEntry) => {
      timeline.push({
        id: transferEntry.id,
        type: 'transfer',
        startTime: transferEntry.transferStart,
        endTime: transferEntry.transferEnd,
        duration: transferEntry.transferEnd ? transferEntry.duration / 60 : 0, // Convert minutes to hours
        label: 'Transfer',
        details: `${transferEntry.fromLocation} → ${transferEntry.toLocation}`,
        notes: transferEntry.notes,
        transferType: transferEntry.transferType,
        fromLocation: transferEntry.fromLocation,
        toLocation: transferEntry.toLocation
      });
    });

    // Sort by start time
    timeline.sort((a, b) => {
      const timeA = a.startTime;
      const timeB = b.startTime;
      return timeA.localeCompare(timeB);
    });

    return timeline;
  };

  const handleViewEmployeeAttendance = (record: AttendanceRecord) => {
    // Store employee data in sessionStorage
    const employeeData = {
      id: record.id,
      employeeId: record.employeeId,
      employeeName: record.employeeName,
      role: record.role,
      department: record.department,
      location: record.location
    };
    sessionStorage.setItem('selectedEmployee', JSON.stringify(employeeData));
    
    // Navigate to employee attendance page with slug
    const slug = record.employeeName.toLowerCase().replace(/\s+/g, '-');
    const url = `/org/cmp/management/time-and-attendance/employee-attendance/${slug}`;
    console.log('Navigating to:', url);
    router.navigate(url);
  };

  return (
    <div className="p-6">
      {/* Header */}
      <div className="mb-6">
        <h1 className="text-xl font-semibold text-foreground mb-1">Team Attendance</h1>
        <p className="text-xs text-muted-foreground">Track and manage team attendance records</p>
      </div>

      {/* Stats Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-5 gap-4 mb-6">
        <div className="bg-white border border-gray-200 rounded-lg p-4">
          <div className="flex items-center gap-3">
            <CheckCircle className="h-5 w-5 text-status-green" />
            <div>
              <div className="text-2xl font-bold">
                {attendanceRecords.filter(r => r.status === 'present').length}
              </div>
              <div className="text-sm text-muted-foreground">Present</div>
            </div>
          </div>
        </div>
        <div className="bg-white border border-gray-200 rounded-lg p-4">
          <div className="flex items-center gap-3">
            <XCircle className="h-5 w-5 text-status-red" />
            <div>
              <div className="text-2xl font-bold">
                {attendanceRecords.filter(r => r.status === 'absent').length}
              </div>
              <div className="text-sm text-muted-foreground">Absent</div>
            </div>
          </div>
        </div>
        <div className="bg-white border border-gray-200 rounded-lg p-4">
          <div className="flex items-center gap-3">
            <AlertTriangle className="h-5 w-5 text-status-orange" />
            <div>
              <div className="text-2xl font-bold">
                {attendanceRecords.filter(r => r.status === 'late').length}
              </div>
              <div className="text-sm text-muted-foreground">Late</div>
            </div>
          </div>
        </div>
        <div className="bg-white border border-gray-200 rounded-lg p-4">
          <div className="flex items-center gap-3">
            <ClockIcon className="h-5 w-5 text-status-purple" />
            <div>
              <div className="text-2xl font-bold">
                {attendanceRecords.filter(r => r.status === 'on-break').length}
              </div>
              <div className="text-sm text-muted-foreground">On Break</div>
            </div>
          </div>
        </div>
        <div className="bg-white border border-gray-200 rounded-lg p-4">
          <div className="flex items-center gap-3">
            <ClockIcon className="h-5 w-5 text-primary" />
            <div>
              <div className="text-2xl font-bold">
                {attendanceRecords.filter(r => r.status === 'on-leave').length}
              </div>
              <div className="text-sm text-muted-foreground">PTO & Leave</div>
            </div>
          </div>
        </div>
      </div>

      {/* Search and Filters */}
      <div className="mb-4">
        <div className={`bg-white border border-gray-200 py-6 px-6 ${
          showFilters ? 'rounded-t-lg' : 'rounded-lg'
        }`}>
          <div className="flex items-center gap-4">
            <div className="flex-1 relative">
              <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-gray-400" />
              <input
                type="text"
                placeholder="Search employees, roles, or departments..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                className="w-full pl-9 pr-3 py-1 border border-gray-200 rounded text-sm bg-gray-50 focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/50"
                aria-label="Search attendance records"
              />
            </div>
            <div className="flex items-center gap-2">
              <input
                type="date"
                value={selectedDate}
                onChange={(e) => setSelectedDate(e.target.value)}
                className="px-3 py-1 border border-gray-200 rounded text-sm focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/50"
                aria-label="Select date"
              />
              <button
                className={`px-3 py-1 border rounded text-sm transition-colors ${
                  showFilters
                    ? 'bg-gray-300 text-black border-gray-300'
                    : 'bg-white text-gray-700 border-gray-300 hover:bg-gray-50'
                }`}
                onClick={() => setShowFilters(!showFilters)}
                aria-label="Toggle filters"
              >
                <Filter className="w-4 h-4 inline mr-1" />
                Filters
              </button>
            </div>
          </div>
        </div>
        
        {showFilters && (
          <div className="bg-white border-l border-r border-b border-gray-200 rounded-b-lg py-6 px-6">
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-3 mb-4">
              <select 
                value={selectedStatus}
                onChange={(e) => setSelectedStatus(e.target.value)}
                className="px-3 py-1 border border-gray-200 rounded text-sm focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/50"
                aria-label="Filter by status"
                id="status-filter"
              >
                <option value="">All Statuses</option>
                <option value="present">Present</option>
                <option value="absent">Absent</option>
                <option value="late">Late</option>
                <option value="partial">Partial</option>
                <option value="on-break">On Break</option>
                <option value="on-leave">On Leave</option>
              </select>

              <select 
                value={selectedDepartment}
                onChange={(e) => setSelectedDepartment(e.target.value)}
                className="px-3 py-1 border border-gray-200 rounded text-sm focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/50"
                aria-label="Filter by department"
                id="department-filter"
              >
                <option value="">All Departments</option>
                <option value="Engineering">Engineering</option>
                <option value="Design">Design</option>
                <option value="Management">Management</option>
                <option value="Marketing">Marketing</option>
                <option value="Product">Product</option>
                <option value="Human Resources">Human Resources</option>
                <option value="Sales">Sales</option>
              </select>

              <select 
                value={selectedLocation}
                onChange={(e) => setSelectedLocation(e.target.value)}
                className="px-3 py-1 border border-gray-200 rounded text-sm focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/50"
                aria-label="Filter by location"
                id="location-filter"
              >
                <option value="">All Locations</option>
                <option value="Office">Office</option>
                <option value="Remote">Remote</option>
              </select>

              <select 
                value={selectedFlags}
                onChange={(e) => setSelectedFlags(e.target.value)}
                className="px-3 py-1 border border-gray-200 rounded text-sm focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/50"
                aria-label="Filter by flags"
                id="flags-filter"
              >
                <option value="">All Records</option>
                <option value="flagged">Flagged Only</option>
                <option value="clean">Clean Only</option>
              </select>
            </div>

            <div className="flex justify-between items-center">
              <button 
                onClick={clearFilters}
                className="text-xs text-gray-500 hover:text-gray-700"
              >
                Clear all filters
              </button>
              <div className="flex gap-3 items-center">
                <span className="text-xs text-gray-500">Sort by:</span>
                <button 
                  onClick={() => handleSort('employeeName')}
                  className={`text-xs hover:text-gray-900 flex items-center gap-1 ${
                    sortBy === 'employeeName' ? 'text-gray-900 font-medium' : 'text-gray-600'
                  }`}
                >
                  Name
                  {sortBy === 'employeeName' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                </button>
                <button 
                  onClick={() => handleSort('department')}
                  className={`text-xs hover:text-gray-900 flex items-center gap-1 ${
                    sortBy === 'department' ? 'text-gray-900 font-medium' : 'text-gray-600'
                  }`}
                >
                  Department
                  {sortBy === 'department' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                </button>
                <button 
                  onClick={() => handleSort('clockIn')}
                  className={`text-xs hover:text-gray-900 flex items-center gap-1 ${
                    sortBy === 'clockIn' ? 'text-gray-900 font-medium' : 'text-gray-600'
                  }`}
                >
                  Clock In
                  {sortBy === 'clockIn' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                </button>
                <button 
                  onClick={() => handleSort('totalHours')}
                  className={`text-xs hover:text-gray-900 flex items-center gap-1 ${
                    sortBy === 'totalHours' ? 'text-gray-900 font-medium' : 'text-gray-600'
                  }`}
                >
                  Hours
                  {sortBy === 'totalHours' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                </button>
              </div>
            </div>
          </div>
        )}
      </div>

      {/* Bulk Actions Bar */}
      {selectedRecords.size > 0 && (
        <div className="bg-primary/5 border border-primary/20 rounded-lg p-4 mb-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-3">
              <span className="text-sm font-medium text-gray-900">
                {selectedRecords.size} record{selectedRecords.size !== 1 ? 's' : ''} selected
              </span>
              <button
                onClick={() => {
                  setSelectedRecords(new Set());
                  setSelectAll(false);
                }}
                className="text-xs text-gray-600 hover:text-gray-800"
              >
                Clear selection
              </button>
            </div>
            <div className="flex items-center gap-2">
              <button className="px-3 py-1 bg-white border border-gray-300 rounded text-sm hover:bg-gray-50 transition-colors">
                Export Selected
              </button>
              <button className="px-3 py-1 bg-white border border-gray-300 rounded text-sm hover:bg-gray-50 transition-colors">
                Bulk Edit
              </button>
              <button className="px-3 py-1 bg-status-red text-white rounded text-sm hover:bg-red-700 transition-colors">
                Delete Selected
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Table View */}
        <div className="bg-white border border-gray-200 rounded-lg overflow-hidden mb-4">
          <div className="overflow-x-auto">
            <table className="w-full table-fixed">
              <thead className="bg-gray-50 border-b border-gray-200">
                <tr>
                  <th className="text-center py-3 px-2 font-medium text-gray-900 text-xs w-14">
                    <div className="flex items-center justify-center h-full">
                      <input
                        type="checkbox"
                        checked={selectAll}
                        onChange={handleSelectAll}
                        className="w-3.5 h-3.5 text-primary focus:ring-primary/20 border-gray-300 rounded"
                        aria-label="Select all records"
                      />
                    </div>
                  </th>
                  <th className="text-left py-3 pl-1 pr-6 font-medium text-gray-900 text-xs w-56">
                    <div className="flex items-center gap-3">
                      <div className="w-6"></div>
                      <button
                        onClick={() => handleSort('employeeName')}
                        className="flex items-center gap-1 hover:text-gray-700 pl-1.5"
                      >
                        Employee
                        {sortBy === 'employeeName' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                      </button>
                    </div>
                  </th>
                  <th className="text-left py-3 px-2 font-medium text-gray-900 text-xs w-24">
                    <button
                      onClick={() => handleSort('status')}
                      className="flex items-center gap-1 hover:text-gray-700"
                    >
                      Status
                      {sortBy === 'status' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                    </button>
                  </th>
                  <th className="text-left py-3 px-4 font-medium text-gray-900 text-xs">
                    <button
                      onClick={() => handleSort('location')}
                      className="flex items-center gap-1 hover:text-gray-700"
                    >
                      Location
                      {sortBy === 'location' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                    </button>
                  </th>
                  <th className="text-left py-3 px-2 font-medium text-gray-900 text-xs w-24">
                    <button
                      onClick={() => handleSort('clockIn')}
                      className="flex items-center gap-1 hover:text-gray-700"
                    >
                      Clock In
                      {sortBy === 'clockIn' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                    </button>
                  </th>
                  <th className="text-left py-3 px-2 font-medium text-gray-900 text-xs w-24">Clock Out</th>
                  <th className="text-left py-3 px-2 font-medium text-gray-900 text-xs w-24">
                    Breaks
                  </th>
                  <th className="text-left py-3 px-2 font-medium text-gray-900 text-xs w-24">
                    Transfers
                  </th>
                  <th className="text-left py-3 px-2 font-medium text-gray-900 text-xs w-24">
                    <button
                      onClick={() => handleSort('totalHours')}
                      className="flex items-center gap-1 hover:text-gray-700"
                    >
                      Total Hours
                      {sortBy === 'totalHours' && (sortOrder === 'asc' ? <SortAsc className="w-3 h-3" /> : <SortDesc className="w-3 h-3" />)}
                    </button>
                  </th>
                  <th className="text-left py-3 px-2 font-medium text-gray-900 text-xs w-24">
                    Overtime
                  </th>
                  <th className="text-left py-3 px-2 font-medium text-gray-900 text-xs w-12">
                    <div className="w-4 h-4 rounded-full border border-gray-900 flex items-center justify-center">
                      <span className="text-[10px] font-medium text-gray-900">M</span>
                    </div>
                  </th>
                  <th className="text-left py-3 px-2 font-medium text-gray-900 text-xs w-12">
                    <Flag className="w-4 h-4 inline text-gray-900" />
                  </th>
                  <th className="text-left py-3 px-2 font-medium text-gray-900 text-xs w-24">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-200">
                {paginatedRecords.map((record, index) => {
                  const workSessionsCount = getWorkSessionsCount(record);
                  const hasMultipleSessions = workSessionsCount > 1;
                  const isExpanded = expandedRecords.has(record.id);
                  const workSessions = hasMultipleSessions ? generateWorkSessions(record) : [];
                  
                  return (
                  <>
                    <tr key={record.id} className="hover:bg-gray-50 transition-colors">
                        <td className="py-2 px-2">
                          <div className="flex items-center justify-center h-full">
                            {hasMultipleSessions ? (
                            <div className="flex items-center gap-1">
                            <button
                                onClick={() => handleRecordExpansion(record.id)}
                                className="w-3.5 h-3.5 flex items-center justify-center text-gray-600 hover:text-gray-800 transition-colors"
                                aria-label={`${isExpanded ? 'Collapse' : 'Expand'} work sessions for ${record.employeeName}`}
                              >
                                {isExpanded ? (
                                  <ChevronDown className="w-3 h-3" />
                                ) : (
                                  <ChevronRight className="w-3 h-3" />
                              )}
                            </button>
                              <span className="text-xs text-gray-500 font-medium">
                                {workSessionsCount}
                              </span>
                            </div>
                            ) : (
                              <input
                                type="checkbox"
                                checked={selectedRecords.has(record.id)}
                                onChange={() => handleRecordSelect(record.id)}
                                className="w-3.5 h-3.5 text-primary focus:ring-primary/20 border-gray-300 rounded"
                                aria-label={`Select ${record.employeeName}`}
                              />
                            )}
                          </div>
                        </td>
                        <td className="py-2 pl-1 pr-6 w-56">
                          <div className="flex items-center gap-3">
                            <div className="relative">
                            <div 
                              className="w-8 h-8 rounded-full flex items-center justify-center text-white text-sm font-medium"
                                style={{ backgroundColor: generateAvatarColor(record.employeeName.split(' ')[0] || '', record.employeeName.split(' ')[1] || '') }}
                              >
                                {generateAvatarInitials(record.employeeName.split(' ')[0] || '', record.employeeName.split(' ')[1] || '')}
                              </div>
                              <div 
                                className="absolute -bottom-0.5 -right-0.5 w-2.5 h-2.5 rounded-full border border-white"
                                style={{ backgroundColor: getStatusDotColor(record) }}
                              >
                              </div>
                            </div>
                            <div>
                              <button
                                onClick={() => handleViewEmployeeAttendance(record)}
                                className="text-sm font-medium text-gray-900 hover:text-primary transition-colors text-left"
                                aria-label={`View ${record.employeeName} attendance details`}
                              >
                                {record.employeeName}
                              </button>
                              <div className="text-xs" style={{ color: '#6B7280' }}>{record.role}</div>
                            </div>
                          </div>
                        </td>
                      <td className="py-2 px-2 w-24">
                        {formatStatusWithIcon(record)}
                      </td>
                      <td className="py-2 px-4">
                        {formatLocationVsScheduled(record)}
                      </td>
                      <td className="py-2 px-2">
                        {isRecordEditing(record.id) ? (
                          <SmartTimeInput
                            value={editClockIn}
                            onChange={setEditClockIn}
                          />
                        ) : (
                          formatActualVsScheduled(getDisplayTime(record, 'clockIn'), record.scheduledClockIn, `clockin-${record.id}`, record, 'clockIn')
                        )}
                      </td>
                      <td className="py-2 px-2">
                        {isRecordEditing(record.id) ? (
                          <SmartTimeInput
                            value={editClockOut}
                            onChange={setEditClockOut}
                          />
                        ) : (
                          formatActualVsScheduled(getDisplayTime(record, 'clockOut'), record.scheduledClockOut, `clockout-${record.id}`, record, 'clockOut')
                        )}
                      </td>
                      <td className="py-2 px-2">
                        <div className="flex items-center gap-1">
                          {record.breaks.length > 0 ? (
                            <div className="flex items-center gap-1">
                              <span className="text-sm text-gray-900">
                                {record.breaks.length}
                              </span>
                              <span className="text-xs text-gray-500">
                                ({(record.totalBreakTime / 60).toFixed(2)}h)
                              </span>
                            </div>
                          ) : (
                            <span className="text-sm text-gray-500">--</span>
                          )}
                        </div>
                      </td>
                      <td className="py-2 px-2">
                        <div className="flex items-center gap-1">
                          {record.transfers.length > 0 ? (
                            <div className="flex items-center gap-1">
                              <span className="text-sm text-gray-900">
                                {record.transfers.length}
                              </span>
                              <span className="text-xs text-gray-500">
                                ({(record.totalTransferTime / 60).toFixed(2)}h)
                              </span>
                        </div>
                          ) : (
                            <span className="text-sm text-gray-500">--</span>
                          )}
                              </div>
                      </td>
                      <td className="py-2 px-2">
                        <span className="text-sm text-gray-900">{record.totalHours.toFixed(2)}h</span>
                            </td>
                            <td className="py-2 px-2">
                        <span className="text-sm text-gray-900">
                          {getOvertimeHours(record.totalHours) > 0 ? `${getOvertimeHours(record.totalHours).toFixed(2)}h` : '--'}
                                </span>
                            </td>
                            <td className="py-2 px-2">
                              <div className="flex items-center justify-start">
                                {renderModifiedIcon(record, record.id)}
                              </div>
                            </td>
                            <td className="py-2 px-2">
                              <div className="flex items-center justify-start">
                                {renderFlagIcon(record, record.id)}
                              </div>
                            </td>
                      <td className="py-2 px-2">
                        <div className="flex items-center">
                          <button
                            onClick={() => openDetailsModal(record)}
                            className="p-1 hover:bg-gray-100 rounded transition-colors"
                            aria-label={`View ${record.employeeName} attendance details`}
                          >
                            <Eye className="w-4 h-4" />
                          </button>
                          <div className="relative">
                          <button
                              onClick={(e) => toggleFloatingMenu(record.id, e)}
                            className={`p-1 hover:bg-gray-100 rounded transition-colors border ${
                              activeFloatingMenu === record.id ? 'border-gray-300 bg-gray-50' : 'border-transparent'
                            }`}
                            aria-label={`More options for ${record.employeeName}`}
                          >
                            <MoreVertical className="w-4 h-4" />
                          </button>
                            {renderFloatingMenu(record.id, undefined, index)}
                          </div>
                        </div>
                      </td>
                    </tr>
                    
                      {/* Expanded Work Sessions */}
                      {hasMultipleSessions && isExpanded && workSessions.map((session: any) => session ? (
                        <tr key={session.id} className="bg-gray-25 hover:bg-gray-50 transition-colors border-l-2 border-l-primary/20">
                          <td className="py-2 px-2">
                            {/* Empty space to align with expand arrow column */}
                          </td>
                           <td className="py-2 pl-1 pr-6 w-56">
                              <div className="flex items-center gap-3">
                               <div className="w-8 flex items-center justify-center">
                                 <input
                                   type="checkbox"
                                   checked={selectedRecords.has(session.id)}
                                   onChange={() => handleWorkSessionSelect(session.id)}
                                   className="w-3.5 h-3.5 text-primary focus:ring-primary/20 border-gray-300 rounded"
                                   aria-label={`Select Work Session ${session.sessionNumber} for ${record.employeeName}`}
                                 />
                                </div>
                               <span className="text-sm text-gray-600 font-medium">
                                 Work Session {session.sessionNumber}
                               </span>
                              </div>
                            </td>
                            <td className="py-2 px-2 w-24">
                            {/* Status column - empty for sessions */}
                            </td>
                            <td className="py-2 px-4">
                            <span className="text-sm text-gray-900">{session.location || '--'}</span>
                            </td>
                            <td className="py-2 px-4">
                              {isRecordEditing(record.id, session.id) ? (
                                <SmartTimeInput
                                  value={editClockIn}
                                  onChange={setEditClockIn}
                                />
                              ) : (
                                <span className="text-sm text-gray-900">{session.clockIn}</span>
                              )}
                            </td>
                            <td className="py-2 px-4">
                              {isRecordEditing(record.id, session.id) ? (
                                <SmartTimeInput
                                  value={editClockOut}
                                  onChange={setEditClockOut}
                                />
                              ) : (
                                <span className="text-sm text-gray-900">{session.clockOut}</span>
                              )}
                            </td>
                            <td className="py-2 px-4">
                            {/* Breaks column - empty for individual sessions */}
                            </td>
                            <td className="py-2 px-4">
                            {/* Transfers column - empty for individual sessions */}
                            </td>
                            <td className="py-2 px-4">
                            <span className="text-sm text-gray-900">{(session.totalHours || 0).toFixed(2)}h</span>
                            </td>
                            <td className="py-2 px-4">
                            {/* Overtime - empty for individual sessions */}
                          </td>
                          <td className="py-2 px-4">
                            {/* Modified - empty for individual sessions */}
                          </td>
                          <td className="py-2 px-4">
                            <div className="flex items-center justify-start">
                              {renderFlagIcon(record, `${session.id}-${record.id}`)}
                            </div>
                          </td>
                          <td className="py-2 px-4">
                            <div className="flex items-center">
                                  <button
                                className="p-1 rounded transition-colors invisible"
                                aria-hidden="true"
                                disabled
                                  >
                                    <Eye className="w-4 h-4" />
                                  </button>
                              <div className="relative">
                                <button
                                  onClick={(e) => toggleFloatingMenu(`${record.id}-${session.id}`, e)}
                                  className={`p-1 hover:bg-gray-100 rounded transition-colors border ${
                                    activeFloatingMenu === `${record.id}-${session.id}` ? 'border-gray-300 bg-gray-50' : 'border-transparent'
                                  }`}
                                  aria-label={`More options for ${record.employeeName} Work Session ${session.sessionNumber}`}
                                >
                                  <MoreVertical className="w-4 h-4" />
                                </button>
                                {renderFloatingMenu(`${record.id}-${session.id}`, session.id, index)}
                              </div>
                              </div>
                            </td>
                          </tr>
                      ) : null)}
                      </>
                  );
                })}
              </tbody>
            </table>
          </div>
        </div>

      {/* Pagination */}
      <div className="bg-white border border-gray-200 rounded-lg py-6 px-6">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-3">
            <span className="text-xs text-gray-600">Show:</span>
            <select 
              value={itemsPerPage}
              onChange={(e) => {
                setItemsPerPage(Number(e.target.value));
                setCurrentPage(1); // Reset to first page when changing items per page
              }}
              className="border border-gray-200 rounded px-2 py-1 text-xs focus:outline-none focus:ring-1 focus:ring-primary/20 focus:border-primary/50"
            >
              <option value={5}>5</option>
              <option value={10}>10</option>
              <option value={25}>25</option>
              <option value={50}>50</option>
            </select>
            <span className="text-xs text-gray-600">
              Showing {((validCurrentPage - 1) * itemsPerPage) + 1}-{Math.min(validCurrentPage * itemsPerPage, filteredRecords.length)} of {filteredRecords.length}
            </span>
          </div>
          
          {totalPages > 1 && (
            <div className="flex items-center gap-3">
              <button
                onClick={() => setCurrentPage(prev => Math.max(prev - 1, 1))}
                disabled={validCurrentPage === 1}
                className={`flex items-center gap-1 px-2 py-1 border rounded text-xs transition-colors ${
                  validCurrentPage === 1
                    ? 'border-gray-200 text-gray-400 cursor-not-allowed'
                    : 'border-gray-300 text-gray-700 hover:bg-gray-50'
                }`}
              >
                <ChevronLeft className="w-3 h-3" />
                Previous
              </button>
              
              <div className="flex items-center gap-1">
                {Array.from({ length: Math.min(totalPages, 5) }, (_, i) => {
                  let pageNum;
                  if (totalPages <= 5) {
                    pageNum = i + 1;
                  } else if (validCurrentPage <= 3) {
                    pageNum = i + 1;
                  } else if (validCurrentPage >= totalPages - 2) {
                    pageNum = totalPages - 4 + i;
                  } else {
                    pageNum = validCurrentPage - 2 + i;
                  }

                  return (
                <button
                      key={pageNum}
                      onClick={() => setCurrentPage(pageNum)}
                  className={`w-6 h-6 text-xs rounded transition-colors flex items-center justify-center ${
                        validCurrentPage === pageNum
                          ? 'bg-gray-300 text-black'
                          : 'border border-gray-300 text-gray-700 hover:bg-gray-50'
                      }`}
                    >
                      {pageNum}
                </button>
                  );
                })}
              </div>
              
              <button
                onClick={() => setCurrentPage(prev => Math.min(prev + 1, totalPages))}
                disabled={validCurrentPage === totalPages}
                className={`flex items-center gap-1 px-2 py-1 border rounded text-xs transition-colors ${
                  validCurrentPage === totalPages
                    ? 'border-gray-200 text-gray-400 cursor-not-allowed'
                    : 'border-gray-300 text-gray-700 hover:bg-gray-50'
                }`}
              >
                Next
                <ChevronRight className="w-3 h-3" />
              </button>
            </div>
          )}
        </div>
      </div>

      {/* Details Modal */}
      {isModalOpen && selectedRecord && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-lg shadow-xl max-w-7xl w-full max-h-[90vh] overflow-hidden">
            {/* Modal Header */}
            <div className="flex items-center justify-between p-6 border-b border-gray-200">
              <div className="flex items-center gap-3">
                <div className="relative">
                  <div 
                    className="w-10 h-10 rounded-full flex items-center justify-center text-white text-sm font-medium"
                    style={{ backgroundColor: generateAvatarColor(selectedRecord.employeeName.split(' ')[0] || '', selectedRecord.employeeName.split(' ')[1] || '') }}
                  >
                    {generateAvatarInitials(selectedRecord.employeeName.split(' ')[0] || '', selectedRecord.employeeName.split(' ')[1] || '')}
    </div>
                  <div 
                    className="absolute -bottom-1 -right-1 w-3 h-3 rounded-full border-2 border-white"
                    style={{ backgroundColor: getStatusDotColor(selectedRecord) }}
                  >
                  </div>
                </div>
                <div>
                  <div className="flex items-center gap-4">
                    <h2 className="text-lg font-semibold text-gray-900">{selectedRecord.employeeName}</h2>
                    <div className="flex items-center gap-2 text-sm text-gray-600">
                      <Calendar className="w-4 h-4" />
                      <span>{selectedDate ? new Date(selectedDate).toLocaleDateString('en-US', { 
                        weekday: 'long', 
                        year: 'numeric', 
                        month: 'long', 
                        day: 'numeric' 
                      }) : 'No date selected'}</span>
                    </div>
                  </div>
                  <p className="text-sm text-gray-600">{selectedRecord.role} • {selectedRecord.department}</p>
                </div>
              </div>
              <button
                onClick={closeDetailsModal}
                className="p-2 hover:bg-gray-100 rounded-full transition-colors"
                aria-label="Close modal"
              >
                <X className="w-5 h-5 text-gray-500" />
              </button>
            </div>

            {/* Modal Content */}
            <div className="overflow-y-auto max-h-[calc(90vh-120px)]">
              {/* Summary Cards */}
              <div className="p-6 pb-0">
                <div className="grid grid-cols-4 gap-4 mb-4">
                  <div className="bg-white border border-gray-200 p-3 rounded">
                    <div className="text-lg font-semibold text-gray-900">{selectedRecord.totalHours}h</div>
                    <div className="text-xs text-gray-600">Total Hours</div>
                  </div>
                  <div className="bg-white border border-gray-200 p-3 rounded">
                    <div className="text-lg font-semibold text-gray-900">{Math.round(selectedRecord.totalBreakTime / 60 * 10) / 10}h</div>
                    <div className="text-xs text-gray-600">Break Time</div>
                  </div>
                  <div className="bg-white border border-gray-200 p-3 rounded">
                    <div className="text-lg font-semibold text-gray-900">{Math.round(selectedRecord.totalTransferTime / 60 * 10) / 10}h</div>
                    <div className="text-xs text-gray-600">Transfer Time</div>
                  </div>
                  <div className="bg-white border border-gray-200 p-3 rounded">
                    <div className="flex items-center gap-2">
                      {getStatusIcon(selectedRecord)}
                      {getStatusBadge(selectedRecord)}
                    </div>
                    <div className="text-xs text-gray-600 mt-1">Current Status</div>
                  </div>
                </div>
              </div>

              {/* Tabs Navigation */}
              <div className="border-b border-gray-200 px-6">
                <nav className="flex space-x-8">
                  <button
                    onClick={() => setActiveTab('sessions')}
                    className={`py-4 px-1 border-b-2 font-medium text-sm transition-colors ${
                      activeTab === 'sessions'
                        ? 'border-primary text-primary'
                        : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
                    }`}
                  >
                    Sessions
                  </button>
                  <button
                    onClick={() => setActiveTab('comments')}
                    className={`py-4 px-1 border-b-2 font-medium text-sm transition-colors ${
                      activeTab === 'comments'
                        ? 'border-primary text-primary'
                        : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
                    }`}
                  >
                    Comments
                  </button>
                  <button
                    onClick={() => setActiveTab('log')}
                    className={`py-4 px-1 border-b-2 font-medium text-sm transition-colors ${
                      activeTab === 'log'
                        ? 'border-primary text-primary'
                        : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
                    }`}
                  >
                    Log
                  </button>
                </nav>
              </div>

              {/* Tab Content */}
              <div className="p-6">
                {activeTab === 'sessions' && (
                  <div className="space-y-6">

                    {/* Work Sessions Content */}
                    <div className="flex items-center justify-between">
                      <h3 className="text-lg font-semibold text-gray-900">Work Sessions</h3>
                      <span className="text-xs text-gray-500">
                        {organizeIntoSessions(selectedRecord).length} session{organizeIntoSessions(selectedRecord).length !== 1 ? 's' : ''}
                      </span>
                    </div>
                
                <div className="bg-white border border-gray-200 rounded-lg overflow-hidden">
                  <table className="w-full table-fixed">
                    <thead className="bg-gray-50">
                      <tr>
                        <th className="text-left py-3 px-4 font-medium text-gray-900 text-xs w-48">Session</th>
                        <th className="text-left py-3 px-4 font-medium text-gray-900 text-xs w-min">Location</th>
                        <th className="text-left py-3 px-4 font-medium text-gray-900 text-xs">Job</th>
                        <th className="text-left py-3 px-2 font-medium text-gray-900 text-xs w-24">Clock In</th>
                        <th className="text-left py-3 px-2 font-medium text-gray-900 text-xs w-24">Clock Out</th>
                        <th className="text-left py-3 px-2 font-medium text-gray-900 text-xs w-24">Total Time</th>
                        <th className="text-left py-3 px-2 font-medium text-gray-900 text-xs w-24">Overtime</th>
                        <th className="text-left py-3 px-2 font-medium text-gray-900 text-xs w-12">
                          <div className="w-4 h-4 rounded-full border border-gray-900 flex items-center justify-center">
                            <span className="text-[10px] font-medium text-gray-900">M</span>
                          </div>
                        </th>
                        <th className="text-left py-3 px-2 font-medium text-gray-900 text-xs w-12">
                          <Flag className="w-4 h-4 inline text-gray-900" />
                        </th>
                        <th className="text-left py-3 px-2 font-medium text-gray-900 text-xs w-20">Actions</th>
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-gray-200">
                      {organizeIntoSessions(selectedRecord).map((session, sessionIndex) => (
                        <tr key={session.id} className="hover:bg-gray-50 transition-colors">
                          <td className="py-2 px-4 w-48">
                            <div className="flex items-center gap-3">
                              <div className="w-8 h-8 rounded-full bg-green-100 text-status-green flex items-center justify-center text-sm font-medium border border-green-200">
                                {session.sessionNumber}
                              </div>
                              <span className="text-sm text-gray-900">Work Session {session.sessionNumber}</span>
                            </div>
                          </td>
                          <td className="py-2 px-4 w-min">
                            <span className="text-sm text-gray-900">{session.location || '--'}</span>
                          </td>
                          <td className="py-2 px-4">
                            <span className="text-sm text-gray-900">{"Hernandez's Residence"}</span>
                          </td>
                          <td className="py-2 px-2 w-24">
                            <span className="text-sm text-gray-900">{session.punches.find(p => p.type === 'in')?.timestamp || '--'}</span>
                          </td>
                          <td className="py-2 px-2 w-24">
                            <span className="text-sm text-gray-900">{session.punches.find(p => p.type === 'out')?.timestamp || '--'}</span>
                          </td>
                          <td className="py-2 px-2 w-24">
                            <span className="text-sm font-medium text-gray-900">{session.totalWorkHours?.toFixed(2) || '0.00'}h</span>
                          </td>
                          <td className="py-2 px-2 w-24">
                            {(() => {
                              const totalHours = session.totalWorkHours || 0;
                              const overtimeHours = Math.max(0, totalHours - 8);
                              return overtimeHours > 0 ? (
                                <span className="text-xs font-medium text-status-orange">
                                  {overtimeHours.toFixed(1)}h
                                </span>
                              ) : (
                                <span className="text-xs text-gray-400">--</span>
                              );
                            })()}
                          </td>
                          <td className="py-2 px-2">
                            <div className="flex items-center justify-start">
                              {renderModifiedIcon(selectedRecord, `session-${session.id}`)}
                            </div>
                          </td>
                          <td className="py-2 px-2">
                            <div className="flex items-center justify-start">
                              {renderFlagIcon(selectedRecord, `session-${session.id}`)}
                            </div>
                          </td>
                          <td className="py-2 px-2">
                            <div className="flex items-center gap-1">
                              <button className="p-1 text-gray-400 hover:text-gray-600 transition-colors">
                                <MessageSquare className="w-4 h-4" />
                              </button>
                              <button className="p-1 text-gray-400 hover:text-gray-600 transition-colors">
                                <MoreVertical className="w-4 h-4" />
                              </button>
                            </div>
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>

                    {/* Transfers */}
                    {selectedRecord.transfers.length > 0 && (
                      <div className="space-y-6">
                        <div className="flex items-center justify-between">
                          <h3 className="text-lg font-semibold text-gray-900">Transfers</h3>
                          <span className="text-xs text-gray-500">
                            {selectedRecord.transfers.length} transfer{selectedRecord.transfers.length !== 1 ? 's' : ''}
                          </span>
                        </div>
                  
                  <div className="bg-white border border-gray-200 rounded-lg overflow-hidden">
                    <table className="w-full table-fixed">
                      <thead className="bg-gray-50">
                        <tr>
                          <th className="text-left py-3 px-4 font-medium text-gray-900 text-xs w-48">Session</th>
                          <th className="text-left py-3 px-4 font-medium text-gray-900 text-xs w-min">Location A</th>
                          <th className="text-left py-3 px-4 font-medium text-gray-900 text-xs w-min">Location B</th>
                          <th className="text-left py-3 px-2 font-medium text-gray-900 text-xs w-24">Start Time</th>
                          <th className="text-left py-3 px-2 font-medium text-gray-900 text-xs w-24">End Time</th>
                          <th className="text-left py-3 px-2 font-medium text-gray-900 text-xs w-24">Total Time</th>
                          <th className="text-left py-3 px-2 font-medium text-gray-900 text-xs w-24">Overtime</th>
                          <th className="text-left py-3 px-2 font-medium text-gray-900 text-xs w-12">
                            <div className="w-4 h-4 rounded-full border border-gray-900 flex items-center justify-center">
                              <span className="text-[10px] font-medium text-gray-900">M</span>
                            </div>
                          </th>
                          <th className="text-left py-3 px-2 font-medium text-gray-900 text-xs w-12">
                            <Flag className="w-4 h-4 inline text-gray-900" />
                          </th>
                          <th className="text-left py-3 px-2 font-medium text-gray-900 text-xs w-20">Actions</th>
                        </tr>
                      </thead>
                      <tbody className="divide-y divide-gray-200">
                        {selectedRecord.transfers.map((transfer, transferIndex) => (
                          <tr key={transfer.id} className="hover:bg-gray-50 transition-colors">
                            <td className="py-2 px-4 w-48">
                              <div className="flex items-center gap-3">
                                <div className="w-8 h-8 rounded-full bg-blue-100 text-blue-700 flex items-center justify-center text-sm font-medium border border-blue-200">
                                  {transferIndex + 1}
                                </div>
                                <span className="text-sm text-gray-900">Transfer {transferIndex + 1}</span>
                              </div>
                            </td>
                            <td className="py-2 px-4 w-min">
                              <span className="text-sm text-gray-900">{transfer.fromLocation}</span>
                            </td>
                            <td className="py-2 px-4 w-min">
                              <span className="text-sm text-gray-900">{transfer.toLocation}</span>
                            </td>
                            <td className="py-2 px-2 w-24">
                              <span className="text-sm text-gray-900">{transfer.transferStart}</span>
                            </td>
                            <td className="py-2 px-2 w-24">
                              <span className="text-sm text-gray-900">{transfer.transferEnd || '--'}</span>
                            </td>
                            <td className="py-2 px-2 w-24">
                              <span className="text-sm font-medium text-gray-900">{(transfer.duration / 60).toFixed(2)}h</span>
                            </td>
                            <td className="py-2 px-2 w-24">
                              <span className="text-xs text-gray-400">--</span>
                            </td>
                            <td className="py-2 px-2">
                              <div className="flex items-center justify-start">
                                {renderModifiedIcon(selectedRecord, `transfer-${transfer.id}`)}
                              </div>
                            </td>
                            <td className="py-2 px-2">
                              <div className="flex items-center justify-start">
                                {renderFlagIcon(selectedRecord, `transfer-${transfer.id}`)}
                              </div>
                            </td>
                            <td className="py-2 px-2">
                              <div className="flex items-center gap-1">
                                <button className="p-1 text-gray-400 hover:text-gray-600 transition-colors">
                                  <MessageSquare className="w-4 h-4" />
                                </button>
                                <button className="p-1 text-gray-400 hover:text-gray-600 transition-colors">
                                  <MoreVertical className="w-4 h-4" />
                                </button>
                              </div>
                            </td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                </div>
              )}

              {/* Breaks */}
              {selectedRecord.breaks.length > 0 && (
                <div className="space-y-6">
                  <div className="flex items-center justify-between">
                    <h3 className="text-lg font-semibold text-gray-900">Breaks</h3>
                    <span className="text-xs text-gray-500">
                      {selectedRecord.breaks.length} break{selectedRecord.breaks.length !== 1 ? 's' : ''}
                    </span>
                  </div>
                  
                  <div className="bg-white border border-gray-200 rounded-lg overflow-hidden">
                    {/* Header */}
                    <div className="bg-gray-50 px-6 py-3 border-b border-gray-200">
                      <div className="grid grid-cols-12 gap-4 text-xs font-medium text-gray-900">
                        <div className="col-span-3">Break</div>
                        <div className="col-span-2">Type</div>
                        <div className="col-span-2">Start Time</div>
                        <div className="col-span-2">End Time</div>
                        <div className="col-span-2">Duration</div>
                        <div className="col-span-1">Actions</div>
                      </div>
                    </div>

                    {/* Breaks */}
                    <div className="divide-y divide-gray-200">
                      {selectedRecord.breaks.map((breakItem, breakIndex) => (
                        <div key={breakItem.id} className="px-6 py-4 hover:bg-gray-50 transition-colors">
                          <div className="grid grid-cols-12 gap-4 items-center">
                            {/* Break Number */}
                            <div className="col-span-3">
                              <div className="flex items-center gap-3">
                                <div className="w-8 h-8 rounded-full bg-orange-100 text-status-orange flex items-center justify-center text-sm font-medium border border-orange-200">
                                  {breakIndex + 1}
                                </div>
                                <span className="text-sm font-medium text-gray-900">
                                  Break {breakIndex + 1}
                                </span>
                              </div>
                            </div>

                            {/* Type */}
                            <div className="col-span-2">
                              <span className="text-sm text-gray-900 capitalize">{breakItem.breakType}</span>
                            </div>

                            {/* Start Time */}
                            <div className="col-span-2">
                              <span className="text-sm text-gray-900">{breakItem.breakStart}</span>
                            </div>

                            {/* End Time */}
                            <div className="col-span-2">
                              <span className="text-sm text-gray-900">{breakItem.breakEnd || '--'}</span>
                            </div>

                            {/* Duration */}
                            <div className="col-span-2">
                              <span className="text-sm text-gray-900">{(breakItem.duration / 60).toFixed(2)}h</span>
                            </div>

                            {/* Actions */}
                            <div className="col-span-1">
                              <div className="flex items-center gap-1">
                                <button className="p-1 text-gray-400 hover:text-gray-600 transition-colors">
                                  <Eye className="w-4 h-4" />
                                </button>
                                <button className="p-1 text-gray-400 hover:text-gray-600 transition-colors">
                                  <MoreVertical className="w-4 h-4" />
                                </button>
                              </div>
                            </div>
                          </div>
                        </div>
                      ))}
                    </div>
                  </div>
                      </div>
                    )}
                  </div>
                )}

                {activeTab === 'comments' && (
                  <div className="space-y-6">
                    <div className="flex items-center justify-between">
                      <h3 className="text-lg font-semibold text-gray-900">Comments</h3>
                      <button className="px-4 py-2 bg-primary text-white rounded-lg text-sm hover:bg-primary/90 transition-colors">
                        Add Comment
                      </button>
                    </div>
                    
                    <div className="bg-white border border-gray-200 rounded-lg p-6">
                      <div className="text-center text-gray-500 py-8">
                        <div className="w-12 h-12 mx-auto mb-4 bg-gray-100 rounded-full flex items-center justify-center">
                          <span className="text-gray-400 text-xl">💬</span>
                        </div>
                        <p className="text-sm">No comments yet</p>
                        <p className="text-xs text-gray-400 mt-1">Add comments for work sessions, breaks, or transfers</p>
                      </div>
                    </div>
                  </div>
                )}

                {activeTab === 'log' && (
                  <div className="space-y-6">
                    <div className="flex items-center justify-between">
                      <h3 className="text-lg font-semibold text-gray-900">Activity Log</h3>
                      <span className="text-xs text-gray-500">Chronological timeline</span>
                    </div>
                    
                    <div className="bg-white border border-gray-200 rounded-lg p-6">
                      <div className="space-y-4">
                        {/* Sample log entries */}
                        <div className="flex items-start gap-3 p-3 bg-blue-50 rounded-lg">
                          <div className="w-2 h-2 bg-blue-500 rounded-full mt-2"></div>
                          <div className="flex-1">
                            <div className="text-sm font-medium text-gray-900">First clock-in</div>
                            <div className="text-xs text-gray-600">08:30 AM • Main Office • Device: iPhone 14 • GPS: 40.7128, -74.0060</div>
                            <div className="text-xs text-gray-500 mt-1">User: john.smith@company.com</div>
                          </div>
                        </div>
                        
                        <div className="flex items-start gap-3 p-3 bg-orange-50 rounded-lg">
                          <div className="w-2 h-2 bg-status-orange rounded-full mt-2"></div>
                          <div className="flex-1">
                            <div className="text-sm font-medium text-gray-900">Break started</div>
                            <div className="text-xs text-gray-600">10:15 AM • Lunch break • Duration: 30 min</div>
                            <div className="text-xs text-gray-500 mt-1">Auto-detected break</div>
                          </div>
                        </div>
                        
                        <div className="flex items-start gap-3 p-3 bg-green-50 rounded-lg">
                          <div className="w-2 h-2 bg-green-500 rounded-full mt-2"></div>
                          <div className="flex-1">
                            <div className="text-sm font-medium text-gray-900">Break ended</div>
                            <div className="text-xs text-gray-600">10:45 AM • Returned to work</div>
                            <div className="text-xs text-gray-500 mt-1">Auto-detected return</div>
                          </div>
                        </div>
                        
                        <div className="flex items-start gap-3 p-3 bg-indigo-50 rounded-lg">
                          <div className="w-2 h-2 bg-indigo-500 rounded-full mt-2"></div>
                          <div className="flex-1">
                            <div className="text-sm font-medium text-gray-900">Transfer initiated</div>
                            <div className="text-xs text-gray-600">12:00 PM • From: Main Office • To: Branch A</div>
                            <div className="text-xs text-gray-500 mt-1">Approved by: manager@company.com</div>
                          </div>
                        </div>
                        
                        <div className="flex items-start gap-3 p-3 bg-gray-50 rounded-lg">
                          <div className="w-2 h-2 bg-gray-500 rounded-full mt-2"></div>
                          <div className="flex-1">
                            <div className="text-sm font-medium text-gray-900">Clock-out</div>
                            <div className="text-xs text-gray-600">17:00 PM • Branch A • Total hours: 8.5h</div>
                            <div className="text-xs text-gray-500 mt-1">End of workday</div>
                          </div>
                        </div>
                      </div>
                    </div>
                  </div>
                )}
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
