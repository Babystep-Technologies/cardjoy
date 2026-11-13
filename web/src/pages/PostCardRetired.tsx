import { Link } from 'react-router-dom';
import { Button } from '@/components/ui/button';

// Old /post-card and /postage links (bookmarks, emailed order links, in-flight Stripe
// return URLs) land here instead of a bare 404.
const PostCardRetired = () => (
  <div className="flex min-h-[60vh] items-center justify-center p-6 text-center">
    <div className="max-w-md">
      <h1 className="mb-4 text-3xl font-bold text-gray-900">Post Cards have been retired</h1>
      <p className="mb-6 text-lg text-gray-600">
        We&apos;re no longer offering printed and mailed post cards. Your group cards, 1-on-1 cards
        and invitations are all still here.
      </p>
      <Button asChild>
        <Link to="/dashboard">Go to your dashboard</Link>
      </Button>
    </div>
  </div>
);

export default PostCardRetired;
