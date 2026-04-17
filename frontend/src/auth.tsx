import {
  createContext,
  ReactNode,
  useCallback,
  useContext,
  useEffect,
  useState,
} from "react";
import { api, ApiError, Me } from "./api";

type AuthState =
  | { status: "loading" }
  | { status: "needs-setup" }
  | { status: "anonymous" }
  | { status: "authenticated"; me: Me };

type Ctx = {
  state: AuthState;
  refresh: () => Promise<void>;
  login: (username: string, password: string) => Promise<void>;
  logout: () => Promise<void>;
  can: (permission: string) => boolean;
};

const AuthContext = createContext<Ctx | null>(null);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [state, setState] = useState<AuthState>({ status: "loading" });

  const refresh = useCallback(async () => {
    try {
      const status = await api.get<{ completed: boolean }>("/api/setup/status");
      if (!status.completed) {
        setState({ status: "needs-setup" });
        return;
      }
    } catch {
      setState({ status: "anonymous" });
      return;
    }
    try {
      const me = await api.get<Me>("/api/auth/me");
      setState({ status: "authenticated", me });
    } catch (err) {
      if (err instanceof ApiError && err.status === 401) {
        setState({ status: "anonymous" });
      } else {
        setState({ status: "anonymous" });
      }
    }
  }, []);

  useEffect(() => {
    refresh();
  }, [refresh]);

  const login = useCallback(
    async (username: string, password: string) => {
      await api.post<Me>("/api/auth/login", { username, password });
      await refresh();
    },
    [refresh]
  );

  const logout = useCallback(async () => {
    await api.post("/api/auth/logout");
    setState({ status: "anonymous" });
  }, []);

  const can = useCallback(
    (permission: string) =>
      state.status === "authenticated" &&
      state.me.permissions.includes(permission),
    [state]
  );

  return (
    <AuthContext.Provider value={{ state, refresh, login, logout, can }}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth(): Ctx {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error("useAuth must be used within AuthProvider");
  return ctx;
}
