import { Lock, Plus, Trash2 } from "lucide-react";
import { FormEvent, useCallback, useEffect, useState } from "react";
import { api, ApiError } from "../api";
import { useAuth } from "../auth";
import Modal from "../components/Modal";
import PageHeader from "../components/PageHeader";

type Role = {
  id: number;
  name: string;
  description: string;
  builtin: boolean;
  permissions: string[];
};

export default function RolesPage() {
  const { can } = useAuth();
  const canManage = can("roles:manage");

  const [roles, setRoles] = useState<Role[]>([]);
  const [permissions, setPermissions] = useState<string[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [creating, setCreating] = useState(false);
  const [editing, setEditing] = useState<Role | null>(null);

  const load = useCallback(async () => {
    setError(null);
    try {
      const [r, p] = await Promise.all([
        api.get<Role[]>("/api/roles"),
        api.get<string[]>("/api/roles/permissions"),
      ]);
      setRoles(r);
      setPermissions(p);
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "Load failed");
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  return (
    <div>
      <PageHeader
        title="Roles"
        subtitle="Each user is assigned a role. Roles grant permissions."
        actions={
          canManage && (
            <button className="btn btn-primary" onClick={() => setCreating(true)}>
              <Plus size={14} />
              New role
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
        <div className="grid grid-cols-1 gap-4 md:grid-cols-2 xl:grid-cols-3">
          {roles.map((r) => (
            <div key={r.id} className="card p-4">
              <div className="flex items-start justify-between">
                <div>
                  <div className="flex items-center gap-2">
                    <h3 className="text-sm font-semibold text-ink-900">
                      {r.name}
                    </h3>
                    {r.builtin && (
                      <span className="badge">
                        <Lock size={10} /> built-in
                      </span>
                    )}
                  </div>
                  {r.description && (
                    <p className="mt-1 text-sm text-ink-500">{r.description}</p>
                  )}
                </div>
                {canManage && (
                  <button
                    className="btn btn-ghost"
                    onClick={() => setEditing(r)}
                  >
                    Edit
                  </button>
                )}
              </div>
              <div className="mt-3 flex flex-wrap gap-1">
                {r.permissions.length === 0 && (
                  <span className="text-xs text-ink-500">No permissions</span>
                )}
                {r.permissions.map((p) => (
                  <span key={p} className="badge font-mono text-[10px]">
                    {p}
                  </span>
                ))}
              </div>
            </div>
          ))}
        </div>
      </div>

      {creating && (
        <RoleEditor
          permissions={permissions}
          onClose={() => setCreating(false)}
          onSaved={async () => {
            setCreating(false);
            await load();
          }}
        />
      )}
      {editing && (
        <RoleEditor
          role={editing}
          permissions={permissions}
          onClose={() => setEditing(null)}
          onSaved={async () => {
            setEditing(null);
            await load();
          }}
        />
      )}
    </div>
  );
}

function RoleEditor({
  role,
  permissions,
  onClose,
  onSaved,
}: {
  role?: Role;
  permissions: string[];
  onClose: () => void;
  onSaved: () => void;
}) {
  const [name, setName] = useState(role?.name || "");
  const [description, setDescription] = useState(role?.description || "");
  const [selected, setSelected] = useState<Set<string>>(
    new Set(role?.permissions || [])
  );
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const isEdit = !!role;
  const locked = isEdit && role?.builtin && role?.name === "admin";

  function toggle(p: string) {
    if (locked) return;
    const next = new Set(selected);
    if (next.has(p)) next.delete(p);
    else next.add(p);
    setSelected(next);
  }

  async function onSave(e: FormEvent) {
    e.preventDefault();
    setError(null);
    setBusy(true);
    try {
      if (isEdit && role) {
        await api.patch(`/api/roles/${role.id}`, {
          description,
          permissions: locked ? undefined : Array.from(selected),
        });
      } else {
        await api.post("/api/roles", {
          name: name.trim(),
          description,
          permissions: Array.from(selected),
        });
      }
      onSaved();
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "Save failed");
    } finally {
      setBusy(false);
    }
  }

  async function onDelete() {
    if (!role) return;
    if (!confirm(`Delete role "${role.name}"?`)) return;
    setError(null);
    setBusy(true);
    try {
      await api.del(`/api/roles/${role.id}`);
      onSaved();
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
      title={isEdit ? `Edit ${role?.name}` : "New role"}
      footer={
        <>
          {isEdit && role && !role.builtin && (
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
            onClick={onSave as any}
            disabled={busy}
          >
            Save
          </button>
        </>
      }
    >
      <form onSubmit={onSave} className="space-y-3">
        <div>
          <label className="label">Name</label>
          <input
            className="input"
            value={name}
            onChange={(e) => setName(e.target.value)}
            disabled={isEdit}
            required
          />
        </div>
        <div>
          <label className="label">Description</label>
          <input
            className="input"
            value={description}
            onChange={(e) => setDescription(e.target.value)}
          />
        </div>
        <div>
          <label className="label">Permissions</label>
          {locked && (
            <p className="mb-2 text-xs text-ink-500">
              The admin role always has all permissions.
            </p>
          )}
          <div className="grid grid-cols-1 gap-1 rounded-md border border-ink-200 bg-ink-50 p-2">
            {permissions.map((p) => (
              <label
                key={p}
                className="flex items-center gap-2 rounded px-2 py-1 text-sm hover:bg-white"
              >
                <input
                  type="checkbox"
                  checked={selected.has(p) || !!locked}
                  disabled={!!locked}
                  onChange={() => toggle(p)}
                />
                <span className="font-mono text-xs">{p}</span>
              </label>
            ))}
          </div>
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
