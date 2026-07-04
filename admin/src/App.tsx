import Home from '@/pages/Home';
import Dashboard from '@/pages/Dashboard';
import ManageStyles from '@/pages/styles/ManageStyles';
import ManageCards from '@/pages/cards/ManageCards';
import ManageUsers from '@/pages/users/ManageUsers';
import AdminCard from '@/pages/cards/AdminCard';
import ManageInvitations from '@/pages/invitations/ManageInvitations';
import AdminInvitation from '@/pages/invitations/AdminInvitation';
import SignIn from '@/pages/SignIn';
import { Routes, Route } from 'react-router-dom';
import RootLayout from '@/components/RootLayout';

const App: React.FC = () => {
  return (
    <RootLayout>
      <Routes>
        <Route path="/" element={<Home />}>
          <Route index element={<Dashboard />} />
          <Route path="styles" element={<ManageStyles />} />
          <Route path="cards" element={<ManageCards />} />
          <Route path="invitations" element={<ManageInvitations />} />
          <Route path="users" element={<ManageUsers />} />
          <Route path="credits" element={<div>Manage Credits & Promos</div>} />
        </Route>
        <Route path="/card/:cardExternalId" element={<AdminCard />} />
        <Route path="/invitation/:externalId" element={<AdminInvitation />} />
        <Route path="/sign_in" element={<SignIn />} />
      </Routes>
    </RootLayout>
  );
};

export default App;
