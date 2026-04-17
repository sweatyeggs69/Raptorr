import { LogOut, Radio, Server, Settings as SettingsIcon, Shield, Users } from "lucide-react";
import { NavLink, Outlet, useNavigate } from "react-router-dom";
import { useAuth } from "../auth";

function NavItem({
  to,
  icon,
  label,
  show = true,
}: {
  to: string;
  icon: JSX.Element;
  label: string;
  show?: boolean;
}) {
  if (!show) return null;
  return (
    <NavLink
      to={to}
      className={({ isActive }) =>
        [
          "flex items-center gap-3 rounded-md px-3 py-2 text-sm transition",
          isActive
            ? "bg-ink-900 text-white"
            : "text-ink-600 hover:bg-ink-100 hover:text-ink-900",
        ].join(" ")
      }
    >
      {icon}
      <span>{label}</span>
    </NavLink>
  );
}

export default function Layout() {
  const { state, logout, can } = useAuth();
  const nav = useNavigate();

  if (state.status !== "authenticated") return null;
  const me = state.me;

  return (
    <div className="flex h-full">
      <aside className="flex w-60 flex-col border-r border-ink-200 bg-white">
        <div className="flex items-center gap-2 px-5 py-5">
          <div className="flex h-7 w-7 items-center justify-center rounded bg-ink-900 font-mono text-sm font-bold text-white">
            R
          </div>
          <div className="text-sm font-semibold tracking-tight text-ink-900">
            Raptorr
          </div>
        </div>
        <nav className="flex flex-1 flex-col gap-1 px-3">
          <NavItem
            to="/devices"
            icon={<Radio size={16} />}
            label="Devices"
            show={can("devices:read")}
          />
          <NavItem
            to="/hosts"
            icon={<Server size={16} />}
            label="Consoles"
            show={can("devices:read")}
          />
          <NavItem
            to="/users"
            icon={<Users size={16} />}
            label="Users"
            show={can("users:read")}
          />
          <NavItem
            to="/roles"
            icon={<Shield size={16} />}
            label="Roles"
            show={can("roles:read")}
          />
          <NavItem
            to="/settings"
            icon={<SettingsIcon size={16} />}
            label="Settings"
            show={can("settings:read")}
          />
        </nav>
        <div className="border-t border-ink-200 p-3">
          <div className="px-2 pb-2">
            <div className="text-sm font-medium text-ink-900">
              {me.user.username}
            </div>
            <div className="text-xs text-ink-500">{me.user.role}</div>
          </div>
          <button
            className="btn btn-ghost w-full justify-start"
            onClick={async () => {
              await logout();
              nav("/login");
            }}
          >
            <LogOut size={14} />
            Sign out
          </button>
        </div>
      </aside>
      <main className="flex-1 overflow-auto">
        <Outlet />
      </main>
    </div>
  );
}
