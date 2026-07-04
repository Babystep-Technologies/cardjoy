// components/CardNotFound.tsx

import React from 'react';
import { Link } from 'react-router-dom';
import { Button } from '@/components/ui/button';

const CardNotFound: React.FC = () => {
  return (
    <div className="min-h-screen flex flex-col items-center justify-center text-center px-4 py-20">
      <h1 className="text-3xl sm:text-4xl font-bold mb-4">Card Not Found</h1>
      <p className="text-gray-600 mb-6 max-w-md">
        {`The card you're looking for doesn’t exist or may have been deleted.`}
      </p>
      <Link to="/">
        <Button>Back to Main Page</Button>
      </Link>
    </div>
  );
};

export default CardNotFound;
