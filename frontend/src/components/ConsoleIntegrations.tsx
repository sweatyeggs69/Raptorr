import { AlertTriangle, Check, Plug, Server, X } from "lucide-react";
import { FormEvent, useCallback, useEffect, useState } from "react";
import { api, ApiError } from "../api";
import Modal from "./Modal";

type Host = {
  id: string | null;
  name: string | null;
  type: string | null;
  host_ip: string | null;
};

type Integration = {
  host_id: string;
  base_url: string;
  api_key_masked: string;
  verify_tls: boolean;
  last_test_at: string | null;
  last_test_ok: boolean | null;
  last_test_message: string | null;
  updated_at: string;
};

type Suggestion = {
  label: string;
  base_url: string;
  verify_tls: boolean;
};

type TestResult =
  | {
      ok: true;
      endpoint: string;
      site_count: number;
      first_site_name: string | null;
    }
  | { ok: false; error: string; status?: number | null };

export default function ConsoleIntegrations({
  canManage,
}: {
  canManage: boolean;
}) {
  const [hosts, setHosts] = useState<Host[] | null>(null);
  const [integrations, setIntegrations] = useState<Record<string, Integration>>(
    {}
  );
  const [error, setError] = useState<string | null>(null);
  const [editing, setEditing] = useState<{ host: Host; integration: Integration | null } | null>(
    null
  );

  const load = useCallback(async () => {
    setError(null);
    try {
      const [h, i] = await Promise.all([
        api.get<Host[]>("/api/devices/hosts"),
        api.get<Integration[]>("/api/consoles/integrations"),
      ]);
      setHosts(h);
      const map: Record<string, Integration> = {};
      for (const row of i) map[row.host_id] = row;
      setIntegrations(map);
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "Load failed");
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  async function removeIntegration(hostId: string) {
    if (!confirm("Remove local integration for this console?")) return;
    await api.del(`/api/consoles/integrations/${encodeURIComponent(hostId)}`);
    await load();
  }

  return (
    <div className="card max-w-3xl p-5">
      <div className="flex items-center gap-2">
        <Server size={16} className="text-ink-500" />
        <h2 className="text-sm font-semibold text-ink-900">
          UniFi OS consoles — local Network Integration API
        </h2>
      </div>
      <p className="mt-1 text-sm text-ink-500">
        The Site Manager API returns aggregated, sometimes-stale data with no per-site
        device attribution. Point Raptorr at a console's local Network Integration API
        with a Control Plane key to get fresh, site-accurate devices and clients.{" "}
        <strong>Raptorr must be able to reach the console's IP</strong> (same LAN, or via
        a VPN/Tailscale sidecar); the unifi.ui.com cloud proxy does not accept API keys.
      </p>

      {error && (
        <div className="mt-3 rounded-md border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-800">
          {error}
        </div>
      )}

      <div className="mt-4 divide-y divide-ink-100">
        {!hosts && !error && (
          <div className="py-3 text-sm text-ink-500">Loading consoles…</div>
        )}
        {hosts && hosts.length === 0 && (
          <div className="py-3 text-sm text-ink-500">
            No consoles visible to your Site Manager API key.
          </div>
        )}
        {hosts?.map((h) => {
          const i = h.id ? integrations[h.id] : undefined;
          return (
            <div
              key={h.id || h.name || ""}
              className="flex items-start gap-4 py-3"
            >
              <div className="flex-1">
                <div className="text-sm font-medium text-ink-900">
                  {h.name || "—"}
                </div>
                <div className="text-xs text-ink-500">
                  {h.type || "UniFi OS"} · {h.host_ip || "no IP"} ·{" "}
                  <span className="font-mono">{h.id}</span>
                </div>
                {i ? (
                  <div className="mt-1 text-xs">
                    <span
                      className={
                        i.last_test_ok === true
                          ? "text-emerald-700"
                          : i.last_test_ok === false
                            ? "text-red-700"
                            : "text-ink-500"
                      }
                    >
                      {i.last_test_ok === true && (
                        <Check size={12} className="mr-1 inline" />
                      )}
                      {i.last_test_ok === false && (
                        <AlertTriangle size={12} className="mr-1 inline" />
                      )}
                      {i.last_test_message || "Not tested yet"}
                    </span>
                    <span className="ml-2 text-ink-500">
                      · {i.base_url} · key {i.api_key_masked}
                    </span>
                  </div>
                ) : (
                  <div className="mt-1 text-xs text-ink-500">
                    No local integration configured — using cloud Site Manager data only.
                  </div>
                )}
              </div>
              {canManage && h.id && (
                <div className="flex gap-2">
                  <button
                    className="btn"
                    onClick={() => setEditing({ host: h, integration: i || null })}
                  >
                    <Plug size={14} />
                    {i ? "Edit" : "Configure"}
                  </button>
                  {i && (
                    <button
                      className="btn btn-ghost"
                      onClick={() => removeIntegration(h.id!)}
                      title="Remove local integration"
                    >
                      <X size={14} />
                    </button>
                  )}
                </div>
              )}
            </div>
          );
        })}
      </div>

      {editing && (
        <IntegrationEditor
          host={editing.host}
          existing={editing.integration}
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

function IntegrationEditor({
  host,
  existing,
  onClose,
  onSaved,
}: {
  host: Host;
  existing: Integration | null;
  onClose: () => void;
  onSaved: () => void;
}) {
  const [baseUrl, setBaseUrl] = useState(existing?.base_url || "");
  const [apiKey, setApiKey] = useState("");
  const [verifyTls, setVerifyTls] = useState(existing?.verify_tls ?? true);
  const [suggestions, setSuggestions] = useState<Suggestion[]>([]);
  const [testing, setTesting] = useState(false);
  const [testResult, setTestResult] = useState<TestResult | null>(null);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!host.id) return;
    const q = new URLSearchParams();
    if (host.host_ip) q.set("host_ip", host.host_ip);
    api
      .get<Suggestion[]>(
        `/api/consoles/integrations/${encodeURIComponent(host.id)}/suggestions?${q}`
      )
      .then(setSuggestions)
      .catch(() => setSuggestions([]));
  }, [host]);

  async function runTest() {
    if (!host.id) return;
    setError(null);
    setTesting(true);
    setTestResult(null);
    try {
      const res = await api.post<TestResult>(
        `/api/consoles/integrations/${encodeURIComponent(host.id)}/test`,
        {
          base_url: baseUrl.trim() || null,
          api_key: apiKey.trim() || null,
          verify_tls: verifyTls,
        }
      );
      setTestResult(res);
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "Test failed");
    } finally {
      setTesting(false);
    }
  }

  async function save(e: FormEvent) {
    e.preventDefault();
    if (!host.id) return;
    setError(null);
    setSaving(true);
    try {
      await api.put(`/api/consoles/integrations/${encodeURIComponent(host.id)}`, {
        base_url: baseUrl.trim(),
        api_key: apiKey.trim() || null,
        verify_tls: verifyTls,
      });
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
      title={`${existing ? "Edit" : "Configure"} local integration — ${host.name || host.id}`}
      footer={
        <>
          <button
            className="btn mr-auto"
            onClick={runTest}
            disabled={testing || !baseUrl || (!existing && !apiKey)}
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
          <label className="label">Base URL</label>
          <input
            className="input font-mono text-xs"
            value={baseUrl}
            onChange={(e) => setBaseUrl(e.target.value)}
            placeholder="https://10.0.0.1 or https://unifi.example.lan"
            required
          />
          {suggestions.length > 0 && (
            <div className="mt-2 flex flex-wrap gap-1">
              <span className="text-xs text-ink-500">Suggested:</span>
              {suggestions.map((s) => (
                <button
                  type="button"
                  key={s.base_url}
                  onClick={() => {
                    setBaseUrl(s.base_url);
                    setVerifyTls(s.verify_tls);
                    setTestResult(null);
                  }}
                  className="rounded border border-ink-200 bg-white px-2 py-0.5 text-xs hover:bg-ink-50"
                >
                  {s.label}
                </button>
              ))}
            </div>
          )}
          <p className="mt-1 text-xs text-ink-500">
            Use the console's IP or hostname (LAN or VPN reachable). Raptorr must be
            able to connect to it over the network.
          </p>
        </div>

        <div>
          <label className="label">
            Control Plane API key
            {existing && (
              <span className="ml-2 font-normal normal-case text-ink-500">
                (leave blank to keep existing: {existing.api_key_masked})
              </span>
            )}
          </label>
          <input
            className="input font-mono text-xs"
            type="password"
            value={apiKey}
            onChange={(e) => setApiKey(e.target.value)}
            placeholder="Paste the local API key from Control Plane → Admins & Users"
            required={!existing}
          />
          <p className="mt-1 text-xs text-ink-500">
            This is the key generated on the UOS console itself — not the Site
            Manager API key at unifi.ui.com.
          </p>
        </div>

        <label className="flex items-center gap-2 text-sm text-ink-700">
          <input
            type="checkbox"
            checked={verifyTls}
            onChange={(e) => setVerifyTls(e.target.checked)}
          />
          Verify TLS certificate (uncheck for direct LAN / self-signed certs)
        </label>

        {testResult && testResult.ok && (
          <div className="rounded-md border border-emerald-200 bg-emerald-50 p-3 text-sm text-emerald-900">
            <div className="flex items-center gap-2 font-semibold">
              <Check size={14} /> Connected
            </div>
            <div className="mt-1 text-xs">
              {testResult.site_count} site(s) found
              {testResult.first_site_name && ` — first: "${testResult.first_site_name}"`}
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
      </form>
    </Modal>
  );
}
