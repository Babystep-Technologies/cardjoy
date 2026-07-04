import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Sparkles } from 'lucide-react';

export default function Careers() {
  return (
    <div className="max-w-2xl mx-auto px-4 py-12 text-center">
      <Card className="shadow-xl border-none">
        <CardHeader>
          <div className="flex flex-col items-center space-y-2">
            <Sparkles className="h-8 w-8 text-yellow-500" />
            <CardTitle className="text-3xl font-bold">Join Our Team</CardTitle>
          </div>
        </CardHeader>
        <CardContent className="space-y-6 text-base text-muted-foreground leading-relaxed">
          <p>
            At <strong>CardJoy</strong>, our mission is simple but powerful:{' '}
            <span className="text-foreground font-medium">
              cherish life moments with the best online greeting cards
            </span>
            .
          </p>

          <p>
            We’re a small, thoughtful team building a platform that spreads connection and joy
            through beautifully designed, collaborative greeting cards.
          </p>

          <p className="font-semibold text-foreground">
            We don't have any open positions at the moment.
          </p>
        </CardContent>
      </Card>
    </div>
  );
}
