import React from 'react';
import { gql, useQuery } from '@apollo/client';
import { Copy, Heart } from 'lucide-react';
import { toast } from 'sonner';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';

const GET_THANK_YOUS = gql`
  query GetRegistryThankYous($externalId: String!) {
    registry(externalId: $externalId) {
      externalId
      surpriseMode
      thankYouUnlocked
      thankYouList {
        guestName
        guestEmail
        itemTitle
        purchased
      }
    }
  }
`;

interface Props {
  externalId: string;
}

/**
 * Who to thank, for the owner (#252). Surprise mode keeps it hidden until the event date has passed,
 * so the owner can't spoil their own surprise by looking.
 */
export const ThankYouList: React.FC<Props> = ({ externalId }) => {
  const { data } = useQuery(GET_THANK_YOUS, { variables: { externalId } });
  const registry = data?.registry;
  if (!registry) return null;

  const claims: {
    guestName: string;
    guestEmail: string | null;
    itemTitle: string;
    purchased: boolean;
  }[] = registry.thankYouList;

  if (!registry.thankYouUnlocked) {
    return (
      <Card className="mt-6">
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Heart className="h-5 w-5 text-pink-500" />
            Thank-you list
          </CardTitle>
        </CardHeader>
        <CardContent className="text-sm text-gray-600">
          Surprise mode is on, so who gave what stays hidden until after the event date. Set a date,
          or turn surprise mode off, to see it sooner.
        </CardContent>
      </Card>
    );
  }

  const copy = async () => {
    const text = claims
      .map(
        c =>
          `${c.guestName}${c.guestEmail ? ` <${c.guestEmail}>` : ''} - ${c.itemTitle}${c.purchased ? '' : ' (not yet bought)'}`
      )
      .join('\n');
    try {
      await navigator.clipboard.writeText(text);
      toast.success('Copied the thank-you list');
    } catch {
      toast.error('Could not copy. You can select the text instead.');
    }
  };

  return (
    <Card className="mt-6">
      <CardHeader>
        <CardTitle className="flex items-center gap-2">
          <Heart className="h-5 w-5 text-pink-500" />
          Thank-you list
        </CardTitle>
      </CardHeader>
      <CardContent className="space-y-3">
        {claims.length === 0 ? (
          <p className="text-sm text-gray-600">Nobody has claimed anything yet.</p>
        ) : (
          <>
            <ul className="divide-y divide-gray-100 text-sm">
              {claims.map((c, i) => (
                <li key={i} className="flex flex-wrap items-baseline justify-between gap-x-4 py-2">
                  <span>
                    <span className="font-semibold text-gray-900">{c.guestName}</span>
                    {c.guestEmail && <span className="text-gray-500"> · {c.guestEmail}</span>}
                  </span>
                  <span className="text-gray-700">
                    {c.itemTitle}
                    {!c.purchased && <span className="text-gray-400"> (not yet bought)</span>}
                  </span>
                </li>
              ))}
            </ul>
            <Button variant="outline" size="sm" className="border-2" onClick={copy}>
              <Copy className="mr-1.5 h-3.5 w-3.5" />
              Copy list
            </Button>
          </>
        )}
      </CardContent>
    </Card>
  );
};
