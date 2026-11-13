import React, { useState } from 'react';
import { gql, useMutation } from '@apollo/client';
import { RotateCcw } from 'lucide-react';
import { toast } from 'sonner';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';

const RESET_REGISTRY = gql`
  mutation ResetRegistry($externalId: String!) {
    resetRegistry(input: { externalId: $externalId }) {
      wishList {
        externalId
      }
      errors
    }
  }
`;

interface Props {
  externalId: string;
  onReset: () => void;
}

/**
 * "Start a new year" for a recurring registry (#251). Destructive for guests (their claims are
 * cleared and their claim links stop working), so it asks twice.
 */
export const ResetRegistry: React.FC<Props> = ({ externalId, onReset }) => {
  const [resetRegistry, { loading }] = useMutation(RESET_REGISTRY);
  const [confirming, setConfirming] = useState(false);

  const handleReset = async () => {
    try {
      const { data } = await resetRegistry({ variables: { externalId } });
      const errors: string[] = data?.resetRegistry?.errors ?? [];
      if (errors.length > 0) {
        toast.error(errors.join(', '));
        return;
      }
      toast.success('Ready for the new year');
      setConfirming(false);
      onReset();
    } catch (e) {
      console.error('Failed to reset registry', e);
      toast.error('Could not reset the registry. Please try again.');
    }
  };

  return (
    <Card className="mt-6">
      <CardHeader>
        <CardTitle className="flex items-center gap-2">
          <RotateCcw className="h-5 w-5 text-gray-500" />
          Start a new year
        </CardTitle>
      </CardHeader>
      <CardContent className="space-y-3 text-sm text-gray-600">
        <p>
          Keep your items, clear everything guests claimed, and move the date forward a year. Good
          for a birthday list you reuse.
        </p>
        {confirming ? (
          <div className="space-y-2">
            <p className="font-semibold text-gray-900">
              This frees every claimed item and cannot be undone. Guests&apos; claim links will stop
              working.
            </p>
            <div className="flex gap-2">
              <Button variant="destructive" size="sm" disabled={loading} onClick={handleReset}>
                {loading ? 'Resetting...' : 'Yes, reset it'}
              </Button>
              <Button
                variant="outline"
                size="sm"
                disabled={loading}
                onClick={() => setConfirming(false)}
              >
                Cancel
              </Button>
            </div>
          </div>
        ) : (
          <Button
            variant="outline"
            size="sm"
            className="border-2"
            onClick={() => setConfirming(true)}
          >
            Reset for next year
          </Button>
        )}
      </CardContent>
    </Card>
  );
};
