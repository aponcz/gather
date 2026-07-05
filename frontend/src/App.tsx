import { BrowserRouter, Navigate, Route, Routes } from 'react-router-dom';
import { AuthProvider } from './context/AuthContext';
import { Layout } from './components/Layout';
import { ProtectedRoute } from './components/ProtectedRoute';
import { AdminOnlyRoute } from './components/AdminOnlyRoute';
import { Login } from './pages/Login';
import { Dashboard } from './pages/Dashboard';
import { Contacts } from './pages/Contacts';
import { Company } from './pages/Company';
import { AdminDashboard } from './pages/AdminDashboard';
import { ManageUsers } from './pages/ManageUsers';
import { ManageCompanies } from './pages/ManageCompanies';
import { SwitchCompany } from './pages/SwitchCompany';
import { NewInvite } from './pages/NewInvite';
import { InviteDetail } from './pages/InviteDetail';
import { ClientPortal } from './pages/ClientPortal';
import { ClientInvite } from './pages/ClientInvite';
import { OAuthCallback } from './pages/OAuthCallback';
import ForgotPassword from './pages/ForgotPassword';
import ResetPassword from './pages/ResetPassword';

export function App() {
  return <BrowserRouter>
    <AuthProvider>
      <Routes>
        <Route path="/login" element={<Login />} />
        <Route path="/login/oauth-callback" element={<OAuthCallback />} />
        <Route path="/forgot-password" element={<ForgotPassword />} />
        <Route path="/reset-password/:token" element={<ResetPassword />} />
        <Route path="/client" element={<ClientPortal />} />
        <Route path="/client/invites/:publicToken" element={<ClientInvite />} />
        <Route element={<ProtectedRoute />}>
          <Route element={<Layout />}>
            <Route path="/" element={<Dashboard />} />
            <Route path="/contacts" element={<Contacts />} />
            <Route path="/company" element={<Company />} />
            <Route path="/switch-company" element={<SwitchCompany />} />
            <Route path="/invites/new" element={<NewInvite />} />
            <Route path="/invites/:id" element={<InviteDetail />} />
            <Route element={<AdminOnlyRoute />}>
              <Route path="/admin" element={<AdminDashboard />} />
              <Route path="/admin/users" element={<ManageUsers />} />
              <Route path="/admin/companies" element={<ManageCompanies />} />
            </Route>
          </Route>
        </Route>
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </AuthProvider>
  </BrowserRouter>;
}
