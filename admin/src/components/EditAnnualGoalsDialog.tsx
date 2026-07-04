import { useState, useEffect } from 'react';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';

interface EditAnnualGoalsDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  currentYear?: number;
  currentDauTarget?: number;
  currentCardsTarget?: number;
  onSuccess: () => void;
}

export default function EditAnnualGoalsDialog({
  open,
  onOpenChange,
  currentYear,
  currentDauTarget,
  currentCardsTarget,
  onSuccess,
}: EditAnnualGoalsDialogProps) {
  const currentCalendarYear = new Date().getFullYear();
  const [year, setYear] = useState(currentYear || currentCalendarYear);
  const [dauTarget, setDauTarget] = useState(currentDauTarget || 1000);
  const [cardsTarget, setCardsTarget] = useState(currentCardsTarget || 1000);
  const [errors, setErrors] = useState<string[]>([]);

  // Update form when currentYear/targets change
  useEffect(() => {
    if (currentYear) setYear(currentYear);
    if (currentDauTarget) setDauTarget(currentDauTarget);
    if (currentCardsTarget) setCardsTarget(currentCardsTarget);
  }, [currentYear, currentDauTarget, currentCardsTarget]);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    setErrors([]);

    // Validate inputs
    const validationErrors: string[] = [];

    if (year < currentCalendarYear) {
      validationErrors.push('Cannot set goals for past years');
    }

    if (dauTarget <= 0) {
      validationErrors.push('DAU target must be greater than 0');
    }

    if (cardsTarget <= 0) {
      validationErrors.push('Cards and invitations target must be greater than 0');
    }

    if (validationErrors.length > 0) {
      setErrors(validationErrors);
      return;
    }

    // Save to localStorage
    const goals = {
      year,
      dauTarget,
      cardsAndInvitationsTarget: cardsTarget,
      updatedAt: new Date().toISOString(),
    };

    localStorage.setItem('annualGoals', JSON.stringify(goals));

    onSuccess();
    onOpenChange(false);
  };

  // Generate year options (current year and next 5 years)
  const yearOptions = Array.from({ length: 6 }, (_, i) => currentCalendarYear + i);

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-[425px]">
        <DialogHeader>
          <DialogTitle>Edit Annual Goals</DialogTitle>
          <DialogDescription>
            Update the annual targets for DAU and Cards+Invitations. Goals are stored locally in
            your browser.
          </DialogDescription>
        </DialogHeader>
        <form onSubmit={handleSubmit}>
          <div className="grid gap-4 py-4">
            {/* Year Selection */}
            <div className="grid grid-cols-4 items-center gap-4">
              <Label htmlFor="year" className="text-right">
                Year
              </Label>
              <select
                id="year"
                value={year}
                onChange={e => setYear(parseInt(e.target.value))}
                className="col-span-3 flex h-10 w-full rounded-md border border-input bg-background px-3 py-2 text-sm ring-offset-background file:border-0 file:bg-transparent file:text-sm file:font-medium placeholder:text-muted-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:cursor-not-allowed disabled:opacity-50"
              >
                {yearOptions.map(y => (
                  <option key={y} value={y}>
                    {y}
                  </option>
                ))}
              </select>
            </div>

            {/* DAU Target */}
            <div className="grid grid-cols-4 items-center gap-4">
              <Label htmlFor="dauTarget" className="text-right">
                DAU Target
              </Label>
              <Input
                id="dauTarget"
                type="number"
                min="1"
                value={dauTarget}
                onChange={e => setDauTarget(parseInt(e.target.value) || 0)}
                className="col-span-3"
              />
            </div>

            {/* Cards + Invitations Target */}
            <div className="grid grid-cols-4 items-center gap-4">
              <Label htmlFor="cardsTarget" className="text-right">
                Cards + Invitations
              </Label>
              <Input
                id="cardsTarget"
                type="number"
                min="1"
                value={cardsTarget}
                onChange={e => setCardsTarget(parseInt(e.target.value) || 0)}
                className="col-span-3"
              />
            </div>

            {/* Error Messages */}
            {errors.length > 0 && (
              <div className="col-span-4 p-3 bg-red-50 border border-red-200 rounded-md">
                <ul className="list-disc list-inside text-sm text-red-600">
                  {errors.map((error, index) => (
                    <li key={index}>{error}</li>
                  ))}
                </ul>
              </div>
            )}
          </div>
          <DialogFooter>
            <Button type="button" variant="outline" onClick={() => onOpenChange(false)}>
              Cancel
            </Button>
            <Button type="submit">Save Goals</Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
