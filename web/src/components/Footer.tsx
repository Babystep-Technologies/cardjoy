import { Link } from 'react-router-dom';
import { Github } from 'lucide-react';
import { GITHUB_REPO_URL } from '@/lib/constants';

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

        {/* Column 2: Explore */}
        <div className="space-y-3">
          <h4 className="font-semibold text-gray-900 text-lg">Explore</h4>
          <ul className="space-y-2">
            <li>
              <Link to="https://blog.cardjoy.app" className="hover:underline">
                Blog
              </Link>
            </li>
            <li>
              <Link to="/buy_credits" className="hover:underline">
                Pricing
              </Link>
            </li>
            <li>
              <Link to="/careers" className="hover:underline">
                Careers
              </Link>
            </li>
            <li>
              <a
                href={GITHUB_REPO_URL}
                target="_blank"
                rel="noopener noreferrer"
                className="inline-flex items-center gap-1.5 hover:underline"
              >
                <Github className="w-4 h-4" />
                Open Source
              </a>
            </li>
          </ul>
        </div>

        {/* Column 3: Legal */}
        <div className="space-y-3">
          <h4 className="font-semibold text-gray-900 text-lg">Legal</h4>
          <ul className="space-y-2">
            <li>
              <Link to="/privacy" className="hover:underline">
                Privacy Policy
              </Link>
            </li>
            <li>
              <Link to="/terms" className="hover:underline">
                Terms of Service
              </Link>
            </li>
            <li>
              <Link to="/disclaimer" className="hover:underline">
                Disclaimer
              </Link>
            </li>
            <li>
              <Link to="/user-policy" className="hover:underline">
                User Policy
              </Link>
            </li>
          </ul>
        </div>
      </div>
    </footer>
  );
};

export default Footer;
