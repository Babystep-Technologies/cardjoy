import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { ArrowRight } from 'lucide-react';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from '@/components/ui/dialog';
import { cardTypes } from '@/config/cardTypes';

interface IntentPickerDialogProps {
  // The single CTA button that opens the picker.
  children: React.ReactNode;
  // When set, carried into the chosen create flow as ?occasion= so the moment is
  // pre-selected (the create flows match it against the card occasion vocabulary).
  occasion?: string;
}

// One strong call to action that opens a lightweight chooser: the user picks the
// moment they have in mind (framed by intent) and lands in the matching create flow.
export const IntentPickerDialog: React.FC<IntentPickerDialogProps> = ({ children, occasion }) => {
  const navigate = useNavigate();
  const [open, setOpen] = useState(false);

  const handlePick = (route: string) => {
    setOpen(false);
    navigate(occasion ? `${route}?occasion=${encodeURIComponent(occasion)}` : route);
  };

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>{children}</DialogTrigger>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle className="text-2xl font-black text-gray-900">
            What do you want to do?
          </DialogTitle>
          <DialogDescription>
            Pick your moment and we&apos;ll set up the right card.
          </DialogDescription>
        </DialogHeader>

        <div className="mt-2 flex flex-col gap-3">
          {cardTypes.map(type => {
            const inner = (
              <>
                <div
                  className={`shrink-0 flex items-center justify-center w-11 h-11 rounded-xl bg-gradient-to-br ${type.gradient}`}
                >
                  <type.icon className="w-5 h-5 text-white" />
                </div>
                <div className="flex-1 text-left">
                  <div className="flex items-center gap-2 font-bold text-gray-900">
                    {type.intent}
                    {type.comingSoon && (
                      <span className="text-[10px] font-semibold uppercase tracking-wide text-gray-400 border border-gray-200 rounded-full px-1.5 py-0.5">
                        Soon
                      </span>
                    )}
                  </div>
                  <div className="text-sm text-gray-500">{type.label}</div>
                </div>
                {!type.comingSoon && <ArrowRight className="w-5 h-5 shrink-0 text-gray-400" />}
              </>
            );

            if (type.comingSoon) {
              return (
                <div
                  key={type.id}
                  className="flex items-center gap-3 rounded-2xl border-2 border-gray-100 p-3 opacity-60"
                >
                  {inner}
                </div>
              );
            }

            return (
              <button
                key={type.id}
                onClick={() => handlePick(type.route)}
                className="flex items-center gap-3 rounded-2xl border-2 border-gray-100 p-3 transition-all hover:border-gray-300 hover:bg-gray-50"
              >
                {inner}
              </button>
            );
          })}
        </div>
      </DialogContent>
    </Dialog>
  );
};
