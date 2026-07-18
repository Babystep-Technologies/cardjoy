import React from 'react';
import { format } from 'date-fns';
import { Calendar as CalendarIcon, Clock } from 'lucide-react';

import { Button } from '@/components/ui/button';
import { Label } from '@/components/ui/label';
import { Calendar as CalendarComponent } from '@/components/ui/calendar';
import { Popover, PopoverContent, PopoverTrigger } from '@/components/ui/popover';
import { cn } from '@/lib/utils';
import { TIMEZONE_OPTIONS } from '@/lib/timezone';

interface SchedulePickerProps {
  date: Date | undefined;
  time: string; // 'HH:mm'
  timezone: string;
  onDateChange: (date: Date | undefined) => void;
  onTimeChange: (time: string) => void;
  onTimezoneChange: (timezone: string) => void;
  idPrefix?: string;
}

const formatTimeLabel = (time: string) => {
  const [hours, minutes] = time.split(':');
  const hour = parseInt(hours, 10);
  const period = hour >= 12 ? 'pm' : 'am';
  const displayHour = hour === 0 ? 12 : hour > 12 ? hour - 12 : hour;
  return `${displayHour}:${minutes}${period}`;
};

// Reusable date/time/timezone control for scheduling a 1-on-1 send. The parent
// owns the pieces; convert to a UTC instant with `zonedWallTimeToUtcISO`.
const SchedulePicker: React.FC<SchedulePickerProps> = ({
  date,
  time,
  timezone,
  onDateChange,
  onTimeChange,
  onTimezoneChange,
  idPrefix = 'schedule',
}) => {
  // Disable past dates; a same-day past time is still possible but the API
  // treats any past deliverAt as "send now", so it degrades safely.
  const today = new Date();
  today.setHours(0, 0, 0, 0);

  return (
    <div className="space-y-4">
      <div className="grid gap-4 sm:grid-cols-2">
        <div className="space-y-2">
          <Label className="flex items-center gap-2 text-base font-semibold">
            <CalendarIcon className="h-4 w-4 text-pink-500" />
            Date
          </Label>
          <Popover>
            <PopoverTrigger asChild>
              <Button
                variant="outline"
                className={cn(
                  'h-11 w-full justify-start border-2 text-left font-normal focus:border-pink-400',
                  !date && 'text-muted-foreground'
                )}
              >
                <CalendarIcon className="mr-2 h-4 w-4" />
                {date ? format(date, 'PPP') : <span>Pick a date</span>}
              </Button>
            </PopoverTrigger>
            <PopoverContent className="w-auto p-0" align="start">
              <CalendarComponent
                mode="single"
                selected={date}
                onSelect={onDateChange}
                disabled={{ before: today }}
                initialFocus
              />
            </PopoverContent>
          </Popover>
        </div>

        <div className="space-y-2">
          <Label className="flex items-center gap-2 text-base font-semibold">
            <Clock className="h-4 w-4 text-blue-500" />
            Time
          </Label>
          <Popover>
            <PopoverTrigger asChild>
              <Button
                variant="outline"
                className={cn(
                  'h-11 w-full justify-start border-2 text-left font-normal focus:border-blue-400',
                  !time && 'text-muted-foreground'
                )}
              >
                <Clock className="mr-2 h-4 w-4" />
                {time ? formatTimeLabel(time) : <span>Pick a time</span>}
              </Button>
            </PopoverTrigger>
            <PopoverContent className="w-[140px] p-0" align="start">
              <div className="max-h-[280px] overflow-y-auto">
                {Array.from({ length: 96 }, (_, i) => {
                  const totalMinutes = i * 15;
                  const hours = Math.floor(totalMinutes / 60);
                  const minutes = totalMinutes % 60;
                  const militaryTime = `${hours.toString().padStart(2, '0')}:${minutes
                    .toString()
                    .padStart(2, '0')}`;

                  return (
                    <button
                      key={militaryTime}
                      type="button"
                      onClick={() => onTimeChange(militaryTime)}
                      className={cn(
                        'w-full border-b px-4 py-3 text-left transition-colors last:border-b-0 hover:bg-blue-50',
                        time === militaryTime && 'bg-blue-100 font-semibold text-blue-700'
                      )}
                    >
                      {formatTimeLabel(militaryTime)}
                    </button>
                  );
                })}
              </div>
            </PopoverContent>
          </Popover>
        </div>
      </div>

      <div className="space-y-2">
        <Label
          htmlFor={`${idPrefix}-timezone`}
          className="flex items-center gap-2 text-base font-semibold"
        >
          <Clock className="h-4 w-4 text-purple-500" />
          Timezone
        </Label>
        <select
          id={`${idPrefix}-timezone`}
          value={timezone}
          onChange={e => onTimezoneChange(e.target.value)}
          className="h-11 w-full rounded-md border-2 border-input bg-background px-3 focus:border-purple-400 focus:outline-none"
        >
          {TIMEZONE_OPTIONS.map(option => (
            <option key={option.value} value={option.value}>
              {option.label}
            </option>
          ))}
        </select>
      </div>
    </div>
  );
};

export default SchedulePicker;
