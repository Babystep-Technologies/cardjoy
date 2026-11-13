/**
 * `/registry/new` and `/registry/:externalId/edit` — create or edit a registry (#245).
 *
 * One page for both: the form is the same, and a registry is saved with the same
 * `upsertWishList` mutation the invitation wish list uses. With no id it creates a standalone
 * registry; with `registryExternalId` it updates the caller's own.
 */
import React, { useEffect, useState } from 'react';
import { gql, useMutation, useQuery } from '@apollo/client';
import { useNavigate, useParams } from 'react-router-dom';
import { Toaster, toast } from 'sonner';
import { Gift } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Switch } from '@/components/ui/switch';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';
import LoadingScreen from '@/components/Loading';
import ErrorScreen from '@/components/Error';
import withAuth from '@/lib/with-auth';
import WishListFields from '@/pages/Invitation/components/WishListFields';
import {
  emptyWishListDraft,
  REGISTRY_OCCASIONS,
  UPSERT_WISH_LIST_MUTATION,
  validateWishListDraft,
  WISH_LIST_FIELDS,
  wishListDraftToInput,
  wishListToDraft,
  type WishListDraft,
} from '@/lib/wishList';

const UPSERT_WISH_LIST = gql(UPSERT_WISH_LIST_MUTATION);

// Named GetRegistry to match GraphqlController::PUBLIC_OPERATIONS; the owner is signed in here,
// so the same query serves the editor and (later) the guest page.
const GET_REGISTRY = gql`
  query GetRegistry($externalId: String!) {
    registry(externalId: $externalId) {
      ${WISH_LIST_FIELDS}
    }
  }
`;

const RegistryEdit: React.FC = () => {
  const { externalId } = useParams<{ externalId: string }>();
  const navigate = useNavigate();
  const isNew = !externalId;

  const [draft, setDraft] = useState<WishListDraft>({ ...emptyWishListDraft(), title: '' });
  const [saving, setSaving] = useState(false);

  const { data, loading, error } = useQuery(GET_REGISTRY, {
    variables: { externalId },
    skip: isNew,
    fetchPolicy: 'network-only',
  });
  const [upsertWishList] = useMutation(UPSERT_WISH_LIST);

  useEffect(() => {
    if (data?.registry) setDraft(wishListToDraft(data.registry));
  }, [data]);

  const handleSave = async () => {
    if (!draft.title.trim()) {
      toast.error('Give your registry a name');
      return;
    }
    const problem = validateWishListDraft(draft);
    if (problem) {
      toast.error(problem);
      return;
    }

    setSaving(true);
    try {
      const { data: result } = await upsertWishList({
        variables: {
          input: { registryExternalId: externalId ?? null, ...wishListDraftToInput(draft) },
        },
      });
      const errors: string[] = result?.upsertWishList?.errors ?? [];
      if (errors.length > 0) {
        toast.error(errors.join(', '));
        return;
      }

      toast.success('Registry saved!');
      const savedId = result?.upsertWishList?.wishList?.externalId;
      if (isNew && savedId) navigate(`/registry/${savedId}/edit`, { replace: true });
    } catch (e) {
      console.error('Failed to save registry', e);
      toast.error('Failed to save the registry. Please try again.');
    } finally {
      setSaving(false);
    }
  };

  if (loading) return <LoadingScreen />;
  if (error || (!isNew && !data?.registry)) return <ErrorScreen />;

  return (
    <div className="mx-auto max-w-3xl p-4 sm:p-8">
      <Toaster />
      <h1 className="mb-6 flex items-center gap-3 text-3xl font-bold text-gray-900">
        <Gift className="h-8 w-8 text-yellow-500" />
        {isNew ? 'Create a registry' : 'Edit your registry'}
      </h1>

      <Card className="mb-6">
        <CardHeader>
          <CardTitle>What&apos;s the occasion?</CardTitle>
        </CardHeader>
        <CardContent className="grid gap-4 sm:grid-cols-2">
          <div className="space-y-2">
            <Label htmlFor="registryOccasion">Occasion</Label>
            <Select
              value={draft.occasion || undefined}
              onValueChange={occasion => setDraft({ ...draft, occasion })}
            >
              <SelectTrigger id="registryOccasion">
                <SelectValue placeholder="Pick one (optional)" />
              </SelectTrigger>
              <SelectContent>
                {REGISTRY_OCCASIONS.map(occasion => (
                  <SelectItem key={occasion.value} value={occasion.value}>
                    {occasion.label}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>
          <div className="space-y-2">
            <Label htmlFor="registryEventDate">Date (optional)</Label>
            <Input
              id="registryEventDate"
              type="date"
              value={draft.eventDate}
              onChange={e => setDraft({ ...draft, eventDate: e.target.value })}
            />
          </div>
        </CardContent>
      </Card>

      <Card>
        <CardContent className="space-y-6 pt-6">
          <WishListFields
            value={draft}
            onChange={setDraft}
            idPrefix="registry"
            visibilityLabel="Share this registry"
            extraSettings={
              <>
                <div className="flex items-center justify-between gap-4">
                  <div>
                    <Label htmlFor="registryShareAddress" className="text-base font-semibold">
                      Share my mailing address with guests who claim a gift
                    </Label>
                    <p className="text-sm text-gray-500">
                      Only people who claim an item see it, and only while this is on. It uses the
                      address saved on your profile.
                    </p>
                  </div>
                  <Switch
                    id="registryShareAddress"
                    checked={draft.shareAddress}
                    onCheckedChange={shareAddress => setDraft({ ...draft, shareAddress })}
                  />
                </div>
                <div className="flex items-center justify-between gap-4">
                  <div>
                    <Label htmlFor="registryRemindOwner" className="text-base font-semibold">
                      Remind me before the event
                    </Label>
                    <p className="text-sm text-gray-500">
                      We email you about two weeks ahead, if you've set an event date, to share the
                      registry. Nothing is sent once the event has passed.
                    </p>
                  </div>
                  <Switch
                    id="registryRemindOwner"
                    checked={draft.remindOwner}
                    onCheckedChange={remindOwner => setDraft({ ...draft, remindOwner })}
                  />
                </div>
              </>
            }
          />
          <div className="flex justify-end pt-2">
            <Button onClick={handleSave} disabled={saving} className="h-12 px-6 font-bold">
              {saving ? 'Saving...' : isNew ? 'Create registry' : 'Save registry'}
            </Button>
          </div>
        </CardContent>
      </Card>
    </div>
  );
};

export default withAuth(RegistryEdit);
