import { Outlet } from 'react-router-dom';
import Sidebar from '@/components/Sidebar';
import withAuth from '@/lib/with-auth';

function Home() {
  return (
    <div className="flex min-h-screen text-muted-foreground">
      <Sidebar />
      <div className="flex flex-col flex-grow">
        <main className="flex-grow px-4 sm:px-6 py-6">
          <Outlet />
        </main>
      </div>
    </div>
  );
}

export default withAuth(Home);
