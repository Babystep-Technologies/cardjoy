import { useState } from 'react';
import { gql, useMutation, ApolloError } from '@apollo/client';
import { useNavigate } from 'react-router-dom';
import { Building2, LoaderCircle } from 'lucide-react';
import * as motion from 'motion/react-client';
import withAuth from '@/lib/with-auth';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Textarea } from '@/components/ui/textarea';
import { useOrganization } from '@/contexts/OrganizationContext';

const CREATE_ORGANIZATION = gql`
  mutation CreateOrganization($input: CreateOrganizationInput!) {
    createOrganization(input: $input) {
      organization {
        id
        name
        slug
      }
      errors
    }
  }
`;

const OrganizationNew: React.FC = () => {
  const navigate = useNavigate();
  const { switchOrganization } = useOrganization();
  const [name, setName] = useState('');
  const [description, setDescription] = useState('');
  const [errors, setErrors] = useState<string[]>([]);
  const [submitting, setSubmitting] = useState(false);

  const [createOrganization] = useMutation(CREATE_ORGANIZATION);

  const handleSubmit = async (event: React.FormEvent) => {
    event.preventDefault();
    setErrors([]);
    setSubmitting(true);

    try {
      const { data } = await createOrganization({
        variables: { input: { name: name.trim(), description: description.trim() || null } },
      });
      const result = data?.createOrganization;

      if (!result?.organization) {
        setErrors(result?.errors?.length ? result.errors : ['Could not create the organization.']);
        return;
      }

      // Creating an organization is how you join one, so land the user inside it rather than
      // leaving them in Personal looking at an organization they can't see.
      await switchOrganization(result.organization.id);
      navigate('/dashboard');
    } catch (error) {
      const err = error as ApolloError;
      setErrors([err.message || 'Unexpected error occurred.']);
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div className="min-h-screen flex flex-col items-center justify-start px-4 pt-20 pb-12">
      <motion.div
        className="w-full max-w-md space-y-8"
        initial={{ opacity: 0, y: 12 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.5 }}
      >
        <div className="space-y-3 text-center">
          <div className="flex justify-center">
            <Building2 className="w-10 h-10 text-gray-900" />
          </div>
          <h1 className="text-3xl font-bold text-black">Create an organization</h1>
          <p className="text-gray-600">
            Share credits, cards, and branding with your team. You'll be its first admin.
          </p>
        </div>

        <form onSubmit={handleSubmit} className="space-y-5">
          <div className="space-y-2">
            <Label htmlFor="organization-name">Name</Label>
            <Input
              id="organization-name"
              value={name}
              onChange={e => setName(e.target.value)}
              placeholder="Acme Corp"
              maxLength={100}
              required
            />
          </div>

          <div className="space-y-2">
            <Label htmlFor="organization-description">Description (optional)</Label>
            <Textarea
              id="organization-description"
              value={description}
              onChange={e => setDescription(e.target.value)}
              placeholder="What is this organization for?"
              rows={3}
            />
          </div>

          {errors.length > 0 && (
            <ul className="space-y-1 text-sm font-medium text-red-600">
              {errors.map(error => (
                <li key={error}>{error}</li>
              ))}
            </ul>
          )}

          <div className="flex items-center gap-3">
            <Button type="submit" disabled={submitting || name.trim() === ''}>
              {submitting && <LoaderCircle className="h-4 w-4 animate-spin" />}
              {submitting ? 'Creating...' : 'Create organization'}
            </Button>
            <Button type="button" variant="ghost" onClick={() => navigate(-1)}>
              Cancel
            </Button>
          </div>
        </form>
      </motion.div>
    </div>
  );
};

export default withAuth(OrganizationNew);
