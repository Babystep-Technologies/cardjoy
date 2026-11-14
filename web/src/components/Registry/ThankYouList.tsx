import React from 'react';
import { gql, useMutation, useQuery } from '@apollo/client';
import { Link } from 'react-router-dom';
import { Copy, Heart, Mail } from 'lucide-react';
import { toast } from 'sonner';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';

export const GET_THANK_YOUS = gql`
  query GetRegistryThankYous($externalId: String!) {
    registry(externalId: $externalId) {
      externalId
      surpriseMode
      thankYouUnlocked
      thankYouList {
        id
        guestName
        guestEmail
        itemTitle
        purchased
        thanked
      }
    }
  }
`;

// Also used by the thank-you card flow, which marks a guest thanked once their card is sent.
export const SET_THANK_YOU_SENT = gql`
  mutation SetThankYouSent($input: SetThankYouSentInput!) {
    setThankYouSent(input: $input) {
      thanked
      errors
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
  const { data, refetch } = useQuery(GET_THANK_YOUS, { variables: { externalId } });
  const [setThankYouSent] = useMutation(SET_THANK_YOU_SENT);
  const registry = data?.registry;
  if (!registry) return null;

  const claims: {
    id: string;
    guestName: string;
    guestEmail: string | null;
    itemTitle: string;
    purchased: boolean;
    thanked: boolean;
  }[] = registry.thankYouList;
  const thankedCount = claims.filter(c => c.thanked).length;

  const toggleThanked = async (claimId: string, sent: boolean) => {
    try {
      const { data: result } = await setThankYouSent({
        variables: { input: { registryExternalId: externalId, reservationId: claimId, sent } },
      });
      const errors: string[] = result?.setThankYouSent?.errors ?? [];
      if (errors.length > 0) toast.error(errors.join(', '));
      await refetch();
    } catch (e) {
      console.error('Failed to update thank-you', e);
      toast.error('Could not update that. Please try again.');
    }
  };

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
            <p className="text-sm text-gray-600">
              {thankedCount} of {claims.length} thanked
            </p>
            <ul className="divide-y divide-gray-100 text-sm">
              {claims.map(c => (
                <li
                  key={c.id}
                  className="flex flex-wrap items-center justify-between gap-x-4 gap-y-1 py-2"
                >
                  <label className="flex items-center gap-2">
                    <input
                      type="checkbox"
                      checked={c.thanked}
                      onChange={e => toggleThanked(c.id, e.target.checked)}
                      aria-label={`Thanked ${c.guestName}`}
                      className="h-4 w-4"
                    />
                    <span className={c.thanked ? 'text-gray-400 line-through' : ''}>
                      <span className="font-semibold text-gray-900">{c.guestName}</span>
                      {c.guestEmail && <span className="text-gray-500"> · {c.guestEmail}</span>}
                    </span>
                  </label>
                  <span className="flex items-center gap-3 text-gray-700">
                    <span>
                      {c.itemTitle}
                      {!c.purchased && <span className="text-gray-400"> (not yet bought)</span>}
                    </span>
                    {c.guestEmail && !c.thanked && (
                      <Button variant="outline" size="sm" asChild>
                        <Link
                          to={`/one-on-one-card/new?${new URLSearchParams({
                            occasion: 'Thank You',
                            thankYouRegistry: externalId,
                            thankYouClaim: c.id,
                          })}`}
                        >
                          <Mail className="mr-1.5 h-3.5 w-3.5" />
                          Send card
                        </Link>
                      </Button>
                    )}
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
