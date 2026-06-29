import { BrowserRouter, Navigate, Route, Routes } from 'react-router-dom';
import { AuthProvider } from './context/AuthContext';
import { Layout } from './components/Layout';
import { ProtectedRoute } from './components/ProtectedRoute';
import { Login } from './pages/Login';
import { Dashboard } from './pages/Dashboard';
import { Contacts } from './pages/Contacts';
import { NewInvite } from './pages/NewInvite';
import { InviteDetail } from './pages/InviteDetail';
import { ClientPortal } from './pages/ClientPortal';
import { ClientInvite } from './pages/ClientInvite';

export function App() {
  return <BrowserRouter>
    <AuthProvider>
      <Routes>
        <Route path="/login" element={<Login />} />
        <Route path="/client" element={<ClientPortal />} />
        <Route path="/client/invites/:publicToken" element={<ClientInvite />} />
        <Route element={<ProtectedRoute />}>
          <Route element={<Layout />}>
            <Route path="/" element={<Dashboard />} />
            <Route path="/contacts" element={<Contacts />} />
            <Route path="/invites/new" element={<NewInvite />} />
            <Route path="/invites/:id" element={<InviteDetail />} />
          </Route>
        </Route>
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </AuthProvider>
  </BrowserRouter>;
}
