import { useState } from 'react';
import { Link } from 'react-router-dom';
import { useAuth } from '@/contexts/AuthContext';
import * as motion from 'motion/react-client';
import { useFeatureFlagEnabled } from 'posthog-js/react';
import { OccasionMegaMenu } from './OccasionMegaMenu';
import { ProductMenu } from './ProductMenu';

const Header: React.FC = () => {
  const { user, loading } = useAuth();
  const [menuOpen, setMenuOpen] = useState(false);
  const isStaging = import.meta.env.VITE_ENV === 'staging';
  const isMaintenance = useFeatureFlagEnabled(import.meta.env.VITE_MAINTENANCE_MODE_FEATURE_FLAG);

  if (loading) return null;

  return (
    <motion.div
      animate={{ opacity: [0, 1], y: [-50, 0] }}
      transition={{ duration: 0.5 }}
      className="fixed top-0 left-0 w-full z-50"
    >
      {/* Staging banner */}
      {isStaging && (
        <div className="bg-yellow-100 text-yellow-800 text-sm font-medium text-center px-3 py-2 shadow-sm sm:text-base">
          <strong>test mode:</strong> data is temporary and may be reset periodically.
        </div>
      )}

      {/* Maintenance banner */}
      {isMaintenance && (
        <div className="bg-red-100 text-red-800 text-sm font-medium text-center px-3 py-2 shadow-sm sm:text-base">
          <strong>maintenance mode:</strong> features may be temporarily unavailable.
        </div>
      )}

      {/* Main header */}
      <div className="bg-white shadow-md">
        <div className="max-w-screen-xl mx-auto px-4 sm:px-6 lg:px-10 h-16 flex items-center justify-between">
          {/* Logo */}
          <motion.div
            whileHover={{ scale: 1.1 }}
            transition={{ type: 'spring', stiffness: 300, damping: 15 }}
            className="flex items-center"
          >
            <Link to="/" className="flex items-center group">
              <svg
                className="h-10 w-auto"
                viewBox="0 0 408 118"
                fill="none"
                xmlns="http://www.w3.org/2000/svg"
              >
                <path
                  d="M43.5028 64.9927H61.5748C60.1578 79.7577 47.9918 90.0337 32.1638 90.0337C14.2098 90.0337 0.861816 77.2767 0.861816 59.7957C0.861816 42.4317 14.2098 29.6757 32.1638 29.6757C47.9918 29.6757 60.1578 39.9517 61.5748 54.7167H43.5028C42.5578 49.5187 38.0688 45.8567 32.2818 45.8567C24.0138 45.8567 19.1698 51.9997 19.1698 59.7957C19.1698 67.5917 24.0138 73.8507 32.2818 73.8507C38.0688 73.8507 42.5578 70.1897 43.5028 64.9927Z"
                  fill="black"
                />
                <path
                  d="M108.824 68.6537V50.9357C105.162 46.9207 101.146 45.8567 97.0119 45.8567C89.2159 45.8567 83.4279 51.8817 83.4279 59.7957C83.4279 67.7087 89.2159 73.7327 97.0119 73.7327C101.146 73.7327 105.162 72.6707 108.824 68.6537ZM127.959 31.2107V88.4977H108.824V85.4257C104.572 88.2607 99.4919 90.0337 93.1139 90.0337C77.6409 90.0337 64.6479 76.8037 64.6479 59.7957C64.6479 42.6677 77.6409 29.6747 93.1139 29.6747C99.4919 29.6747 104.572 31.3287 108.824 34.1637V31.2107H127.959Z"
                  fill="black"
                />
                <path
                  d="M175.209 48.4556C165.877 48.8096 159.972 51.2906 155.483 55.6606V88.4976H136.23V31.2106H155.483V37.3526C160.563 32.9816 166.705 30.2656 175.209 30.2656V48.4556Z"
                  fill="black"
                />
                <path
                  d="M219.74 68.8902V51.1722C216.078 47.1572 212.062 46.0932 207.928 46.0932C200.132 46.0932 194.344 52.1182 194.344 59.9132C194.344 67.9452 200.132 73.9692 207.928 73.9692C212.062 73.9692 216.078 72.9062 219.74 68.8902ZM238.875 4.63419V88.4972H219.74V85.6622C215.488 88.3792 210.408 90.0342 204.03 90.0342C188.557 90.0342 175.564 77.0402 175.564 59.9132C175.564 42.9042 188.557 29.9112 204.03 29.9112C210.408 29.9112 215.488 31.5652 219.74 34.4002V4.63419H238.875Z"
                  fill="black"
                />
                <path
                  d="M245.493 11.4847C245.493 5.22368 250.572 0.617683 256.714 0.617683C262.974 0.617683 267.935 5.22368 267.935 11.4847C267.935 17.6267 262.974 22.2337 256.714 22.2337C250.572 22.2337 245.493 17.6267 245.493 11.4847ZM266.4 88.7337C266.4 106.452 260.848 116.728 238.17 117.201L236.516 101.255C244.903 100.428 247.147 97.9467 247.147 91.3327V31.2107H266.4V88.7337Z"
                  fill="black"
                />
                <path
                  d="M407.398 31.2105L371.726 115.782H351.646L363.576 87.3165L335.583 31.2105H355.898L372.199 66.7645L387.201 31.2105H407.398Z"
                  fill="black"
                />
                <g className="animate-brand-cycle" fill="currentColor" stroke="currentColor">
                  <path d="M304.791 73.6599L305.458 72.5603L305.708 73.822L309.159 91.2058L318.467 89.2966L316.42 72.6658L316.286 71.571L317.198 72.1912L329.905 80.8328L334.919 72.4753L321.353 62.4919L320.511 61.8728L321.521 61.6062L335.083 58.0242V51.6111L318.028 53.6472L316.925 53.7791L317.558 52.866L328.581 36.9695L322.792 32.8074L310.734 47.6814L309.845 48.7771V26.572H298.751V48.4714L297.96 47.905L283.062 37.2449L275.589 44.9597L291.47 58.0222L292.131 58.5662L291.333 58.8748L275.423 65.0339L277.851 77.4089L293.575 70.2449L294.816 69.6794L294.234 70.9128L285.26 89.9509L293.046 93.0173L304.791 73.6599Z" />
                  <path d="M303.652 80.115L304.319 79.0154L304.57 80.2771L307.295 94.0115L321.092 91.1824L319.417 77.575L319.282 76.4802L320.194 77.1003L330.648 84.2097L338.067 71.8435L326.757 63.5203L325.916 62.9011L326.926 62.6345L337.457 59.8523V48.9363L322.986 50.6648L321.883 50.7957L322.517 49.8826L331.862 36.405L322.358 29.571L313.107 40.9832L312.22 42.0789V24.198H296.376V43.8523L295.586 43.2869L282.78 34.1248L272.093 45.157L286.825 57.2761L287.486 57.8191L286.688 58.1277L272.711 63.5378L276.1 80.8162L288.665 75.0896L289.906 74.5242L289.325 75.7576L282.031 91.2312L294.038 95.9607L303.652 80.115ZM333.708 56.9656L333.336 57.0642L317.384 61.2781L332.73 72.571L333.098 72.8406L332.863 73.2312L329.748 78.4236L329.476 78.8777L329.038 78.5798L314.552 68.7302L316.892 87.7468L316.948 88.2048L316.496 88.2976L310.732 89.4802L310.239 89.5818L310.141 89.0886L306.117 68.824L292.692 90.9539L292.474 91.3142L292.081 91.1599L287.626 89.4041L287.13 89.2087L287.357 88.7253L297.657 66.8748L279.441 75.1726L278.865 75.4353L278.744 74.8142L277.076 66.3103L276.995 65.8992L277.386 65.7478L294.82 58.9988L278.033 45.1892L277.614 44.8445L277.991 44.4548L282.927 39.3621L283.227 39.0525L283.576 39.3035L300.125 51.1453V27.946H308.471V52.655L322.746 35.0466L323.043 34.6804L323.427 34.9558L326.284 37.0105L326.684 37.2976L326.403 37.7019L314.054 55.5066L333.149 53.2253L333.708 53.1589V56.9656Z" />
                </g>
              </svg>
            </Link>
          </motion.div>

          {/* Desktop Nav */}
          <div className="hidden sm:flex items-center gap-6 text-base">
            {!user && (
              <>
                <ProductMenu />
                <OccasionMegaMenu />
                <Link
                  to="/for-teams"
                  className="text-gray-600 hover:text-gray-900 transition font-medium text-base"
                >
                  For Teams
                </Link>
              </>
            )}
            {user ? (
              <div className="flex items-center gap-4">
                <Link to="/dashboard" className="text-black text-bold text-xl transition">
                  Dashboard
                </Link>
                <Link to="/profile" className="text-black text-bold text-xl transition">
                  Profile
                </Link>
              </div>
            ) : (
              <div className="flex items-center gap-4">
                <Link to="/sign_in" className="text-gray-600 hover:text-gray-900 transition">
                  Sign In
                </Link>
                <Link
                  to="/sign_up"
                  className="bg-black text-white px-4 py-2 rounded-md font-semibold hover:bg-gray-800 transition"
                >
                  Sign Up Free
                </Link>
              </div>
            )}
          </div>

          {/* Mobile hamburger */}
          <button
            onClick={() => setMenuOpen(!menuOpen)}
            className="sm:hidden flex items-center justify-center w-10 h-10 text-2xl text-gray-700 rounded-md focus:outline-none focus:ring-2 focus:ring-gray-300"
            aria-label={menuOpen ? 'Close menu' : 'Open menu'}
          >
            <span aria-hidden="true">{menuOpen ? '✕' : '☰'}</span>
          </button>
        </div>

        {/* Mobile Dropdown */}
        {menuOpen && (
          <motion.div
            animate={{ opacity: [0, 1], height: ['0px', 'auto'] }}
            transition={{ duration: 0.3 }}
            className="sm:hidden w-full px-4 pb-4 bg-white shadow-inner overflow-hidden"
          >
            <div className="flex flex-col gap-3 mt-4 text-base">
              {user ? (
                <>
                  <Link
                    to="/dashboard"
                    onClick={() => setMenuOpen(false)}
                    className="text-gray-600 hover:text-gray-900 text-center"
                  >
                    Dashboard
                  </Link>
                  <Link
                    to="/profile"
                    onClick={() => setMenuOpen(false)}
                    className="bg-black text-white px-4 py-2 rounded-md font-semibold text-center hover:bg-gray-800 transition"
                  >
                    Profile
                  </Link>
                </>
              ) : (
                <>
                  <Link
                    to="/group-card/new"
                    onClick={() => setMenuOpen(false)}
                    className="text-gray-600 hover:text-gray-900 text-center"
                  >
                    Group Cards
                  </Link>
                  <Link
                    to="/invitation/new"
                    onClick={() => setMenuOpen(false)}
                    className="text-gray-600 hover:text-gray-900 text-center"
                  >
                    Invitations
                  </Link>
                  <Link
                    to="/occasions"
                    onClick={() => setMenuOpen(false)}
                    className="text-gray-600 hover:text-gray-900 text-center"
                  >
                    Occasions
                  </Link>
                  <Link
                    to="/for-teams"
                    onClick={() => setMenuOpen(false)}
                    className="text-gray-600 hover:text-gray-900 text-center"
                  >
                    For Teams
                  </Link>
                  <Link
                    to="/sign_in"
                    onClick={() => setMenuOpen(false)}
                    className="text-gray-600 hover:text-gray-900 text-center"
                  >
                    Sign In
                  </Link>
                  <Link
                    to="/sign_up"
                    onClick={() => setMenuOpen(false)}
                    className="bg-black text-white px-4 py-2 rounded-md font-semibold text-center hover:bg-gray-800 transition"
                  >
                    Sign Up Free
                  </Link>
                </>
              )}
            </div>
          </motion.div>
        )}
      </div>
    </motion.div>
  );
};

export default Header;
