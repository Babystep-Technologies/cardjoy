import { gql, useQuery } from '@apollo/client';
import { useState, useEffect } from 'react';
import { Card, CardHeader, CardTitle, CardContent } from '@/components/ui/card';
import { Skeleton } from '@/components/ui/skeleton';
import TrendChart from '@/components/TrendChart';
import AnnualGoalsCard from '@/components/AnnualGoalsCard';
import EditAnnualGoalsDialog from '@/components/EditAnnualGoalsDialog';
import withAuth from '@/lib/with-auth';

const BUSINESS_METRICS_QUERY = gql`
  query BusinessMetrics {
    businessMetrics {
      usersLast1Day
      usersLast7Days
      usersLast30Days
      usersLast90Days
      usersLast180Days
      cardsLast1Day
      cardsLast7Days
      cardsLast30Days
      cardsLast90Days
      cardsLast180Days
      invitationsLast1Day
      invitationsLast7Days
      invitationsLast30Days
      invitationsLast90Days
      invitationsLast180Days
      rsvpsLast1Day
      rsvpsLast7Days
      rsvpsLast30Days
      rsvpsLast90Days
      rsvpsLast180Days
      rsvpsGoingLast30Days
      rsvpsMaybeLast30Days
      rsvpsNotGoingLast30Days
      totalAttendeesLast30Days
    }
  }
`;

const DAILY_METRICS_QUERY = gql`
  query DailyMetrics($days: Int) {
    dailyMetrics(days: $days) {
      date
      users
      cards
      invitations
      rsvps
    }
  }
`;

interface AnnualGoals {
  year: number;
  dauTarget: number;
  cardsAndInvitationsTarget: number;
  updatedAt: string;
}

function Dashboard() {
  const [editDialogOpen, setEditDialogOpen] = useState(false);
  const [annualGoals, setAnnualGoals] = useState<AnnualGoals | null>(null);
  const [goalsRefreshKey, setGoalsRefreshKey] = useState(0);

  const { data } = useQuery(BUSINESS_METRICS_QUERY);
  const { data: dailyData, loading: dailyLoading } = useQuery(DAILY_METRICS_QUERY, {
    variables: { days: 30 },
  });

  // Load annual goals from localStorage
  useEffect(() => {
    const storedGoals = localStorage.getItem('annualGoals');
    if (storedGoals) {
      try {
        setAnnualGoals(JSON.parse(storedGoals));
      } catch (error) {
        console.error('Failed to parse annual goals from localStorage:', error);
        setAnnualGoals(null);
      }
    } else {
      setAnnualGoals(null);
    }
  }, [goalsRefreshKey]);

  const handleGoalsSaved = () => {
    setGoalsRefreshKey(prev => prev + 1);
  };

  // Combine goals with current metrics
  const goalsData = annualGoals
    ? {
        year: annualGoals.year,
        dauTarget: annualGoals.dauTarget,
        cardsAndInvitationsTarget: annualGoals.cardsAndInvitationsTarget,
        currentDau: data?.businessMetrics.usersLast7Days || 0,
        currentCardsAndInvitations:
          (data?.businessMetrics.cardsLast180Days || 0) +
          (data?.businessMetrics.invitationsLast180Days || 0),
      }
    : undefined;

  const renderMetric = (label: string, value: number | undefined) => (
    <div className="flex justify-between py-1 text-sm">
      <span>{label}</span>
      {value !== undefined ? (
        <span className="font-medium">{value}</span>
      ) : (
        <Skeleton className="w-6 h-4" />
      )}
    </div>
  );

  return (
    <div className="p-4 max-w-7xl mx-auto space-y-6">
      {/* Annual Goals Section */}
      <AnnualGoalsCard data={goalsData} loading={!data} onEdit={() => setEditDialogOpen(true)} />

      <EditAnnualGoalsDialog
        open={editDialogOpen}
        onOpenChange={setEditDialogOpen}
        currentYear={annualGoals?.year}
        currentDauTarget={annualGoals?.dauTarget}
        currentCardsTarget={annualGoals?.cardsAndInvitationsTarget}
        onSuccess={handleGoalsSaved}
      />

      {/* Trend Charts Section */}
      <div className="space-y-6">
        <h2 className="text-2xl font-bold">Growth Trends (Last 30 Days)</h2>

        {dailyLoading ? (
          <div className="space-y-4">
            <Skeleton className="w-full h-[350px]" />
            <Skeleton className="w-full h-[350px]" />
          </div>
        ) : dailyData?.dailyMetrics ? (
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            <TrendChart
              title="User Growth"
              data={dailyData.dailyMetrics}
              lines={[{ dataKey: 'users', name: 'New Users', color: '#3b82f6' }]}
            />
            <TrendChart
              title="Card & Invitation Creation"
              data={dailyData.dailyMetrics}
              lines={[
                { dataKey: 'cards', name: 'Cards', color: '#10b981' },
                { dataKey: 'invitations', name: 'Invitations', color: '#f59e0b' },
              ]}
            />
            <TrendChart
              title="RSVP Activity"
              data={dailyData.dailyMetrics}
              lines={[{ dataKey: 'rsvps', name: 'RSVPs', color: '#8b5cf6' }]}
            />
            <TrendChart
              title="Combined Overview"
              data={dailyData.dailyMetrics}
              lines={[
                { dataKey: 'users', name: 'Users', color: '#3b82f6' },
                { dataKey: 'cards', name: 'Cards', color: '#10b981' },
                { dataKey: 'invitations', name: 'Invitations', color: '#f59e0b' },
                { dataKey: 'rsvps', name: 'RSVPs', color: '#8b5cf6' },
              ]}
            />
          </div>
        ) : null}
      </div>

      {/* Summary Metrics Section */}
      <div className="space-y-4">
        <h2 className="text-2xl font-bold">Summary Metrics</h2>
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          <Card>
            <CardHeader>
              <CardTitle className="text-lg font-bold">User Metrics</CardTitle>
            </CardHeader>
            <CardContent className="space-y-1">
              {renderMetric('Users (Last 1 Day)', data?.businessMetrics.usersLast1Day)}
              {renderMetric('Users (Last 7 Days)', data?.businessMetrics.usersLast7Days)}
              {renderMetric('Users (Last 30 Days)', data?.businessMetrics.usersLast30Days)}
              {renderMetric('Users (Last 90 Days)', data?.businessMetrics.usersLast90Days)}
              {renderMetric('Users (Last 180 Days)', data?.businessMetrics.usersLast180Days)}
            </CardContent>
          </Card>

          <Card>
            <CardHeader>
              <CardTitle className="text-lg font-bold">Card Metrics</CardTitle>
            </CardHeader>
            <CardContent className="space-y-1">
              {renderMetric('Cards (Last 1 Day)', data?.businessMetrics.cardsLast1Day)}
              {renderMetric('Cards (Last 7 Days)', data?.businessMetrics.cardsLast7Days)}
              {renderMetric('Cards (Last 30 Days)', data?.businessMetrics.cardsLast30Days)}
              {renderMetric('Cards (Last 90 Days)', data?.businessMetrics.cardsLast90Days)}
              {renderMetric('Cards (Last 180 Days)', data?.businessMetrics.cardsLast180Days)}
            </CardContent>
          </Card>

          <Card>
            <CardHeader>
              <CardTitle className="text-lg font-bold">Invitation Metrics</CardTitle>
            </CardHeader>
            <CardContent className="space-y-1">
              {renderMetric('Invitations (Last 1 Day)', data?.businessMetrics.invitationsLast1Day)}
              {renderMetric(
                'Invitations (Last 7 Days)',
                data?.businessMetrics.invitationsLast7Days
              )}
              {renderMetric(
                'Invitations (Last 30 Days)',
                data?.businessMetrics.invitationsLast30Days
              )}
              {renderMetric(
                'Invitations (Last 90 Days)',
                data?.businessMetrics.invitationsLast90Days
              )}
              {renderMetric(
                'Invitations (Last 180 Days)',
                data?.businessMetrics.invitationsLast180Days
              )}
            </CardContent>
          </Card>

          <Card>
            <CardHeader>
              <CardTitle className="text-lg font-bold">RSVP Metrics</CardTitle>
            </CardHeader>
            <CardContent className="space-y-1">
              {renderMetric('RSVPs (Last 1 Day)', data?.businessMetrics.rsvpsLast1Day)}
              {renderMetric('RSVPs (Last 7 Days)', data?.businessMetrics.rsvpsLast7Days)}
              {renderMetric('RSVPs (Last 30 Days)', data?.businessMetrics.rsvpsLast30Days)}
              {renderMetric('RSVPs (Last 90 Days)', data?.businessMetrics.rsvpsLast90Days)}
              {renderMetric('RSVPs (Last 180 Days)', data?.businessMetrics.rsvpsLast180Days)}
            </CardContent>
          </Card>

          <Card>
            <CardHeader>
              <CardTitle className="text-lg font-bold">RSVP Breakdown (Last 30 Days)</CardTitle>
            </CardHeader>
            <CardContent className="space-y-1">
              {renderMetric('Going', data?.businessMetrics.rsvpsGoingLast30Days)}
              {renderMetric('Maybe', data?.businessMetrics.rsvpsMaybeLast30Days)}
              {renderMetric('Not Going', data?.businessMetrics.rsvpsNotGoingLast30Days)}
              {renderMetric(
                'Total Attendees (with +1s)',
                data?.businessMetrics.totalAttendeesLast30Days
              )}
            </CardContent>
          </Card>
        </div>
      </div>
    </div>
  );
}

export default withAuth(Dashboard);
