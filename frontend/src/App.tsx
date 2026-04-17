import { Navigate, Route, Routes } from "react-router-dom";
import { AuthProvider, useAuth } from "./auth";
import Layout from "./components/Layout";
import DevicesPage from "./pages/Devices";
import LoginPage from "./pages/Login";
import RolesPage from "./pages/Roles";
import SettingsPage from "./pages/Settings";
import SetupPage from "./pages/Setup";
import UsersPage from "./pages/Users";

function Gate({ children }: { children: JSX.Element }) {
  const { state } = useAuth();
  if (state.status === "loading") {
    return (
      <div className="flex h-full items-center justify-center text-sm text-ink-500">
        Loading…
      </div>
    );
  }
  if (state.status === "needs-setup") return <Navigate to="/setup" replace />;
  if (state.status === "anonymous") return <Navigate to="/login" replace />;
  return children;
}

function Public({ children }: { children: JSX.Element }) {
  const { state } = useAuth();
  if (state.status === "loading") return null;
  if (state.status === "needs-setup") return <Navigate to="/setup" replace />;
  if (state.status === "authenticated") return <Navigate to="/" replace />;
  return children;
}

function SetupGate({ children }: { children: JSX.Element }) {
  const { state } = useAuth();
  if (state.status === "loading") return null;
  if (state.status !== "needs-setup") return <Navigate to="/" replace />;
  return children;
}

export default function App() {
  return (
    <AuthProvider>
      <Routes>
        <Route
          path="/setup"
          element={
            <SetupGate>
              <SetupPage />
            </SetupGate>
          }
        />
        <Route
          path="/login"
          element={
            <Public>
              <LoginPage />
            </Public>
          }
        />
        <Route
          path="/"
          element={
            <Gate>
              <Layout />
            </Gate>
          }
        >
          <Route index element={<Navigate to="/devices" replace />} />
          <Route path="devices" element={<DevicesPage />} />
          <Route path="users" element={<UsersPage />} />
          <Route path="roles" element={<RolesPage />} />
          <Route path="settings" element={<SettingsPage />} />
        </Route>
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </AuthProvider>
  );
}
