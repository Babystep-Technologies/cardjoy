import { useState } from 'react';
import { useMutation } from '@apollo/client';
import { toast } from 'sonner';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Textarea } from '@/components/ui/textarea';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';
import { Dialog, DialogContent, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { Sheet, SheetContent, SheetHeader, SheetTitle } from '@/components/ui/sheet';
import { isMobile } from '@/lib/utils';
import { CREATE_SUPPORT_TICKET } from '../queries';
import { SUPPORT_CATEGORIES, type SupportTicketSummary } from '../types';

interface NewTicketDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  onCreated: (ticket: SupportTicketSummary) => void;
}

/** New-ticket form: subject + category + body, all required. Sheet on mobile, Dialog on desktop —
 * the same split the old Profile.tsx "Contact Us" dialog used. */
export default function NewTicketDialog({ open, onOpenChange, onCreated }: NewTicketDialogProps) {
  const [subject, setSubject] = useState('');
  const [category, setCategory] = useState('');
  const [body, setBody] = useState('');
  const [createSupportTicket, { loading }] = useMutation(CREATE_SUPPORT_TICKET);

  const reset = () => {
    setSubject('');
    setCategory('');
    setBody('');
  };

  const handleSubmit = async () => {
    if (!subject.trim() || !category || !body.trim()) {
      toast.error('Please fill in a subject, category, and message.');
      return;
    }

    try {
      const { data } = await createSupportTicket({
        variables: { input: { subject: subject.trim(), category, body: body.trim() } },
      });
      const result = data?.createSupportTicket;
      if (result?.errors?.length) {
        toast.error(result.errors.join(', '));
        return;
      }
      if (!result?.supportTicket) {
        toast.error('Something went wrong. Please try again.');
        return;
      }

      toast.success('Support request sent.');
      reset();
      onOpenChange(false);
      onCreated(result.supportTicket);
    } catch (err) {
      toast.error(`Something went wrong: ${(err as Error).message}`);
    }
  };

  const form = (
    <div className="space-y-4">
      <div className="space-y-1">
        <Label htmlFor="support-subject">Subject</Label>
        <Input
          id="support-subject"
          value={subject}
          onChange={e => setSubject(e.target.value)}
          placeholder="What's this about?"
        />
      </div>
      <div className="space-y-1">
        <Label>Category</Label>
        <Select value={category} onValueChange={setCategory}>
          <SelectTrigger className="w-full">
            <SelectValue placeholder="Select a category" />
          </SelectTrigger>
          <SelectContent>
            {SUPPORT_CATEGORIES.map(({ value, label }) => (
              <SelectItem key={value} value={value}>
                {label}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>
      </div>
      <div className="space-y-1">
        <Label htmlFor="support-body">Message</Label>
        <Textarea
          id="support-body"
          className="w-full"
          value={body}
          onChange={e => setBody(e.target.value)}
          placeholder="How can we help?"
          rows={8}
        />
      </div>
      <Button onClick={handleSubmit} disabled={loading} className="w-full">
        {loading ? 'Sending...' : 'Submit'}
      </Button>
    </div>
  );

  if (isMobile()) {
    return (
      <Sheet open={open} onOpenChange={onOpenChange}>
        <SheetContent
          side="bottom"
          className="bg-white text-black p-6 space-y-4 h-[95vh] overflow-y-auto rounded-t-xl"
        >
          <SheetHeader className="p-0">
            <SheetTitle>New support request</SheetTitle>
          </SheetHeader>
          {form}
        </SheetContent>
      </Sheet>
    );
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="bg-white text-black p-6 space-y-4">
        <DialogHeader className="p-0">
          <DialogTitle>New support request</DialogTitle>
        </DialogHeader>
        {form}
      </DialogContent>
    </Dialog>
  );
}
