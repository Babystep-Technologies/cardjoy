/**
 * `/registry/add` — the landing page for the "Add to CardJoy registry" bookmarklet (#298).
 *
 * With product details in the query string (from the bookmarklet) it shows an editable item and
 * asks which registry to add it to; nothing is saved until the owner confirms, since anyone can
 * craft a link to this page. With no details it explains and offers the bookmarklet to install.
 */
import React, { useEffect, useRef, useState } from 'react';
import { gql, useApolloClient, useQuery } from '@apollo/client';
import { Link, useNavigate, useSearchParams } from 'react-router-dom';
import { Toaster, toast } from 'sonner';
import { Bookmark, Gift } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';
import withAuth from '@/lib/with-auth';
import { buildBookmarklet, parseCapturedItem } from '@/lib/bookmarklet';
import {
  emptyWishListItem,
  UPSERT_WISH_LIST_MUTATION,
  WISH_LIST_FIELDS,
  wishListDraftToInput,
  wishListToDraft,
} from '@/lib/wishList';

const GET_MY_REGISTRIES = gql`
  query MyRegistries {
    myRegistries {
      externalId
      title
      standalone
    }
  }
`;

const GET_REGISTRY = gql`
  query GetRegistry($externalId: String!) {
    registry(externalId: $externalId) {
      ${WISH_LIST_FIELDS}
    }
  }
`;

const UPSERT_WISH_LIST = gql(UPSERT_WISH_LIST_MUTATION);

/** The install link. React 19 refuses `javascript:` hrefs, so it is set on the element directly. */
const BookmarkletLink: React.FC = () => {
  const ref = useRef<HTMLAnchorElement>(null);
  useEffect(() => {
    ref.current?.setAttribute('href', buildBookmarklet(window.location.origin));
  }, []);
  return (
    <a
      ref={ref}
      onClick={e => {
        // Clicking runs it on this page, which is pointless; it is meant to be dragged.
        e.preventDefault();
        toast.info('Drag this button to your bookmarks bar instead of clicking it.');
      }}
      className="inline-flex cursor-grab items-center gap-2 rounded-md border-2 border-dashed border-pink-400 bg-pink-50 px-4 py-2 font-semibold text-pink-700"
    >
      <Bookmark className="h-4 w-4" />
      Add to CardJoy
    </a>
  );
};

const RegistryAdd: React.FC = () => {
  const [params] = useSearchParams();
  const navigate = useNavigate();
  const client = useApolloClient();
  const captured = parseCapturedItem(params);

  const { data } = useQuery(GET_MY_REGISTRIES);
  const registries: { externalId: string; title: string }[] = (data?.myRegistries ?? []).filter(
    (r: { standalone: boolean }) => r.standalone
  );

  const [registryId, setRegistryId] = useState('');
  const [title, setTitle] = useState(captured?.title ?? '');
  const [price, setPrice] = useState(captured?.price ?? '');
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    if (!registryId && registries.length > 0) setRegistryId(registries[0].externalId);
  }, [registries, registryId]);

  const save = async () => {
    if (!captured || !registryId) return;
    if (!title.trim()) {
      toast.error('Give the item a name');
      return;
    }
    setSaving(true);
    try {
      // Saving a registry sends its items in full, so read the current list and append.
      const { data: current } = await client.query({
        query: GET_REGISTRY,
        variables: { externalId: registryId },
        fetchPolicy: 'network-only',
      });
      if (!current?.registry) throw new Error('Registry not found');
      const draft = wishListToDraft(current.registry);
      draft.items = [
        ...draft.items,
        {
          ...emptyWishListItem(),
          title: title.trim(),
          price: price.trim(),
          url: captured.url,
          imageUrl: captured.imageUrl,
        },
      ];
      const { data: result } = await client.mutate({
        mutation: UPSERT_WISH_LIST,
        variables: { input: { registryExternalId: registryId, ...wishListDraftToInput(draft) } },
      });
      const errors: string[] = result?.upsertWishList?.errors ?? [];
      if (errors.length > 0) {
        toast.error(errors.join(', '));
        return;
      }
      toast.success('Added to your registry');
      navigate(`/registry/${registryId}/edit`);
    } catch (e) {
      console.error('Failed to add item', e);
      toast.error('Could not add the item. Please try again.');
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="mx-auto max-w-xl p-4 sm:p-8">
      <Toaster />
      <h1 className="mb-6 flex items-center gap-3 text-3xl font-bold text-gray-900">
        <Gift className="h-8 w-8 text-yellow-500" />
        {captured ? 'Add to a registry' : 'Add from any store'}
      </h1>

      {captured ? (
        <Card>
          <CardContent className="space-y-4 pt-6">
            {captured.imageUrl && (
              <img
                src={captured.imageUrl}
                alt=""
                referrerPolicy="no-referrer"
                className="mx-auto max-h-48 rounded-lg object-contain"
              />
            )}
            <div className="space-y-2">
              <Label htmlFor="addTitle">Name</Label>
              <Input id="addTitle" value={title} onChange={e => setTitle(e.target.value)} />
            </div>
            <div className="space-y-2">
              <Label htmlFor="addPrice">Price (optional)</Label>
              <Input id="addPrice" value={price} onChange={e => setPrice(e.target.value)} />
            </div>
            <p className="break-all text-xs text-gray-500">{captured.url}</p>
            {registries.length === 0 ? (
              <p className="text-sm text-gray-600">
                You don&apos;t have a registry yet.{' '}
                <Link to="/registry/new" className="font-semibold underline">
                  Create one
                </Link>{' '}
                and use the button again.
              </p>
            ) : (
              <div className="space-y-2">
                <Label htmlFor="addRegistry">Add to</Label>
                <Select value={registryId} onValueChange={setRegistryId}>
                  <SelectTrigger id="addRegistry">
                    <SelectValue placeholder="Choose a registry" />
                  </SelectTrigger>
                  <SelectContent>
                    {registries.map(r => (
                      <SelectItem key={r.externalId} value={r.externalId}>
                        {r.title}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
            )}
            <div className="flex justify-end">
              <Button onClick={save} disabled={saving || !registryId} className="font-bold">
                {saving ? 'Adding...' : 'Add item'}
              </Button>
            </div>
          </CardContent>
        </Card>
      ) : (
        <Card>
          <CardHeader>
            <CardTitle>Add gifts straight from the store&apos;s page</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4 text-sm text-gray-700">
            <p>
              Some stores don&apos;t let us read their pages, so pasting a link can come up empty.
              This button works from the page you&apos;re already looking at, so it still gets the
              name, picture and price.
            </p>
            <ol className="list-decimal space-y-1 pl-5">
              <li>Drag the button below to your bookmarks bar.</li>
              <li>On any product page, click it.</li>
              <li>Check the details and pick a registry.</li>
            </ol>
            <div className="py-2">
              <BookmarkletLink />
            </div>
            <p className="text-xs text-gray-500">
              A few sites block bookmarklets with their security settings; paste the link into your
              registry instead. Nothing is sent to CardJoy until you press Add item.
            </p>
          </CardContent>
        </Card>
      )}
    </div>
  );
};

export default withAuth(RegistryAdd);
