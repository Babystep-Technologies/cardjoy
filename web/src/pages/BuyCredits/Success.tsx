import { useLocation } from 'react-router-dom';
import { CheckCircle } from 'lucide-react';
import * as motion from 'motion/react-client';
import { Link } from 'react-router-dom';

const BuyCreditsSuccess: React.FC = () => {
  const location = useLocation();
  const searchParams = new URLSearchParams(location.search);
  const sessionId = searchParams.get('session_id');

  return (
    <div className="flex min-h-screen flex-col">
      <main className="flex-grow flex items-center justify-center px-4 py-20">
        <motion.div
          className="w-full max-w-xl text-center space-y-6"
          initial={{ opacity: 0, y: 24 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6 }}
        >
          <CheckCircle className="w-16 h-16 mx-auto text-green-500" strokeWidth={1.5} />
          <h1 className="text-3xl font-bold text-gray-900">Payment Successful</h1>
          <p className="text-gray-600">
            Your credits have been added to your account.
            {sessionId && (
              <>
                <br />
                <span className="text-xs text-gray-400">Session ID: {sessionId}</span>
              </>
            )}
          </p>
          <motion.div
            className="flex flex-col sm:flex-row justify-center items-center gap-4 sm:gap-6 pt-4"
            whileHover={{ scale: 1.02 }}
            whileTap={{ scale: 0.98 }}
          >
            <Link
              to="/group-card/new"
              className="w-full sm:w-auto bg-black text-white px-6 py-3 rounded-xl font-semibold text-lg transition-colors hover:bg-gray-800 shadow-md"
            >
              Create New Card
            </Link>
            <Link
              to="/profile"
              className="w-full sm:w-auto bg-gray-100 text-gray-700 px-6 py-3 rounded-xl font-medium text-lg transition-colors hover:bg-gray-200"
            >
              Go to Profile
            </Link>
          </motion.div>
        </motion.div>
      </main>
    </div>
  );
};

export default BuyCreditsSuccess;
