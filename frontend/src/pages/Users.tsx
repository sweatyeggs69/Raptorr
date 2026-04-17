import { Plus, Trash2 } from "lucide-react";
import { FormEvent, useCallback, useEffect, useState } from "react";
import { api, ApiError } from "../api";
import { useAuth } from "../auth";
import Modal from "../components/Modal";
import PageHeader from "../components/PageHeader";

type User = {
  id: number;
  username: string;
  email: string | null;
  role_id: number;
  role: string | null;
  disabled: boolean;
  created_at: string;
  last_login: string | null;
};

type Role = {
  id: number;
  name: string;
  description: string;
  builtin: boolean;
  permissions: string[];
};

export default function UsersPage() {
  const { can, state } = useAuth();
  const canManage = can("users:manage");
  const currentUserId =
    state.status === "authenticated" ? state.me.user.id : null;

  const [users, setUsers] = useState<User[]>([]);
  const [roles, setRoles] = useState<Role[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [creating, setCreating] = useState(false);
  const [editing, setEditing] = useState<User | null>(null);

  const load = useCallback(async () => {
    setError(null);
    try {
      const [u, r] = await Promise.all([
        api.get<User[]>("/api/users"),
        can("roles:read")
          ? api.get<Role[]>("/api/roles")
          : Promise.resolve<Role[]>([]),
      ]);
      setUsers(u);
      setRoles(r);
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "Load failed");
    }
  }, [can]);

  useEffect(() => {
    load();
  }, [load]);

  return (
    <div>
      <PageHeader
        title="Users"
        subtitle="Accounts that can sign in to Raptorr."
        actions={
          canManage && (
            <button className="btn btn-primary" onClick={() => setCreating(true)}>
              <Plus size={14} />
              New user
            </button>
          )
        }
      />
      <div className="px-8 py-6">
        {error && (
          <div className="mb-4 rounded-md border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-800">
            {error}
          </div>
        )}
        <div className="card overflow-hidden">
          <table className="w-full border-collapse">
            <thead>
              <tr>
                <th className="th">Username</th>
                <th className="th">Email</th>
                <th className="th">Role</th>
                <th className="th">Status</th>
                <th className="th">Last login</th>
                <th className="th"></th>
              </tr>
            </thead>
            <tbody>
              {users.map((u) => (
                <tr
                  key={u.id}
                  className="border-t border-ink-100 hover:bg-ink-50"
                >
                  <td className="td font-medium">{u.username}</td>
                  <td className="td text-ink-500">{u.email || "—"}</td>
                  <td className="td">{u.role || "—"}</td>
                  <td className="td">
                    {u.disabled ? (
                      <span className="badge badge-bad">Disabled</span>
                    ) : (
                      <span className="badge badge-ok">Active</span>
                    )}
                  </td>
                  <td className="td text-ink-500">
                    {u.last_login
                      ? new Date(u.last_login).toLocaleString()
                      : "Never"}
                  </td>
                  <td className="td text-right">
                    {canManage && (
                      <button
                        className="btn btn-ghost"
                        onClick={() => setEditing(u)}
                      >
                        Edit
                      </button>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {creating && (
        <CreateUserModal
          roles={roles}
          onClose={() => setCreating(false)}
          onCreated={async () => {
            setCreating(false);
            await load();
          }}
        />
      )}
      {editing && (
        <EditUserModal
          user={editing}
          roles={roles}
          currentUserId={currentUserId}
          onClose={() => setEditing(null)}
          onChanged={async () => {
            setEditing(null);
            await load();
          }}
        />
      )}
    </div>
  );
}

function CreateUserModal({
  roles,
  onClose,
  onCreated,
}: {
  roles: Role[];
  onClose: () => void;
  onCreated: () => void;
}) {
  const [username, setUsername] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [roleId, setRoleId] = useState<number | "">("");
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  async function onSubmit(e: FormEvent) {
    e.preventDefault();
    setError(null);
    setBusy(true);
    try {
      await api.post("/api/users", {
        username: username.trim(),
        email: email.trim() || null,
        password,
        role_id: roleId,
      });
      onCreated();
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "Create failed");
    } finally {
      setBusy(false);
    }
  }

  return (
    <Modal
      open
      onClose={onClose}
      title="New user"
      footer={
        <>
          <button className="btn" onClick={onClose}>
            Cancel
          </button>
          <button
            className="btn btn-primary"
            onClick={onSubmit as any}
            disabled={busy}
          >
            Create
          </button>
        </>
      }
    >
      <form onSubmit={onSubmit} className="space-y-3">
        <div>
          <label className="label">Username</label>
          <input
            className="input"
            value={username}
            onChange={(e) => setUsername(e.target.value)}
            required
          />
        </div>
        <div>
          <label className="label">Email</label>
          <input
            className="input"
            type="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
          />
        </div>
        <div>
          <label className="label">Password</label>
          <input
            className="input"
            type="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            required
            minLength={8}
          />
        </div>
        <div>
          <label className="label">Role</label>
          <select
            className="input"
            value={roleId}
            onChange={(e) =>
              setRoleId(e.target.value ? parseInt(e.target.value, 10) : "")
            }
            required
          >
            <option value="">Select a role…</option>
            {roles.map((r) => (
              <option key={r.id} value={r.id}>
                {r.name}
              </option>
            ))}
          </select>
        </div>
        {error && (
          <div className="rounded-md border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-800">
            {error}
          </div>
        )}
      </form>
    </Modal>
  );
}

function EditUserModal({
  user,
  roles,
  currentUserId,
  onClose,
  onChanged,
}: {
  user: User;
  roles: Role[];
  currentUserId: number | null;
  onClose: () => void;
  onChanged: () => void;
}) {
  const [email, setEmail] = useState(user.email || "");
  const [password, setPassword] = useState("");
  const [roleId, setRoleId] = useState(user.role_id);
  const [disabled, setDisabled] = useState(user.disabled);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const isSelf = user.id === currentUserId;

  async function onSave() {
    setError(null);
    setBusy(true);
    try {
      await api.patch(`/api/users/${user.id}`, {
        email: email.trim() || null,
        password: password || undefined,
        role_id: roleId,
        disabled,
      });
      onChanged();
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "Update failed");
    } finally {
      setBusy(false);
    }
  }

  async function onDelete() {
    if (!confirm(`Delete user "${user.username}"?`)) return;
    setError(null);
    setBusy(true);
    try {
      await api.del(`/api/users/${user.id}`);
      onChanged();
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "Delete failed");
    } finally {
      setBusy(false);
    }
  }

  return (
    <Modal
      open
      onClose={onClose}
      title={`Edit ${user.username}`}
      footer={
        <>
          {!isSelf && (
            <button
              className="btn btn-danger mr-auto"
              onClick={onDelete}
              disabled={busy}
            >
              <Trash2 size={14} />
              Delete
            </button>
          )}
          <button className="btn" onClick={onClose}>
            Cancel
          </button>
          <button
            className="btn btn-primary"
            onClick={onSave}
            disabled={busy}
          >
            Save
          </button>
        </>
      }
    >
      <div className="space-y-3">
        <div>
          <label className="label">Username</label>
          <input className="input" value={user.username} disabled />
        </div>
        <div>
          <label className="label">Email</label>
          <input
            className="input"
            type="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
          />
        </div>
        <div>
          <label className="label">New password</label>
          <input
            className="input"
            type="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            placeholder="Leave blank to keep current"
            minLength={8}
          />
        </div>
        <div>
          <label className="label">Role</label>
          <select
            className="input"
            value={roleId}
            onChange={(e) => setRoleId(parseInt(e.target.value, 10))}
          >
            {roles.map((r) => (
              <option key={r.id} value={r.id}>
                {r.name}
              </option>
            ))}
          </select>
        </div>
        <label className="flex items-center gap-2 text-sm text-ink-700">
          <input
            type="checkbox"
            checked={disabled}
            disabled={isSelf}
            onChange={(e) => setDisabled(e.target.checked)}
          />
          Disabled{isSelf && " (can't disable yourself)"}
        </label>
        {error && (
          <div className="rounded-md border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-800">
            {error}
          </div>
        )}
      </div>
    </Modal>
  );
}
