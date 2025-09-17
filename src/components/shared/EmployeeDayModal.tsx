import React, { useState, useEffect, useRef } from 'react';
import { 
  X, 
  Calendar, 
  MessageSquare, 
  Send, 
  ChevronDown,
  Flag,
  MoreVertical
} from 'lucide-react';

// Types
interface AttendanceRecord {
  id: string;
  employeeName: string;
  role: string;
  department: string;
  totalHours: number;
  totalBreakTime: number;
  totalTransferTime: number;
  punches: Array<{
    id: string;
    type: 'in' | 'out';
    timestamp: string;
    location?: string;
  }>;
  transfers: Array<{
    id: string;
    fromLocation: string;
    toLocation: string;
    startTime: string;
    endTime?: string;
    duration: number;
  }>;
  breaks: Array<{
    id: string;
    breakType: 'coffee' | 'lunch';
    startTime: string;
    endTime?: string;
    duration: number;
  }>;
}

interface Comment {
  id: string;
  author: string;
  text: string;
  timestamp: string;
  context?: string;
  replies?: Array<{
    id: string;
    author: string;
    text: string;
    timestamp: string;
  }>;
}

interface ActivityLogEntry {
  id: string;
  description: string;
  details: string;
  timestamp: string;
  userId: string;
  userName?: string;
  userInitials?: string;
}

interface EmployeeDayModalProps {
  isOpen: boolean;
  onClose: () => void;
  selectedRecord: AttendanceRecord | null;
  selectedDate: string | null;
  // Optional props for customization
  onAddComment?: (recordId: string, comment: string, sessionId?: string, eventId?: string) => void;
  onAddReply?: (commentId: string, reply: string) => void;
  getCommentsForRecord?: (recordId: string) => Comment[];
  getActivityLogForRecord?: (recordId: string) => ActivityLogEntry[];
  // Helper functions
  generateAvatarColor?: (firstName: string, lastName: string) => string;
  generateAvatarInitials?: (firstName: string, lastName: string) => string;
  getDotSize?: (size: 'sm' | 'md' | 'lg') => string;
  getStatusDotColor?: (record: AttendanceRecord) => string;
  organizeIntoSessions?: (record: AttendanceRecord) => any[];
  renderModifiedIcon?: (record: AttendanceRecord, context: string) => React.ReactNode;
  renderFlagIcon?: (record: AttendanceRecord, context: string) => React.ReactNode;
  getOvertimeHours?: (totalHours: number) => number;
}

const EmployeeDayModal: React.FC<EmployeeDayModalProps> = ({
  isOpen,
  onClose,
  selectedRecord,
  selectedDate,
  onAddComment,
  onAddReply,
  getCommentsForRecord = () => [],
  getActivityLogForRecord = () => [],
  generateAvatarColor = () => '#6B7280',
  generateAvatarInitials = (firstName, lastName) => `${firstName.charAt(0)}${lastName.charAt(0)}`.toUpperCase(),
  getDotSize = () => 'w-3 h-3',
  getStatusDotColor = () => '#6B7280',
  organizeIntoSessions = () => [],
  renderModifiedIcon = () => null,
  renderFlagIcon = () => null,
  getOvertimeHours = (totalHours) => Math.max(0, totalHours - 8)
}) => {
  // State
  const [activeTab, setActiveTab] = useState<'sessions' | 'comments' | 'log'>('sessions');
  const [newCommentText, setNewCommentText] = useState('');
  const [replyText, setReplyText] = useState('');
  const [replyingTo, setReplyingTo] = useState<string | null>(null);
  const [selectedSession, setSelectedSession] = useState<string>('');
  const [selectedEvent, setSelectedEvent] = useState<string>('');
  const [showSessionDropdown, setShowSessionDropdown] = useState(false);
  const [showEventDropdown, setShowEventDropdown] = useState(false);
  
  const commentInputRef = useRef<HTMLInputElement>(null);

  // Prevent body scroll when modal is open
  useEffect(() => {
    if (isOpen) {
      document.body.style.overflow = 'hidden';
    } else {
      document.body.style.overflow = 'unset';
    }

    return () => {
      document.body.style.overflow = 'unset';
    };
  }, [isOpen]);

  // Reset state when modal opens
  useEffect(() => {
    if (isOpen) {
      setActiveTab('sessions');
      setNewCommentText('');
      setReplyText('');
      setReplyingTo(null);
      setSelectedSession('');
      setSelectedEvent('');
    }
  }, [isOpen]);

  // Helper functions
  const getContextLabel = (comment: Comment) => {
    if (comment.context) {
      return comment.context;
    }
    return 'General';
  };

  const getSessionOptions = () => {
    if (!selectedRecord) return [];
    const sessions = organizeIntoSessions(selectedRecord);
    return sessions.map((session, index) => ({
      value: session.id,
      label: `Work Session ${session.sessionNumber}`
    }));
  };

  const getEventOptions = () => {
    return [
      { value: 'clock-in', label: 'Clock In' },
      { value: 'clock-out', label: 'Clock Out' },
      { value: 'break-start', label: 'Break Start' },
      { value: 'break-end', label: 'Break End' },
      { value: 'transfer-start', label: 'Transfer Start' },
      { value: 'transfer-end', label: 'Transfer End' }
    ];
  };

  const handleReply = (commentId: string) => {
    setReplyingTo(commentId);
    setReplyText('');
  };

  const handleCancelReply = () => {
    setReplyingTo(null);
    setReplyText('');
  };

  const handleSaveReply = () => {
    if (replyText.trim() && replyingTo && onAddReply) {
      onAddReply(replyingTo, replyText);
      setReplyText('');
      setReplyingTo(null);
    }
  };

  const handleSaveNewComment = () => {
    if (newCommentText.trim() && selectedRecord && onAddComment) {
      onAddComment(selectedRecord.id, newCommentText, selectedSession, selectedEvent);
      setNewCommentText('');
      setSelectedSession('');
      setSelectedEvent('');
    }
  };

  if (!isOpen || !selectedRecord) {
    return null;
  }

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
      <div className="relative bg-white rounded-lg shadow-xl max-w-7xl w-full h-[85vh] overflow-hidden">
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
                className={`absolute -bottom-1 -right-1 ${getDotSize('md')} rounded-full border-2 border-white`}
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
          
          <div className="flex items-center gap-6">
            {/* Tabs Navigation */}
            <div className="flex space-x-6">
              <button
                onClick={() => setActiveTab('sessions')}
                className={`py-2 px-1 border-b-2 font-medium text-sm transition-colors ${
                  activeTab === 'sessions'
                    ? 'border-primary text-primary'
                    : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
                }`}
              >
                Sessions
              </button>
              <button
                onClick={() => setActiveTab('comments')}
                className={`py-2 px-1 border-b-2 font-medium text-sm transition-colors ${
                  activeTab === 'comments'
                    ? 'border-primary text-primary'
                    : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
                }`}
              >
                Comments
              </button>
              <button
                onClick={() => setActiveTab('log')}
                className={`py-2 px-1 border-b-2 font-medium text-sm transition-colors ${
                  activeTab === 'log'
                    ? 'border-primary text-primary'
                    : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
                }`}
              >
                Log
              </button>
            </div>
            
            <button
              onClick={onClose}
              className="p-2 hover:bg-gray-100 rounded-full transition-colors"
              aria-label="Close modal"
            >
              <X className="w-5 h-5 text-gray-500" />
            </button>
          </div>
        </div>

        {/* Modal Content */}
        <div className="relative flex flex-col h-[calc(85vh-120px)]">
          {/* Tab Content */}
          <div className={`overflow-y-auto p-6 ${activeTab === 'comments' || activeTab === 'sessions' ? 'pb-0 h-[calc(100%-88px)] flex flex-col' : 'flex-1'}`} style={{ paddingRight: activeTab === 'sessions' ? '26px' : '24px' }}>
            {activeTab === 'sessions' && (
              <div className="flex flex-col h-full">
                {/* Work Sessions Content */}
                <div className="flex-1 overflow-y-auto min-h-0 pb-8" style={{ scrollbarGutter: 'stable' }}>
                  {/* Header */}
                  <div className="flex items-center justify-between mb-3">
                    <h3 className="text-lg font-semibold text-gray-900">Work Sessions</h3>
                    <div className="flex items-center gap-4 text-xs text-gray-500">
                      <span>
                        {(() => {
                          const sessions = organizeIntoSessions(selectedRecord);
                          return `${sessions.length} session${sessions.length !== 1 ? 's' : ''}`;
                        })()}
                      </span>
                      <span className="text-gray-900 font-medium">
                        Total Time: {selectedRecord.totalHours}h
                      </span>
                    </div>
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
                            <td className="py-2 px-2 w-12">
                              <div className="flex items-center justify-start">
                                {renderModifiedIcon(selectedRecord, `session-${session.id}`)}
                              </div>
                            </td>
                            <td className="py-2 px-2 w-12">
                              <div className="flex items-center justify-start">
                                {renderFlagIcon(selectedRecord, `session-${session.id}`)}
                              </div>
                            </td>
                            <td className="py-2 px-2 w-20">
                              <div className="flex items-center gap-1">
                                <button 
                                  className="p-1 text-gray-400 hover:text-gray-600 transition-colors"
                                  title="Add comment"
                                >
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
                    <div className="mt-8">
                      <div className="flex items-center justify-between mb-3">
                        <h3 className="text-lg font-semibold text-gray-900">Transfers</h3>
                        <div className="flex items-center gap-4 text-xs text-gray-500">
                          <span>
                            {selectedRecord.transfers.length} transfer{selectedRecord.transfers.length !== 1 ? 's' : ''}
                          </span>
                          <span className="text-gray-900 font-medium">
                            Total Time: {(() => {
                              const totalTransferTime = selectedRecord.transfers.reduce((sum, transfer) => sum + (transfer.duration / 60), 0);
                              return totalTransferTime.toFixed(2);
                            })()}h
                          </span>
                        </div>
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
                              <th className="text-left py-3 px-2 font-medium text-gray-900 text-xs w-24"></th>
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
                                  <span className="text-sm text-gray-900">{transfer.startTime}</span>
                                </td>
                                <td className="py-2 px-2 w-24">
                                  <span className="text-sm text-gray-900">{transfer.endTime || '--'}</span>
                                </td>
                                <td className="py-2 px-2 w-24">
                                  <span className="text-sm font-medium text-gray-900">{(transfer.duration / 60).toFixed(2)}h</span>
                                </td>
                                <td className="py-2 px-2 w-24">
                                  {/* Empty column for alignment */}
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
                    <div className="mt-8">
                      <div className="flex items-center justify-between mb-3">
                        <h3 className="text-lg font-semibold text-gray-900">Breaks</h3>
                        <div className="flex items-center gap-4 text-xs text-gray-500">
                          <span>
                            {selectedRecord.breaks.length} break{selectedRecord.breaks.length !== 1 ? 's' : ''}
                          </span>
                          <span className="text-gray-900 font-medium">
                            Total Time: {(() => {
                              const totalBreakTime = selectedRecord.breaks.reduce((sum, breakItem) => sum + (breakItem.duration / 60), 0);
                              return totalBreakTime.toFixed(2);
                            })()}h
                          </span>
                        </div>
                      </div>
                      
                      <div className="bg-white border border-gray-200 rounded-lg overflow-hidden">
                        <table className="w-full table-fixed">
                          <thead className="bg-gray-50">
                            <tr>
                              <th className="text-left py-3 px-4 font-medium text-gray-900 text-xs w-48">Session</th>
                              <th className="text-left py-3 px-4 font-medium text-gray-900 text-xs">Type</th>
                              <th className="text-left py-3 px-4 font-medium text-gray-900 text-xs">Description</th>
                              <th className="text-left py-3 px-2 font-medium text-gray-900 text-xs w-24">Start Time</th>
                              <th className="text-left py-3 px-2 font-medium text-gray-900 text-xs w-24">End Time</th>
                              <th className="text-left py-3 px-2 font-medium text-gray-900 text-xs w-24">Total Time</th>
                              <th className="text-left py-3 px-2 font-medium text-gray-900 text-xs w-24"></th>
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
                            {selectedRecord.breaks.map((breakItem, breakIndex) => (
                              <tr key={breakItem.id} className="hover:bg-gray-50 transition-colors">
                                <td className="py-2 px-4 w-48">
                                  <div className="flex items-center gap-3">
                                    <div className="w-8 h-8 rounded-full bg-orange-100 text-status-orange flex items-center justify-center text-sm font-medium border border-orange-200">
                                      {breakIndex + 1}
                                    </div>
                                    <span className="text-sm text-gray-900">Break {breakIndex + 1}</span>
                                  </div>
                                </td>
                                <td className="py-2 px-4">
                                  <span className="text-sm text-gray-900">
                                    {breakItem.breakType === 'coffee' ? 'Paid' : 'Non Paid'}
                                  </span>
                                </td>
                                <td className="py-2 px-4">
                                  <span className="text-sm text-gray-900 capitalize">
                                    {breakItem.breakType === 'coffee' ? 'Coffee' : 'Lunch'}
                                  </span>
                                </td>
                                <td className="py-2 px-2 w-24">
                                  <span className="text-sm text-gray-900">{breakItem.startTime}</span>
                                </td>
                                <td className="py-2 px-2 w-24">
                                  <span className="text-sm text-gray-900">{breakItem.endTime || '--'}</span>
                                </td>
                                <td className="py-2 px-2 w-24">
                                  <span className="text-sm font-medium text-gray-900">{(breakItem.duration / 60).toFixed(2)}h</span>
                                </td>
                                <td className="py-2 px-2 w-24">
                                  {/* Empty column for alignment */}
                                </td>
                                <td className="py-2 px-2 w-12">
                                  <div className="flex items-center justify-start">
                                    {renderModifiedIcon(selectedRecord, `break-${breakItem.id}`)}
                                  </div>
                                </td>
                                <td className="py-2 px-2 w-12">
                                  <div className="flex items-center justify-start">
                                    {renderFlagIcon(selectedRecord, `break-${breakItem.id}`)}
                                  </div>
                                </td>
                                <td className="py-2 px-2 w-20">
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
                </div>
              </div>
            )}

            {activeTab === 'comments' && (
              <div className="flex flex-col h-full">
                {/* Header */}
                <div className="flex items-center justify-between mb-6">
                  <h3 className="text-lg font-semibold text-gray-900">Comments</h3>
                </div>
                
                {/* Comments Thread - Direct display without border */}
                <div className="flex-1 overflow-y-auto min-h-0 pb-8">
                  {selectedRecord && getCommentsForRecord(selectedRecord.id).length > 0 ? (
                    <div className="space-y-6 ml-4">
                      {getCommentsForRecord(selectedRecord.id).map((comment) => (
                        <div key={comment.id} className="border-b border-gray-100 pb-6 last:border-b-0">
                          {/* Main Comment */}
                          <div className="flex items-start gap-3">
                            <div className="w-8 h-8 bg-primary rounded-full flex items-center justify-center text-white text-sm font-medium">
                              {comment.author.charAt(0)}
                            </div>
                            <div className="flex-1">
                              <div className="flex items-center gap-2 mb-2">
                                <span className="text-sm font-medium text-gray-900">
                                  {comment.author}
                                </span>
                                <span className="text-xs text-gray-500">
                                  {new Date(comment.timestamp).toLocaleString()}
                                </span>
                                <span className="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
                                  {getContextLabel(comment)}
                                </span>
                              </div>
                              <p className="text-sm text-gray-700 mb-3">{comment.text}</p>
                              
                              {/* Reply Button */}
                              <button
                                onClick={() => handleReply(comment.id)}
                                className="text-xs text-gray-500 hover:text-gray-700 transition-colors"
                              >
                                Reply
                              </button>
                              
                              {/* Replies */}
                              {comment.replies && comment.replies.length > 0 && (
                                <div className="mt-4 ml-4 border-l-2 border-gray-200 pl-4 space-y-4">
                                  {comment.replies.map((reply) => (
                                    <div key={reply.id} className="flex items-start gap-3">
                                      <div className="w-6 h-6 bg-gray-400 rounded-full flex items-center justify-center text-white text-xs font-medium">
                                        {reply.author.charAt(0)}
                                      </div>
                                      <div className="flex-1">
                                        <div className="flex items-center gap-2 mb-1">
                                          <span className="text-xs font-medium text-gray-900">
                                            {reply.author}
                                          </span>
                                          <span className="text-xs text-gray-500">
                                            {new Date(reply.timestamp).toLocaleString()}
                                          </span>
                                        </div>
                                        <p className="text-xs text-gray-700">{reply.text}</p>
                                      </div>
                                    </div>
                                  ))}
                                </div>
                              )}
                            </div>
                          </div>
                        </div>
                      ))}
                    </div>
                  ) : (
                    <div className="text-center text-gray-500 py-8">
                      <MessageSquare className="mx-auto h-8 w-8 text-gray-400 mb-4" />
                      <p className="text-sm">No comments yet</p>
                      <p className="text-xs text-gray-400 mt-1">Start a conversation below</p>
                    </div>
                  )}
                </div>

                {/* Reply Input - Fixed at Bottom */}
                {replyingTo && (
                  <div className="bg-gray-50 border border-gray-200 rounded-lg p-4 mb-4">
                    <div className="text-xs text-gray-600 mb-2">
                      Replying to: <span className="font-medium">{getCommentsForRecord(selectedRecord?.id || '').find(c => c.id === replyingTo)?.author}</span>
                    </div>
                    <div className="flex items-end gap-3">
                      <div className="flex-1">
                        <textarea
                          value={replyText}
                          onChange={(e) => setReplyText(e.target.value)}
                          placeholder="Write a reply..."
                          rows={2}
                          className="w-full px-3 py-2 border border-gray-300 rounded-md text-sm focus:outline-none focus:ring-2 focus:ring-primary focus:border-transparent resize-none"
                        />
                      </div>
                      <div className="flex gap-2">
                        <button
                          onClick={handleCancelReply}
                          className="px-2 py-1 bg-gray-200 text-gray-700 rounded text-xs hover:bg-gray-300 transition-colors"
                        >
                          Cancel
                        </button>
                        <button
                          onClick={handleSaveReply}
                          disabled={!replyText.trim()}
                          className="px-2 py-1 bg-primary text-white rounded text-xs hover:bg-primary/90 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
                        >
                          Reply
                        </button>
                      </div>
                    </div>
                  </div>
                )}
              </div>
            )}

            {activeTab === 'log' && (
              <div className="flex flex-col h-full">
                {/* Header */}
                <div className="flex items-center justify-between mb-6">
                  <h3 className="text-lg font-semibold text-gray-900">Activity Log</h3>
                </div>
                
                {/* Activity Log Thread - Direct display without border */}
                <div className="flex-1 overflow-y-auto min-h-0">
                  {selectedRecord && getActivityLogForRecord(selectedRecord.id).length > 0 ? (
                    <div className="space-y-6 ml-4">
                      {getActivityLogForRecord(selectedRecord.id).map((logEntry) => (
                        <div key={logEntry.id} className="border-b border-gray-100 pb-6 last:border-b-0">
                          {/* Log Entry */}
                          <div className="flex items-start gap-3">
                            <div className={`w-8 h-8 rounded-full flex items-center justify-center text-sm font-medium ${
                              logEntry.userId === 'system' 
                                ? 'bg-gray-300 text-black' 
                                : 'bg-primary text-white'
                            }`}>
                              {logEntry.userInitials || 'U'}
                            </div>
                            <div className="flex-1">
                              <div className="flex items-center gap-2 mb-2">
                                <span className="text-sm font-medium text-gray-900">
                                  {logEntry.description}
                                </span>
                                <span className="text-xs text-gray-500">
                                  {new Date(logEntry.timestamp).toLocaleString()}
                                </span>
                              </div>
                              <p className="text-sm text-gray-700">{logEntry.details}</p>
                              {logEntry.userName && (
                                <p className="text-xs text-gray-500 mt-1">
                                  by {logEntry.userName}
                                </p>
                              )}
                            </div>
                          </div>
                        </div>
                      ))}
                    </div>
                  ) : (
                    <div className="flex flex-col items-center justify-center h-full text-gray-500 ml-4">
                      <MessageSquare className="w-12 h-12 mb-4 text-gray-300" />
                      <p className="text-sm">No activity logged yet</p>
                      <p className="text-xs text-gray-400 mt-1">Activity will appear here as it happens</p>
                    </div>
                  )}
                </div>
              </div>
            )}
          </div>

          {/* Summary Cards Footer for Sessions */}
          {activeTab === 'sessions' && (
            <div className="absolute bottom-0 left-0 right-0 border-t border-gray-200 px-6 pt-6 pb-6" style={{ backgroundColor: 'var(--gray-200)' }}>
              <div className="grid grid-cols-4 gap-4">
                <div className="bg-white border border-gray-200 p-2.5 rounded">
                  <div className="text-lg font-semibold text-gray-900">{selectedRecord.totalHours}h</div>
                  <div className="text-xs text-gray-600">Total Hours</div>
                </div>
                <div className="bg-white border border-gray-200 p-2.5 rounded">
                  <div className="text-lg font-semibold text-gray-900">{Math.round(selectedRecord.totalBreakTime / 60 * 10) / 10}h</div>
                  <div className="text-xs text-gray-600">Break Time</div>
                </div>
                <div className="bg-white border border-gray-200 p-2.5 rounded">
                  <div className="text-lg font-semibold text-gray-900">{Math.round(selectedRecord.totalTransferTime / 60 * 10) / 10}h</div>
                  <div className="text-xs text-gray-600">Transfer Time</div>
                </div>
                <div className="bg-white border border-gray-200 p-2.5 rounded">
                  <div className="text-lg font-semibold text-gray-900">
                    {getOvertimeHours(selectedRecord.totalHours) > 0 ? `${getOvertimeHours(selectedRecord.totalHours).toFixed(1)}h` : '0h'}
                  </div>
                  <div className="text-xs text-gray-600">Overtime</div>
                </div>
              </div>
            </div>
          )}

          {/* Summary Cards Footer for Comments */}
          {activeTab === 'comments' && (
            <div className="absolute bottom-0 left-0 right-0 border-t border-gray-200 px-6 pt-6 pb-6" style={{ backgroundColor: 'var(--gray-200)' }}>
              <div className="bg-white border border-gray-200 rounded-lg p-4 w-full">
                <div className="flex items-center gap-3">
                  <div className="w-8 h-8 bg-primary rounded-full flex items-center justify-center text-white text-sm font-medium">
                    JR
                  </div>
                  <div className="flex-1">
                    <input
                      ref={commentInputRef}
                      type="text"
                      value={newCommentText}
                      onChange={(e) => setNewCommentText(e.target.value)}
                      placeholder="Reply in thread"
                      className="w-full h-8 px-3 border border-gray-300 rounded-md text-sm focus:outline-none focus:ring-2 focus:ring-primary focus:border-transparent"
                    />
                  </div>
                  <div className="flex items-center gap-2">
                    {/* Session Selector */}
                    <div className="relative dropdown-container">
                      <button
                        type="button"
                        onClick={() => {
                          setShowSessionDropdown(!showSessionDropdown);
                          setShowEventDropdown(false);
                        }}
                        className="w-48 h-8 appearance-none bg-white border border-gray-300 rounded-md px-3 text-sm focus:outline-none focus:ring-2 focus:ring-primary focus:border-transparent text-left flex items-center justify-between"
                        title="Select session"
                      >
                        <span className={selectedSession ? 'text-gray-900' : 'text-gray-500'}>
                          {selectedSession ? getSessionOptions().find(opt => opt.value === selectedSession)?.label || 'Session' : 'Session'}
                        </span>
                        <ChevronDown className={`w-4 h-4 text-gray-400 transition-transform ${showSessionDropdown ? 'rotate-180' : ''}`} />
                      </button>
                      
                      {showSessionDropdown && (
                        <div className="absolute z-10 w-full mt-1 bg-white border border-gray-200 rounded-md shadow-lg">
                          <div
                            className="px-3 py-2 text-sm text-gray-500 hover:bg-gray-50 cursor-pointer"
                            onClick={() => {
                              setSelectedSession('');
                              setShowSessionDropdown(false);
                            }}
                          >
                            Session
                          </div>
                          {getSessionOptions().map((option) => (
                            <div
                              key={option.value}
                              className="px-3 py-2 text-sm text-gray-900 hover:bg-gray-50 cursor-pointer"
                              onClick={() => {
                                setSelectedSession(option.value);
                                setShowSessionDropdown(false);
                              }}
                            >
                              {option.label}
                            </div>
                          ))}
                        </div>
                      )}
                    </div>
                    
                    {/* Event Selector */}
                    <div className="relative dropdown-container">
                      <button
                        type="button"
                        onClick={() => {
                          setShowEventDropdown(!showEventDropdown);
                          setShowSessionDropdown(false);
                        }}
                        className="w-32 h-8 appearance-none bg-white border border-gray-300 rounded-md px-3 text-sm focus:outline-none focus:ring-2 focus:ring-primary focus:border-transparent text-left flex items-center justify-between"
                        title="Select event"
                      >
                        <span className={selectedEvent ? 'text-gray-900' : 'text-gray-500'}>
                          {selectedEvent ? getEventOptions().find(opt => opt.value === selectedEvent)?.label || 'Event' : 'Event'}
                        </span>
                        <ChevronDown className={`w-4 h-4 text-gray-400 transition-transform ${showEventDropdown ? 'rotate-180' : ''}`} />
                      </button>
                      
                      {showEventDropdown && (
                        <div className="absolute z-10 w-full mt-1 bg-white border border-gray-200 rounded-md shadow-lg">
                          <div
                            className="px-3 py-2 text-sm text-gray-500 hover:bg-gray-50 cursor-pointer"
                            onClick={() => {
                              setSelectedEvent('');
                              setShowEventDropdown(false);
                            }}
                          >
                            Event
                          </div>
                          {getEventOptions().map((option) => (
                            <div
                              key={option.value}
                              className="px-3 py-2 text-sm text-gray-900 hover:bg-gray-50 cursor-pointer"
                              onClick={() => {
                                setSelectedEvent(option.value);
                                setShowEventDropdown(false);
                              }}
                            >
                              {option.label}
                            </div>
                          ))}
                        </div>
                      )}
                    </div>
                    
                    {/* Send Button */}
                    <button
                      onClick={handleSaveNewComment}
                      disabled={!newCommentText.trim()}
                      className="flex items-center gap-2 h-8 px-2 rounded text-white transition-colors text-sm disabled:opacity-50 disabled:cursor-not-allowed"
                      style={{ backgroundColor: 'var(--teal-brand-hex)' }}
                      title="Send message"
                    >
                      <Send className="w-4 h-4" />
                      Send
                    </button>
                  </div>
                </div>
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
};

export default EmployeeDayModal;
