import {
  AlertTriangle,
  Check,
  ChevronRight,
  ExternalLink,
  Plus,
  Server,
  Trash2,
} from "lucide-react";
import { FormEvent, useCallback, useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { api, ApiError } from "../api";
import { useAuth } from "../auth";
import Modal from "../components/Modal";
import PageHeader from "../components/PageHeader";

type Console = {
  id: number;
  name: string;
  base_url: string;
  api_key_masked: string;
  verify_tls: boolean;
  last_test_at: string | null;
  last_test_ok: boolean | null;
  last_test_message: string | null;
};

type TestResult =
  | {
      ok: true;
      endpoint: string;
      site_count: number;
      first_site_name: string | null;
    }
  | { ok: false; error: string; status?: number | null };

export default function ConsolesPage() {
  const { can } = useAuth();
  const canManage = can("consoles:manage");

  const [consoles, setConsoles] = useState<Console[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [creating, setCreating] = useState(false);
  const [editing, setEditing] = useState<Console | null>(null);

  const load = useCallback(async () => {
    setError(null);
    try {
      setConsoles(await api.get<Console[]>("/api/consoles"));
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "Load failed");
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  async function remove(c: Console) {
    if (!confirm(`Remove console "${c.name}"?`)) return;
    await api.del(`/api/consoles/${c.id}`);
    await load();
  }

  return (
    <div>
      <PageHeader
        title="Consoles"
        subtitle="UniFi OS consoles Raptorr can reach directly on your LAN or VPN."
        actions={
          canManage && (
            <button
              className="btn btn-primary"
              onClick={() => setCreating(true)}
            >
              <Plus size={14} />
              Add console
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

        {!consoles && !error && (
          <div className="text-sm text-ink-500">Loading…</div>
        )}

        {consoles && consoles.length === 0 && (
          <div className="card max-w-xl p-6">
            <div className="flex items-center gap-2 text-sm font-semibold text-ink-900">
              <Server size={16} /> No consoles yet
            </div>
            <p className="mt-2 text-sm text-ink-500">
              Add a UOS console by its LAN (or VPN-reachable) IP and a Control
              Plane API key to start seeing real-time devices and clients.
            </p>
            {canManage && (
              <button
                className="btn btn-primary mt-3"
                onClick={() => setCreating(true)}
              >
                <Plus size={14} />
                Add your first console
              </button>
            )}
          </div>
        )}

        {consoles && consoles.length > 0 && (
          <div className="card overflow-hidden">
            <table className="w-full border-collapse">
              <thead>
                <tr>
                  <th className="th">Name</th>
                  <th className="th">Base URL</th>
                  <th className="th">Status</th>
                  <th className="th"></th>
                </tr>
              </thead>
              <tbody>
                {consoles.map((c) => (
                  <tr
                    key={c.id}
                    className="border-t border-ink-100 hover:bg-ink-50"
                  >
                    <td className="td font-medium">
                      <Link
                        to={`/consoles/${c.id}`}
                        className="hover:underline"
                      >
                        {c.name}
                      </Link>
                    </td>
                    <td className="td font-mono text-xs text-ink-500">
                      {c.base_url}
                    </td>
                    <td className="td">
                      {c.last_test_ok === true && (
                        <span className="badge badge-ok">
                          <Check size={10} /> OK
                        </span>
                      )}
                      {c.last_test_ok === false && (
                        <span className="badge badge-bad">
                          <AlertTriangle size={10} /> Failed
                        </span>
                      )}
                      {c.last_test_ok === null && (
                        <span className="badge">Not tested</span>
                      )}
                      {c.last_test_message && (
                        <span className="ml-2 text-xs text-ink-500">
                          {c.last_test_message}
                        </span>
                      )}
                    </td>
                    <td className="td text-right">
                      <div className="flex justify-end gap-1">
                        <Link
                          to={`/consoles/${c.id}`}
                          className="btn btn-ghost px-2"
                          title="Open"
                        >
                          <ChevronRight size={14} />
                        </Link>
                        {canManage && (
                          <button
                            className="btn btn-ghost px-2"
                            onClick={() => setEditing(c)}
                          >
                            Edit
                          </button>
                        )}
                        {canManage && (
                          <button
                            className="btn btn-ghost px-2"
                            onClick={() => remove(c)}
                            title="Remove"
                          >
                            <Trash2 size={14} />
                          </button>
                        )}
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {creating && (
        <ConsoleEditor
          onClose={() => setCreating(false)}
          onSaved={async () => {
            setCreating(false);
            await load();
          }}
        />
      )}
      {editing && (
        <ConsoleEditor
          existing={editing}
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

function ConsoleEditor({
  existing,
  onClose,
  onSaved,
}: {
  existing?: Console;
  onClose: () => void;
  onSaved: () => void;
}) {
  const isEdit = !!existing;
  const [name, setName] = useState(existing?.name || "");
  const [baseUrl, setBaseUrl] = useState(existing?.base_url || "");
  const [apiKey, setApiKey] = useState("");
  const [verifyTls, setVerifyTls] = useState(existing?.verify_tls ?? false);
  const [testResult, setTestResult] = useState<TestResult | null>(null);
  const [testing, setTesting] = useState(false);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function runTest() {
    setError(null);
    setTesting(true);
    setTestResult(null);
    try {
      const body = {
        base_url: baseUrl.trim() || null,
        api_key: apiKey.trim() || null,
        verify_tls: verifyTls,
      };
      const url = isEdit
        ? `/api/consoles/${existing!.id}/test`
        : "/api/consoles/test";
      const res = await api.post<TestResult>(url, body);
      setTestResult(res);
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "Test failed");
    } finally {
      setTesting(false);
    }
  }

  async function save(e: FormEvent) {
    e.preventDefault();
    setError(null);
    setSaving(true);
    try {
      if (isEdit) {
        await api.patch(`/api/consoles/${existing!.id}`, {
          name: name.trim(),
          base_url: baseUrl.trim(),
          api_key: apiKey.trim() || undefined,
          verify_tls: verifyTls,
        });
      } else {
        await api.post("/api/consoles", {
          name: name.trim(),
          base_url: baseUrl.trim(),
          api_key: apiKey.trim(),
          verify_tls: verifyTls,
        });
      }
      onSaved();
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "Save failed");
    } finally {
      setSaving(false);
    }
  }

  return (
    <Modal
      open
      onClose={onClose}
      title={isEdit ? `Edit ${existing?.name}` : "Add console"}
      footer={
        <>
          <button
            className="btn mr-auto"
            onClick={runTest}
            disabled={testing || !baseUrl || (!isEdit && !apiKey)}
          >
            {testing ? "Testing…" : "Test connection"}
          </button>
          <button className="btn" onClick={onClose}>
            Cancel
          </button>
          <button
            className="btn btn-primary"
            onClick={save as any}
            disabled={saving}
          >
            Save
          </button>
        </>
      }
    >
      <form onSubmit={save} className="space-y-3">
        <div>
          <label className="label">Name</label>
          <input
            className="input"
            value={name}
            onChange={(e) => setName(e.target.value)}
            placeholder="e.g. HQ main, Remote site A"
            required
          />
        </div>

        <div>
          <label className="label">Base URL</label>
          <input
            className="input font-mono text-xs"
            value={baseUrl}
            onChange={(e) => setBaseUrl(e.target.value)}
            placeholder="https://10.0.0.1 or https://unifi.example.lan"
            required
          />
          <p className="mt-1 text-xs text-ink-500">
            The console's IP or hostname. Raptorr must be able to reach it
            (LAN, VPN, or Tailscale).
          </p>
        </div>

        <div>
          <label className="label">
            Control Plane API key
            {isEdit && (
              <span className="ml-2 font-normal normal-case text-ink-500">
                (leave blank to keep existing: {existing?.api_key_masked})
              </span>
            )}
          </label>
          <input
            className="input font-mono text-xs"
            type="password"
            value={apiKey}
            onChange={(e) => setApiKey(e.target.value)}
            placeholder="Generated on the console: Control Plane → Admins & Users → API Keys"
            required={!isEdit}
          />
        </div>

        <label className="flex items-center gap-2 text-sm text-ink-700">
          <input
            type="checkbox"
            checked={verifyTls}
            onChange={(e) => setVerifyTls(e.target.checked)}
          />
          Verify TLS certificate (uncheck for self-signed LAN certs)
        </label>

        {testResult && testResult.ok && (
          <div className="rounded-md border border-emerald-200 bg-emerald-50 p-3 text-sm text-emerald-900">
            <div className="flex items-center gap-2 font-semibold">
              <Check size={14} /> Connected
            </div>
            <div className="mt-1 text-xs">
              {testResult.site_count} site(s)
              {testResult.first_site_name &&
                ` — first: "${testResult.first_site_name}"`}
            </div>
            <div className="mt-1 font-mono text-[10px] text-emerald-800">
              {testResult.endpoint}
            </div>
          </div>
        )}
        {testResult && !testResult.ok && (
          <div className="rounded-md border border-red-200 bg-red-50 p-3 text-sm text-red-800">
            <div className="flex items-center gap-2 font-semibold">
              <AlertTriangle size={14} /> Test failed
              {testResult.status ? ` (HTTP ${testResult.status})` : ""}
            </div>
            <div className="mt-1 text-xs">{testResult.error}</div>
          </div>
        )}
        {error && (
          <div className="rounded-md border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-800">
            {error}
          </div>
        )}

        <p className="text-xs text-ink-500">
          <ExternalLink size={10} className="mr-1 inline" />
          The Control Plane API key is a local key generated on the UOS
          console. The Site Manager cloud API key is not compatible.
        </p>
      </form>
    </Modal>
  );
}
