import { BrowserRouter, Navigate, Route, Routes } from 'react-router-dom';
import { AuthProvider } from './context/AuthContext';
import { Layout } from './components/Layout';
import { ProtectedRoute } from './components/ProtectedRoute';
import { Login } from './pages/Login';
import { Dashboard } from './pages/Dashboard';
import { Contacts } from './pages/Contacts';
import { Company } from './pages/Company';
import { SwitchCompany } from './pages/SwitchCompany';
import { NewInvite } from './pages/NewInvite';
import { InviteDetail } from './pages/InviteDetail';
import { ClientPortal } from './pages/ClientPortal';
import { ClientInvite } from './pages/ClientInvite';
import ForgotPassword from './pages/ForgotPassword';
import ResetPassword from './pages/ResetPassword';

export function App() {
  return <BrowserRouter>
    <AuthProvider>
      <Routes>
        <Route path="/login" element={<Login />} />
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
          </Route>
        </Route>
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </AuthProvider>
  </BrowserRouter>;
}
