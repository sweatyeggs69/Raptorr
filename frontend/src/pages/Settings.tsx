import { Check, KeyRound } from "lucide-react";
import { FormEvent, useEffect, useState } from "react";
import { api, ApiError } from "../api";
import { useAuth } from "../auth";
import PageHeader from "../components/PageHeader";

type ApiKeyInfo = { configured: boolean; masked: string };

export default function SettingsPage() {
  const { can } = useAuth();
  const canManage = can("settings:manage");

  const [info, setInfo] = useState<ApiKeyInfo | null>(null);
  const [input, setInput] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [saved, setSaved] = useState(false);
  const [busy, setBusy] = useState(false);

  async function load() {
    setError(null);
    try {
      const r = await api.get<ApiKeyInfo>("/api/settings/api-key");
      setInfo(r);
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "Load failed");
    }
  }

  useEffect(() => {
    load();
  }, []);

  async function onSave(e: FormEvent) {
    e.preventDefault();
    setError(null);
    setSaved(false);
    setBusy(true);
    try {
      const r = await api.put<ApiKeyInfo>("/api/settings/api-key", {
        api_key: input.trim(),
      });
      setInfo(r);
      setInput("");
      setSaved(true);
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "Save failed");
    } finally {
      setBusy(false);
    }
  }

  return (
    <div>
      <PageHeader
        title="Settings"
        subtitle="Configure Raptorr and the UniFi Site Manager integration."
      />
      <div className="px-8 py-6">
        <div className="card max-w-2xl p-5">
          <div className="flex items-center gap-2">
            <KeyRound size={16} className="text-ink-500" />
            <h2 className="text-sm font-semibold text-ink-900">
              UniFi Site Manager API key
            </h2>
          </div>
          <p className="mt-1 text-sm text-ink-500">
            Generate a key at{" "}
            <span className="font-mono text-xs">unifi.ui.com → API</span>. It's
            stored locally and sent as <span className="font-mono text-xs">X-API-Key</span>{" "}
            on every request.
          </p>

          <div className="mt-4 text-sm">
            Current:{" "}
            {info?.configured ? (
              <span className="font-mono text-ink-800">{info.masked}</span>
            ) : (
              <span className="text-ink-500">not configured</span>
            )}
          </div>

          {canManage && (
            <form onSubmit={onSave} className="mt-4 space-y-3">
              <div>
                <label className="label">
                  {info?.configured ? "Replace key" : "Set key"}
                </label>
                <input
                  className="input font-mono text-xs"
                  value={input}
                  onChange={(e) => setInput(e.target.value)}
                  placeholder="Paste API key"
                  required
                />
              </div>
              {error && (
                <div className="rounded-md border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-800">
                  {error}
                </div>
              )}
              {saved && !error && (
                <div className="flex items-center gap-2 rounded-md border border-emerald-200 bg-emerald-50 px-3 py-2 text-sm text-emerald-800">
                  <Check size={14} />
                  Saved and verified.
                </div>
              )}
              <button
                type="submit"
                className="btn btn-primary"
                disabled={busy || !input.trim()}
              >
                {busy ? "Verifying…" : "Save & verify"}
              </button>
            </form>
          )}
        </div>
      </div>
    </div>
  );
}
