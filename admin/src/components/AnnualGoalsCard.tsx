import { Card, CardHeader, CardTitle, CardContent } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Progress } from '@/components/ui/progress';
import { Skeleton } from '@/components/ui/skeleton';

interface AnnualGoalsData {
  year: number;
  dauTarget: number;
  cardsAndInvitationsTarget: number;
  currentDau: number;
  currentCardsAndInvitations: number;
}

interface AnnualGoalsCardProps {
  data?: AnnualGoalsData;
  loading: boolean;
  onEdit: () => void;
}

export default function AnnualGoalsCard({ data, loading, onEdit }: AnnualGoalsCardProps) {
  if (loading) {
    return (
      <Card>
        <CardHeader>
          <CardTitle className="text-2xl font-bold">
            <Skeleton className="w-48 h-8" />
          </CardTitle>
        </CardHeader>
        <CardContent>
          <Skeleton className="w-full h-24" />
        </CardContent>
      </Card>
    );
  }

  if (!data) {
    return (
      <Card className="border-2 border-gray-200">
        <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-4">
          <CardTitle className="text-2xl font-bold">Annual Goals</CardTitle>
          <Button onClick={onEdit} variant="outline" size="sm">
            Set Goals
          </Button>
        </CardHeader>
        <CardContent>
          <p className="text-gray-600">
            No annual goals set yet. Click "Set Goals" to configure your targets.
          </p>
        </CardContent>
      </Card>
    );
  }

  // Calculate progress percentages
  const dauProgressPercentage = data.dauTarget > 0 ? (data.currentDau / data.dauTarget) * 100 : 0;
  const cardsProgressPercentage =
    data.cardsAndInvitationsTarget > 0
      ? (data.currentCardsAndInvitations / data.cardsAndInvitationsTarget) * 100
      : 0;

  // Calculate year progress
  const now = new Date();
  const yearStart = new Date(data.year, 0, 1);
  const yearEnd = new Date(data.year, 11, 31, 23, 59, 59);
  const daysInYear = Math.ceil((yearEnd.getTime() - yearStart.getTime()) / (1000 * 60 * 60 * 24));
  const daysElapsed = Math.max(
    0,
    Math.min(daysInYear, Math.ceil((now.getTime() - yearStart.getTime()) / (1000 * 60 * 60 * 24)))
  );
  const daysRemaining = Math.max(0, daysInYear - daysElapsed);
  const yearProgressPercentage = (daysElapsed / daysInYear) * 100;

  // Determine color based on progress vs year progress
  const getProgressColor = (progress: number, yearProgress: number) => {
    const ratio = progress / yearProgress;
    if (ratio >= 0.9) return 'bg-green-500'; // On track or ahead
    if (ratio >= 0.7) return 'bg-yellow-500'; // Slightly behind
    return 'bg-red-500'; // Significantly behind
  };

  const dauColor = getProgressColor(dauProgressPercentage, yearProgressPercentage);
  const cardsColor = getProgressColor(cardsProgressPercentage, yearProgressPercentage);

  return (
    <Card className="border-2 border-blue-200 bg-blue-50">
      <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-4">
        <CardTitle className="text-2xl font-bold">{data.year} Annual Goals</CardTitle>
        <Button onClick={onEdit} variant="outline" size="sm">
          Edit Goals
        </Button>
      </CardHeader>
      <CardContent className="space-y-6">
        {/* Time Progress */}
        <div className="p-4 bg-white rounded-lg border">
          <p className="text-sm text-gray-600 mb-2">
            Day {daysElapsed} of {daysInYear} • {yearProgressPercentage.toFixed(1)}% of year
            complete • {daysRemaining} days remaining
          </p>
          <Progress value={yearProgressPercentage} indicatorClassName="bg-blue-500" />
        </div>

        {/* DAU Goal */}
        <div className="space-y-2">
          <div className="flex justify-between items-baseline">
            <h3 className="text-lg font-semibold">Daily Active Users (7-day rolling)</h3>
            <div className="text-right">
              <span className="text-2xl font-bold">{data.currentDau}</span>
              <span className="text-gray-600"> / {data.dauTarget}</span>
              <span className="text-sm text-gray-500 ml-2">
                ({dauProgressPercentage.toFixed(1)}%)
              </span>
            </div>
          </div>
          <Progress value={dauProgressPercentage} indicatorClassName={dauColor} />
        </div>

        {/* Cards + Invitations Goal */}
        <div className="space-y-2">
          <div className="flex justify-between items-baseline">
            <h3 className="text-lg font-semibold">Cards + Invitations (YTD)</h3>
            <div className="text-right">
              <span className="text-2xl font-bold">{data.currentCardsAndInvitations}</span>
              <span className="text-gray-600"> / {data.cardsAndInvitationsTarget}</span>
              <span className="text-sm text-gray-500 ml-2">
                ({cardsProgressPercentage.toFixed(1)}%)
              </span>
            </div>
          </div>
          <Progress value={cardsProgressPercentage} indicatorClassName={cardsColor} />
        </div>

        {/* Legend */}
        <div className="flex gap-4 text-xs text-gray-600 pt-2">
          <div className="flex items-center gap-1">
            <div className="w-3 h-3 rounded-full bg-green-500"></div>
            <span>On track</span>
          </div>
          <div className="flex items-center gap-1">
            <div className="w-3 h-3 rounded-full bg-yellow-500"></div>
            <span>Behind pace</span>
          </div>
          <div className="flex items-center gap-1">
            <div className="w-3 h-3 rounded-full bg-red-500"></div>
            <span>Significantly behind</span>
          </div>
        </div>
      </CardContent>
    </Card>
  );
}
