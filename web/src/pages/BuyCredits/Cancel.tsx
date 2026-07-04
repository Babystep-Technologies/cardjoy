import { XCircle } from 'lucide-react';
import * as motion from 'motion/react-client';
import { Link } from 'react-router-dom';

const BuyCreditsCancel: React.FC = () => {
  return (
    <div className="flex min-h-screen flex-col">
      <main className="flex-grow flex items-center justify-center px-4 py-20">
        <motion.div
          className="w-full max-w-xl text-center space-y-6"
          initial={{ opacity: 0, y: 24 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6 }}
        >
          <XCircle className="w-16 h-16 mx-auto text-red-500" strokeWidth={1.5} />
          <h1 className="text-3xl font-bold text-gray-900">Purchase Cancelled</h1>
          <p className="text-gray-600">
            Your payment was not completed. You can try again anytime.
          </p>
          <motion.div whileHover={{ scale: 1.05 }} whileTap={{ scale: 0.97 }}>
            <Link
              to="/profile"
              className="inline-block bg-black text-white px-6 py-3 rounded-xl font-medium text-lg transition-colors hover:bg-gray-800"
            >
              Back to Profile
            </Link>
          </motion.div>
        </motion.div>
      </main>
    </div>
  );
};

export default BuyCreditsCancel;
