import { useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { useFeatureFlagEnabled } from 'posthog-js/react';

const Maintenance = () => {
  const navigate = useNavigate();
  const isMaintenance = useFeatureFlagEnabled(import.meta.env.VITE_MAINTENANCE_MODE_FEATURE_FLAG);

  useEffect(() => {
    if (!isMaintenance) {
      navigate('/', { replace: true });
    }
  }, [isMaintenance, navigate]);

  return (
    <div className="flex items-center justify-center min-h-screen text-center p-6">
      <div>
        <h1 className="text-3xl text-black font-bold mb-4">Site Under Maintenance</h1>
        <p className="text-lg text-gray-600">
          We're making some improvements. Please check back soon.
        </p>
      </div>
    </div>
  );
};

export default Maintenance;
