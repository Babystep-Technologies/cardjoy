import React, { useState } from 'react';
import { Card } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import {
  Users,
  Mail,
  MessageSquare,
  UserPlus,
  ChevronDown,
  ChevronUp,
  Download,
} from 'lucide-react';

interface Rsvp {
  id: string;
  guestName: string;
  guestEmail: string;
  status: string;
  plusOne: boolean;
  additionalGuestsCount?: number;
  plusOneName?: string | null;
  message?: string | null;
  createdAt: string;
}

interface RsvpCounts {
  going: number;
  maybe: number;
  notGoing: number;
  total: number;
  totalAttendees: number;
}

interface RSVPManagementProps {
  rsvps: Rsvp[];
  rsvpCounts: RsvpCounts;
  invitationTitle: string;
}

const RSVPManagement: React.FC<RSVPManagementProps> = ({ rsvps, rsvpCounts, invitationTitle }) => {
  const [expandedSection, setExpandedSection] = useState<string | null>('going');

  const goingRsvps = rsvps.filter(r => r.status === 'going');
  const maybeRsvps = rsvps.filter(r => r.status === 'maybe');
  const notGoingRsvps = rsvps.filter(r => r.status === 'not-going');

  const exportToCSV = () => {
    const headers = [
      'Name',
      'Email',
      'Status',
      'Additional Guests',
      'Guest Names',
      'Message',
      'Date',
    ];
    const rows = rsvps.map(rsvp => [
      rsvp.guestName,
      rsvp.guestEmail,
      rsvp.status,
      rsvp.additionalGuestsCount || 0,
      rsvp.plusOneName || '',
      rsvp.message?.replace(/"/g, '""') || '',
      new Date(rsvp.createdAt).toLocaleDateString(),
    ]);

    const csvContent = [
      headers.join(','),
      ...rows.map(row => row.map(cell => `"${cell}"`).join(',')),
    ].join('\n');

    const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = `${invitationTitle.replace(/[^a-z0-9]/gi, '_')}_RSVPs.csv`;
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    URL.revokeObjectURL(url);
  };

  const RsvpCard = ({ rsvp }: { rsvp: Rsvp }) => (
    <div className="bg-white p-4 rounded-xl border-2 border-gray-100 hover:border-gray-200 transition-colors">
      <div className="flex items-start justify-between">
        <div className="flex-1">
          <div className="font-semibold text-lg">{rsvp.guestName}</div>
          <div className="flex items-center gap-1 text-sm text-gray-600 mt-1">
            <Mail className="w-3 h-3" />
            <a href={`mailto:${rsvp.guestEmail}`} className="hover:underline">
              {rsvp.guestEmail}
            </a>
          </div>
          {(rsvp.additionalGuestsCount || 0) > 0 && (
            <div className="flex items-center gap-1 text-sm text-purple-600 mt-2">
              <UserPlus className="w-3 h-3" />
              <span>
                +{rsvp.additionalGuestsCount}
                {rsvp.plusOneName && `: ${rsvp.plusOneName}`}
              </span>
            </div>
          )}
          {rsvp.message && (
            <div className="mt-3 p-3 bg-gray-50 rounded-lg">
              <div className="flex items-center gap-1 text-xs text-gray-500 mb-1">
                <MessageSquare className="w-3 h-3" />
                Message
              </div>
              <p className="text-sm text-gray-700 italic">"{rsvp.message}"</p>
            </div>
          )}
        </div>
        <div className="text-xs text-gray-400">{new Date(rsvp.createdAt).toLocaleDateString()}</div>
      </div>
    </div>
  );

  const Section = ({
    title,
    count,
    rsvpList,
    sectionKey,
    dotColor,
  }: {
    title: string;
    count: number;
    rsvpList: Rsvp[];
    sectionKey: string;
    dotColor: string;
  }) => {
    const isExpanded = expandedSection === sectionKey;

    return (
      <div className="rounded-lg border border-gray-200 overflow-hidden">
        <button
          onClick={() => setExpandedSection(isExpanded ? null : sectionKey)}
          className="w-full bg-gray-50 hover:bg-gray-100 p-4 flex items-center justify-between transition-colors"
        >
          <div className="flex items-center gap-3">
            <span className={`w-2.5 h-2.5 rounded-full ${dotColor}`}></span>
            <span className="font-medium text-gray-700">{title}</span>
            <span className="text-lg font-semibold text-gray-900">{count}</span>
          </div>
          {isExpanded ? (
            <ChevronUp className="w-5 h-5 text-gray-400" />
          ) : (
            <ChevronDown className="w-5 h-5 text-gray-400" />
          )}
        </button>

        {isExpanded && (
          <div className="p-4 space-y-3 bg-white border-t border-gray-100">
            {rsvpList.length > 0 ? (
              rsvpList.map(rsvp => <RsvpCard key={rsvp.id} rsvp={rsvp} />)
            ) : (
              <p className="text-gray-500 text-center py-4">No responses yet</p>
            )}
          </div>
        )}
      </div>
    );
  };

  return (
    <Card className="shadow-lg border border-gray-200 bg-white overflow-hidden">
      <div className="border-b border-gray-100 p-5">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2">
            <Users className="w-5 h-5 text-gray-600" />
            <h2 className="text-xl font-semibold text-gray-800">Guest Responses</h2>
          </div>
          {rsvps.length > 0 && (
            <Button variant="outline" size="sm" onClick={exportToCSV} className="gap-2 text-sm">
              <Download className="w-4 h-4" />
              Export
            </Button>
          )}
        </div>

        {/* Summary Stats */}
        <div className="grid grid-cols-2 sm:grid-cols-4 gap-3 mt-5">
          <div className="text-center p-3 bg-gray-50 rounded-lg">
            <div className="text-2xl font-bold text-gray-900">{rsvpCounts.going}</div>
            <div className="text-xs text-gray-500 font-medium mt-1">Going</div>
          </div>
          <div className="text-center p-3 bg-gray-50 rounded-lg">
            <div className="text-2xl font-bold text-gray-900">{rsvpCounts.maybe}</div>
            <div className="text-xs text-gray-500 font-medium mt-1">Maybe</div>
          </div>
          <div className="text-center p-3 bg-gray-50 rounded-lg">
            <div className="text-2xl font-bold text-gray-900">{rsvpCounts.notGoing}</div>
            <div className="text-xs text-gray-500 font-medium mt-1">Can't go</div>
          </div>
          <div className="text-center p-3 bg-gray-50 rounded-lg">
            <div className="text-2xl font-bold text-gray-900">{rsvpCounts.totalAttendees}</div>
            <div className="text-xs text-gray-500 font-medium mt-1">Total guests</div>
          </div>
        </div>
      </div>

      {/* RSVP Lists */}
      <div className="p-5 space-y-3">
        <Section
          title="Going"
          count={goingRsvps.length}
          rsvpList={goingRsvps}
          sectionKey="going"
          dotColor="bg-green-500"
        />

        <Section
          title="Maybe"
          count={maybeRsvps.length}
          rsvpList={maybeRsvps}
          sectionKey="maybe"
          dotColor="bg-amber-500"
        />

        <Section
          title="Can't go"
          count={notGoingRsvps.length}
          rsvpList={notGoingRsvps}
          sectionKey="not-going"
          dotColor="bg-gray-400"
        />
      </div>
    </Card>
  );
};

export default RSVPManagement;
