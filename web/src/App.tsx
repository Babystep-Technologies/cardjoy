import React from 'react';
import { Routes, Route, Navigate, useLocation } from 'react-router-dom';
import { useFeatureFlagEnabled } from 'posthog-js/react';
import Home from '@/pages/Home';
import SignIn from '@/pages/SignIn';
import SignUp from '@/pages/SignUp';
import ForgotPassword from '@/pages/ForgotPassword';
import ResetPassword from '@/pages/ResetPassword';
import RootLayout from '@/layouts/RootLayout';
import VerifyEmail from '@/pages/VerifyEmail';
import Profile from '@/pages/Profile';
import BuyCredits from '@/pages/BuyCredits';
import BuyCreditsCancel from '@/pages/BuyCredits/Cancel';
import BuyCreditsSuccess from '@/pages/BuyCredits/Success';
import RedeemPromo from '@/pages/RedeemPromo';
import Dashboard from '@/pages/Dashboard';
import CardNew from '@/pages/Card/New';
import CardOneOnOneNew from '@/pages/Card/OneOnOneNew';
import CardEdit from '@/pages/Card/Edit';
import CardEditable from '@/pages/Card/Editable';
import CardViewable from '@/pages/Card/Viewable';
import InvitationNew from '@/pages/Invitation/New';
import InvitationView from '@/pages/Invitation/View';
import InvitationEdit from '@/pages/Invitation/Edit';
import Maintenance from '@/pages/Maintenance';
import Careers from '@/pages/Careers';
import ForTeams from '@/pages/ForTeams';
import ConnectSlack from '@/pages/ConnectSlack';
import Occasions from '@/pages/Occasions';
import Contacts from '@/pages/Contacts/Index';
import PrivacyPolicy from './pages/PrivacyPolicy';
import TermsOfService from './pages/TermsOfService';
import Disclaimer from './pages/Disclaimer';
import UserPolicy from './pages/UserPolicy';
import {
  EventLandingPage,
  valentinesDayConfig,
  birthdayConfig,
  weddingConfig,
  babyShowerConfig,
  graduationConfig,
  newJobConfig,
  jobFarewellConfig,
} from './pages/events';

const MaintenanceGate: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const isMaintenance = useFeatureFlagEnabled(import.meta.env.VITE_MAINTENANCE_MODE_FEATURE_FLAG);
  const location = useLocation();

  if (isMaintenance && location.pathname !== '/maintenance') {
    return <Navigate to="/maintenance" replace />;
  }

  return <>{children}</>;
};

/** Permanent redirect for a renamed route, preserving any query string (e.g. ?occasion=). */
const LegacyRedirect: React.FC<{ to: string }> = ({ to }) => {
  const { search } = useLocation();
  return <Navigate to={`${to}${search}`} replace />;
};

const App: React.FC = () => {
  return (
    <RootLayout>
      <MaintenanceGate>
        <Routes>
          <Route path="/" element={<Home />} />
          <Route path="/maintenance" element={<Maintenance />} />
          <Route path="/sign_in" element={<SignIn />} />
          <Route path="/sign_up" element={<SignUp />} />
          <Route path="/forgot_password" element={<ForgotPassword />} />
          <Route path="/reset_password" element={<ResetPassword />} />
          <Route path="/verify_email" element={<VerifyEmail />} />
          <Route path="/profile" element={<Profile />} />
          <Route path="/buy_credits" element={<BuyCredits />} />
          <Route path="/buy_credits/cancel" element={<BuyCreditsCancel />} />
          <Route path="/buy_credits/success" element={<BuyCreditsSuccess />} />
          <Route path="/redeem" element={<RedeemPromo />} />
          <Route path="/dashboard" element={<Dashboard />} />
          <Route path="/contacts" element={<Contacts />} />

          <Route path="/group-card/new" element={<CardNew />} />
          <Route path="/one-on-one-card/new" element={<CardOneOnOneNew />} />
          {/* Legacy paths — keep old links / indexed URLs working */}
          <Route path="/card/new" element={<LegacyRedirect to="/group-card/new" />} />
          <Route
            path="/card/one-on-one/new"
            element={<LegacyRedirect to="/one-on-one-card/new" />}
          />
          <Route path="/card/:cardExternalId/edit" element={<CardEdit />} />
          <Route path="/card/:cardExternalId/viewable" element={<CardViewable />} />
          <Route path="/card/:cardExternalId/editable" element={<CardEditable />} />

          <Route path="/invitation/new" element={<InvitationNew />} />
          <Route path="/invitation/:id" element={<InvitationView />} />
          <Route path="/invitation/:id/edit" element={<InvitationEdit />} />

          <Route
            path="/for/valentines-day"
            element={<EventLandingPage config={valentinesDayConfig} />}
          />
          <Route path="/for/birthday" element={<EventLandingPage config={birthdayConfig} />} />
          <Route path="/for/wedding" element={<EventLandingPage config={weddingConfig} />} />
          <Route path="/for/baby-shower" element={<EventLandingPage config={babyShowerConfig} />} />
          <Route path="/for/graduation" element={<EventLandingPage config={graduationConfig} />} />
          <Route path="/for/new-job" element={<EventLandingPage config={newJobConfig} />} />
          <Route
            path="/for/job-farewell"
            element={<EventLandingPage config={jobFarewellConfig} />}
          />

          <Route path="/connect-slack" element={<ConnectSlack />} />
          <Route path="/occasions" element={<Occasions />} />
          <Route path="/for-teams" element={<ForTeams />} />
          <Route path="/careers" element={<Careers />} />
          <Route path="/privacy" element={<PrivacyPolicy />} />
          <Route path="/terms" element={<TermsOfService />} />
          <Route path="/disclaimer" element={<Disclaimer />} />
          <Route path="/user-policy" element={<UserPolicy />} />
        </Routes>
      </MaintenanceGate>
    </RootLayout>
  );
};

export default App;
