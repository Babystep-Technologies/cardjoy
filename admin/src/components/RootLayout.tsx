import React from 'react';
import Footer from '@/components/Footer';

const RootLayout: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const isStaging = import.meta.env.VITE_ENV === 'staging';

  return (
    <div className="min-h-screen w-full bg-gray-50 text-gray-900 antialiased flex flex-col">
      {isStaging && (
        <div className="bg-yellow-100 text-yellow-800 text-sm text-center py-2 px-4 shadow-sm">
          <strong>test mode:</strong> data is temporary and may be reset periodically.
        </div>
      )}
      <main className="flex-grow pt-4">{children}</main>
      <Footer />
    </div>
  );
};

export default RootLayout;
