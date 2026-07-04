import { Link } from 'react-router-dom';
import { Instagram, Twitter, Music2 } from 'lucide-react'; // Music2 used as a TikTok icon substitute

const Footer: React.FC = () => {
  const year = new Date().getFullYear();

  return (
    <footer className="bg-white border-t mt-auto">
      <div className="max-w-screen-xl mx-auto px-6 py-12 grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 gap-12 text-md text-gray-700">
        {/* Column 1: Logo + Rights */}
        <div className="space-y-4">
          <Link to="/" className="inline-block">
            <img
              src="/font-logo.svg"
              alt="CardJoy Logo"
              width={140}
              height={30}
              className="grayscale opacity-70"
            />
          </Link>
          <p className="text-sm text-gray-500 leading-relaxed">
            &copy; {year} BabyStep Technologies, Inc. <br />
            All rights reserved.
          </p>
        </div>

        {/* Column 2: Socials */}
        <div className="space-y-3">
          <h4 className="font-semibold text-gray-900 text-lg">Our Socials</h4>
          <ul className="space-y-2">
            <li>
              <Link to="#" className="hover:underline flex items-center gap-2">
                <Instagram className="w-4 h-4" />
                Instagram
              </Link>
            </li>
            <li>
              <Link to="#" className="hover:underline flex items-center gap-2">
                <Music2 className="w-4 h-4" />
                TikTok
              </Link>
            </li>
            <li>
              <Link to="#" className="hover:underline flex items-center gap-2">
                <Twitter className="w-4 h-4" />X
              </Link>
            </li>
          </ul>
        </div>

        {/* Column 3: Other Quick Links */}
        <div className="space-y-3">
          <h4 className="font-semibold text-gray-900 text-lg">Other Quick Links</h4>
          <ul className="space-y-2">
            <li>
              <Link to="#" className="hover:underline">
                Basecamp
              </Link>
            </li>
            <li>
              <Link to="#" className="hover:underline">
                Freshdesk
              </Link>
            </li>
            <li>
              <Link to="#" className="hover:underline">
                PostHog
              </Link>
            </li>
          </ul>
        </div>
      </div>
    </footer>
  );
};

export default Footer;
