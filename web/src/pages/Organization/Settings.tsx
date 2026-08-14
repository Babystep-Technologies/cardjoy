import { useCallback, useEffect, useRef, useState } from 'react';
import { gql, useMutation, useQuery } from '@apollo/client';
import { Link } from 'react-router-dom';
import { Building2, LoaderCircle } from 'lucide-react';
import { Toaster, toast } from 'sonner';
import withAuth from '@/lib/with-auth';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Textarea } from '@/components/ui/textarea';
import { useOrganization } from '@/contexts/OrganizationContext';
import { uploadGraphQLMutation } from '@/lib/graphql-upload';
import { validateImageFile } from '@/lib/image-upload';
import DesignAssets from './components/DesignAssets';
import EmailBrandPreview from './components/EmailBrandPreview';

/**
 * Settings for the organization the user is currently acting in: its profile, the branding applied
 * to the email it sends, and its own design assets.
 *
 * Scoped to the active organization rather than addressed by id, so it inherits the switcher's
 * answer to "which organization am I in" — a user only ever reaches an organization they belong to.
 * Every mutation here is admin-only on the server; a plain member gets the same page read-only,
 * since seeing your organization's branding isn't the same as being able to change it.
 */

const ORGANIZATION_SETTINGS = gql`
  query OrganizationSettings {
    viewer {
      id
      activeOrganization {
        id
        name
        slug
        description
        logoUrl
        accentColor
        emailFooterText
        emailReplyTo
      }
    }
  }
`;

// The same mutation twice: as a string for the multipart upload path (a logo can only travel that
// way, see lib/graphql-upload.ts) and as a document for every other save.
const UPDATE_ORGANIZATION_DOCUMENT = `
  mutation UpdateOrganization($input: UpdateOrganizationInput!) {
    updateOrganization(input: $input) {
      organization {
        id
        name
        slug
        description
        logoUrl
        accentColor
        emailFooterText
        emailReplyTo
      }
      errors
    }
  }
`;

const UPDATE_ORGANIZATION = gql`
  ${UPDATE_ORGANIZATION_DOCUMENT}
`;

/** Organization::FOOTER_TEXT_MAX_LENGTH. */
const FOOTER_TEXT_MAX_LENGTH = 200;

type OrganizationSettingsData = {
  viewer: {
    id: string;
    activeOrganization: {
      id: string;
      name: string;
      slug: string;
      description: string | null;
      logoUrl: string | null;
      accentColor: string | null;
      emailFooterText: string | null;
      emailReplyTo: string | null;
    } | null;
  } | null;
};

type OrganizationSettings = NonNullable<
  NonNullable<OrganizationSettingsData['viewer']>['activeOrganization']
>;

const errorList = (errors: string[]) =>
  errors.length > 0 && (
    <ul className="space-y-1 text-sm font-medium text-red-600">
      {errors.map(error => (
        <li key={error}>{error}</li>
      ))}
    </ul>
  );

const OrganizationSettingsPage: React.FC = () => {
  const { activeOrganization, loading: organizationLoading } = useOrganization();
  const canEdit = activeOrganization?.role === 'admin';

  const { data, loading, refetch } = useQuery<OrganizationSettingsData>(ORGANIZATION_SETTINGS, {
    fetchPolicy: 'cache-and-network',
    skip: !activeOrganization,
  });
  const organization = data?.viewer?.activeOrganization ?? null;

  const [updateOrganization] = useMutation(UPDATE_ORGANIZATION);

  const [name, setName] = useState('');
  const [description, setDescription] = useState('');
  const [slug, setSlug] = useState('');
  const [accentColor, setAccentColor] = useState('');
  const [footerText, setFooterText] = useState('');
  const [replyTo, setReplyTo] = useState('');
  const [logoFile, setLogoFile] = useState<File | null>(null);
  const [logoPreviewUrl, setLogoPreviewUrl] = useState<string | null>(null);

  const [profileErrors, setProfileErrors] = useState<string[]>([]);
  const [brandErrors, setBrandErrors] = useState<string[]>([]);
  const [assetErrors, setAssetErrors] = useState<string[]>([]);
  const [savingProfile, setSavingProfile] = useState(false);
  const [savingBrand, setSavingBrand] = useState(false);

  const logoInput = useRef<HTMLInputElement>(null);

  // Seed the forms from the server once per organization. Re-seeding on every result would throw
  // away what the admin is typing whenever a refetch lands.
  const seededFor = useRef<string | null>(null);

  const applyOrganization = useCallback((loaded: OrganizationSettings) => {
    setName(loaded.name);
    setDescription(loaded.description ?? '');
    setSlug(loaded.slug);
    setAccentColor(loaded.accentColor ?? '');
    setFooterText(loaded.emailFooterText ?? '');
    setReplyTo(loaded.emailReplyTo ?? '');
  }, []);

  useEffect(() => {
    if (!organization || seededFor.current === organization.id) return;
    seededFor.current = organization.id;
    applyOrganization(organization);
  }, [organization, applyOrganization]);

  // Object URLs are held by the browser until they're released.
  useEffect(() => {
    return () => {
      if (logoPreviewUrl) URL.revokeObjectURL(logoPreviewUrl);
    };
  }, [logoPreviewUrl]);

  const handleLogoChange = (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    event.target.value = '';
    if (!file) return;

    const validationError = validateImageFile(file);
    if (validationError) {
      setBrandErrors([validationError]);
      return;
    }

    setBrandErrors([]);
    setLogoFile(file);
    if (logoPreviewUrl) URL.revokeObjectURL(logoPreviewUrl);
    setLogoPreviewUrl(URL.createObjectURL(file));
  };

  const clearPickedLogo = () => {
    setLogoFile(null);
    if (logoPreviewUrl) URL.revokeObjectURL(logoPreviewUrl);
    setLogoPreviewUrl(null);
  };

  const handleSaveProfile = async (event: React.FormEvent) => {
    event.preventDefault();
    if (!organization) return;

    setProfileErrors([]);
    setSavingProfile(true);

    try {
      const { data: result } = await updateOrganization({
        variables: {
          input: {
            organizationId: organization.id,
            name: name.trim(),
            description: description.trim(),
            slug: slug.trim(),
          },
        },
      });
      const errors: string[] = result?.updateOrganization?.errors ?? [];
      const saved: OrganizationSettings | null = result?.updateOrganization?.organization ?? null;

      if (errors.length > 0 || !saved) {
        setProfileErrors(errors.length > 0 ? errors : ['Could not save the profile.']);
        return;
      }

      applyOrganization(saved);
      toast.success('Profile saved.');
    } catch (error) {
      setProfileErrors([error instanceof Error ? error.message : 'Could not save the profile.']);
    } finally {
      setSavingProfile(false);
    }
  };

  const handleSaveBrand = async (event: React.FormEvent) => {
    event.preventDefault();
    if (!organization) return;

    setBrandErrors([]);
    setSavingBrand(true);

    // Empty strings rather than nulls: the server treats an empty string as "clear this field back
    // to CardJoy's default", which is exactly what an admin emptying the input means.
    const input: Record<string, unknown> = {
      organizationId: organization.id,
      accentColor: accentColor.trim(),
      emailFooterText: footerText.trim(),
      emailReplyTo: replyTo.trim(),
    };

    try {
      let saved: OrganizationSettings | null = null;
      let errors: string[] = [];

      if (logoFile) {
        const json = await uploadGraphQLMutation<{
          updateOrganization: { organization: OrganizationSettings | null; errors: string[] };
        }>({
          query: UPDATE_ORGANIZATION_DOCUMENT,
          input: { ...input, logo: null },
          filePath: 'variables.input.logo',
          file: logoFile,
          filename: logoFile.name,
        });

        if (json.errors?.length) {
          errors = json.errors.map(error => error.message);
        } else {
          saved = json.data?.updateOrganization.organization ?? null;
          errors = json.data?.updateOrganization.errors ?? [];
        }
      } else {
        const { data: result } = await updateOrganization({ variables: { input } });
        saved = result?.updateOrganization?.organization ?? null;
        errors = result?.updateOrganization?.errors ?? [];
      }

      if (errors.length > 0 || !saved) {
        setBrandErrors(errors.length > 0 ? errors : ['Could not save the branding.']);
        return;
      }

      applyOrganization(saved);
      clearPickedLogo();
      // The upload path bypasses Apollo, so the cache still holds the old logo URL.
      await refetch();
      toast.success('Email branding saved.');
    } catch (error) {
      setBrandErrors([error instanceof Error ? error.message : 'Could not save the branding.']);
    } finally {
      setSavingBrand(false);
    }
  };

  if (organizationLoading) {
    return (
      <div className="flex min-h-screen items-center justify-center">
        <LoaderCircle className="h-6 w-6 animate-spin text-gray-400" />
      </div>
    );
  }

  // Personal is a real context, not a missing organization — say so rather than 404ing.
  if (!activeOrganization) {
    return (
      <div className="mx-auto max-w-2xl px-4 pt-20 pb-12 text-center">
        <Building2 className="mx-auto h-10 w-10 text-gray-400" />
        <h1 className="mt-4 text-2xl font-bold text-black">No organization selected</h1>
        <p className="mt-2 text-gray-600">
          You're working in your personal context. Switch to an organization from the header to
          manage its settings.
        </p>
        <Button asChild className="mt-6">
          <Link to="/organizations/new">Create an organization</Link>
        </Button>
      </div>
    );
  }

  return (
    <div className="mx-auto max-w-5xl px-4 pt-12 pb-16">
      <Toaster />

      <header className="space-y-2">
        <h1 className="text-3xl font-bold text-black">{activeOrganization.name}</h1>
        <p className="text-gray-600">
          Profile, email branding, and design assets for this organization.
        </p>
        {!canEdit && (
          <p className="rounded-md bg-gray-50 px-3 py-2 text-sm text-gray-600">
            You're a member of this organization, so these settings are read-only. Ask an admin to
            make changes.
          </p>
        )}
      </header>

      {loading && !organization ? (
        <div className="flex justify-center py-16">
          <LoaderCircle className="h-6 w-6 animate-spin text-gray-400" />
        </div>
      ) : (
        <div className="mt-8 space-y-8">
          <Card>
            <CardHeader>
              <CardTitle>Profile</CardTitle>
              <CardDescription>How this organization appears across CardJoy.</CardDescription>
            </CardHeader>
            <CardContent>
              <form onSubmit={handleSaveProfile} className="max-w-xl space-y-5">
                <div className="space-y-2">
                  <Label htmlFor="organization-name">Name</Label>
                  <Input
                    id="organization-name"
                    value={name}
                    onChange={e => setName(e.target.value)}
                    maxLength={100}
                    disabled={!canEdit}
                    required
                  />
                </div>

                <div className="space-y-2">
                  <Label htmlFor="organization-description">Description</Label>
                  <Textarea
                    id="organization-description"
                    value={description}
                    onChange={e => setDescription(e.target.value)}
                    placeholder="What is this organization for?"
                    rows={3}
                    disabled={!canEdit}
                  />
                </div>

                <div className="space-y-2">
                  <Label htmlFor="organization-slug">Slug</Label>
                  <Input
                    id="organization-slug"
                    value={slug}
                    onChange={e => setSlug(e.target.value)}
                    maxLength={60}
                    disabled={!canEdit}
                    required
                  />
                  <p className="text-xs text-gray-500">
                    Lowercase letters, numbers, and hyphens. Links already shared use the current
                    slug, so changing it will break them.
                  </p>
                </div>

                {errorList(profileErrors)}

                {canEdit && (
                  <Button type="submit" disabled={savingProfile || name.trim() === ''}>
                    {savingProfile && <LoaderCircle className="h-4 w-4 animate-spin" />}
                    {savingProfile ? 'Saving...' : 'Save profile'}
                  </Button>
                )}
              </form>
            </CardContent>
          </Card>

          <Card>
            <CardHeader>
              <CardTitle>Email branding</CardTitle>
              <CardDescription>
                Applied to every email this organization's cards and invitations send. Anything left
                blank falls back to CardJoy's own branding.
              </CardDescription>
            </CardHeader>
            <CardContent>
              <div className="grid gap-8 lg:grid-cols-2">
                <form onSubmit={handleSaveBrand} className="space-y-5">
                  <div className="space-y-2">
                    <Label htmlFor="organization-logo">Logo</Label>
                    <input
                      ref={logoInput}
                      id="organization-logo"
                      type="file"
                      accept="image/png, image/jpeg, image/jpg, image/gif"
                      className="hidden"
                      onChange={handleLogoChange}
                      disabled={!canEdit}
                    />
                    <div className="flex flex-wrap items-center gap-3">
                      <Button
                        type="button"
                        variant="outline"
                        disabled={!canEdit}
                        onClick={() => logoInput.current?.click()}
                      >
                        {organization?.logoUrl || logoFile ? 'Replace logo' : 'Upload logo'}
                      </Button>
                      {logoFile && (
                        <>
                          <span className="max-w-[12rem] truncate text-sm text-gray-600">
                            {logoFile.name}
                          </span>
                          <Button type="button" variant="ghost" onClick={clearPickedLogo}>
                            Remove
                          </Button>
                        </>
                      )}
                    </div>
                    <p className="text-xs text-gray-500">PNG, JPG, or GIF • up to 10MB</p>
                  </div>

                  <div className="space-y-2">
                    <Label htmlFor="organization-accent-color">Accent color</Label>
                    <div className="flex items-center gap-3">
                      <input
                        type="color"
                        aria-label="Pick an accent color"
                        value={/^#[0-9a-fA-F]{6}$/.test(accentColor) ? accentColor : '#433c69'}
                        onChange={e => setAccentColor(e.target.value)}
                        disabled={!canEdit}
                        className="h-9 w-12 cursor-pointer rounded border border-gray-200 bg-white disabled:cursor-not-allowed"
                      />
                      <Input
                        id="organization-accent-color"
                        value={accentColor}
                        onChange={e => setAccentColor(e.target.value)}
                        placeholder="#433c69"
                        maxLength={7}
                        disabled={!canEdit}
                      />
                    </div>
                  </div>

                  <div className="space-y-2">
                    <Label htmlFor="organization-footer-text">Footer text</Label>
                    <Textarea
                      id="organization-footer-text"
                      value={footerText}
                      onChange={e => setFooterText(e.target.value)}
                      placeholder={`© ${new Date().getFullYear()} Your company`}
                      rows={2}
                      maxLength={FOOTER_TEXT_MAX_LENGTH}
                      disabled={!canEdit}
                    />
                  </div>

                  <div className="space-y-2">
                    <Label htmlFor="organization-reply-to">Reply-to address</Label>
                    <Input
                      id="organization-reply-to"
                      type="email"
                      value={replyTo}
                      onChange={e => setReplyTo(e.target.value)}
                      placeholder="people@yourcompany.com"
                      disabled={!canEdit}
                    />
                  </div>

                  {errorList(brandErrors)}

                  {canEdit && (
                    <Button type="submit" disabled={savingBrand}>
                      {savingBrand && <LoaderCircle className="h-4 w-4 animate-spin" />}
                      {savingBrand ? 'Saving...' : 'Save branding'}
                    </Button>
                  )}
                </form>

                <div className="space-y-2">
                  <p className="text-sm font-medium text-gray-700">Preview</p>
                  <EmailBrandPreview
                    organizationName={name || activeOrganization.name}
                    logoUrl={logoPreviewUrl ?? organization?.logoUrl ?? null}
                    accentColor={accentColor}
                    footerText={footerText}
                    replyTo={replyTo}
                  />
                </div>
              </div>
            </CardContent>
          </Card>

          <Card>
            <CardHeader>
              <CardTitle>Design assets</CardTitle>
              <CardDescription>
                Cover artwork only this organization can use, offered alongside CardJoy's gallery
                whenever a member picks a cover.
              </CardDescription>
            </CardHeader>
            <CardContent className="space-y-4">
              <DesignAssets
                organizationId={activeOrganization.id}
                canEdit={!!canEdit}
                onErrors={setAssetErrors}
                onSuccess={message => toast.success(message)}
              />
              {errorList(assetErrors)}
            </CardContent>
          </Card>
        </div>
      )}
    </div>
  );
};

export default withAuth(OrganizationSettingsPage);
