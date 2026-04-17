import { FormEvent, useState } from "react";
import { api, ApiError } from "../api";
import { useAuth } from "../auth";

export default function SetupPage() {
  const { refresh, login } = useAuth();
  const [username, setUsername] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [confirm, setConfirm] = useState("");
  const [apiKey, setApiKey] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  async function onSubmit(e: FormEvent) {
    e.preventDefault();
    setError(null);
    if (password !== confirm) {
      setError("Passwords don't match");
      return;
    }
    if (password.length < 8) {
      setError("Password must be at least 8 characters");
      return;
    }
    setBusy(true);
    try {
      await api.post("/api/setup/complete", {
        username: username.trim(),
        email: email.trim() || null,
        password,
        api_key: apiKey.trim() || null,
      });
      await login(username.trim(), password);
      await refresh();
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "Setup failed");
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="flex min-h-full items-center justify-center bg-ink-50 px-4 py-10">
      <form
        onSubmit={onSubmit}
        className="card w-full max-w-md p-6"
        autoComplete="off"
      >
        <div className="mb-5">
          <div className="mb-2 inline-flex items-center gap-2">
            <div className="flex h-7 w-7 items-center justify-center rounded bg-ink-900 font-mono text-sm font-bold text-white">
              R
            </div>
            <span className="text-sm font-semibold text-ink-900">Raptorr</span>
          </div>
          <h1 className="text-lg font-semibold text-ink-900">
            Welcome — let's set things up
          </h1>
          <p className="mt-1 text-sm text-ink-500">
            Create the first admin account. You can add more users afterwards.
          </p>
        </div>

        <div className="space-y-3">
          <div>
            <label className="label">Admin username</label>
            <input
              className="input"
              value={username}
              onChange={(e) => setUsername(e.target.value)}
              required
              minLength={3}
              autoFocus
            />
          </div>
          <div>
            <label className="label">Email (optional)</label>
            <input
              className="input"
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
            />
          </div>
          <div className="grid grid-cols-2 gap-3">
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
              <label className="label">Confirm</label>
              <input
                className="input"
                type="password"
                value={confirm}
                onChange={(e) => setConfirm(e.target.value)}
                required
                minLength={8}
              />
            </div>
          </div>
          <div>
            <label className="label">
              UniFi Site Manager API key (optional)
            </label>
            <input
              className="input font-mono text-xs"
              value={apiKey}
              onChange={(e) => setApiKey(e.target.value)}
              placeholder="Paste from unifi.ui.com → API"
            />
            <p className="mt-1 text-xs text-ink-500">
              You can add or change this later in Settings.
            </p>
          </div>
        </div>

        {error && (
          <div className="mt-4 rounded-md border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-800">
            {error}
          </div>
        )}

        <button
          type="submit"
          className="btn btn-primary mt-5 w-full"
          disabled={busy}
        >
          {busy ? "Setting up…" : "Create admin account"}
        </button>
      </form>
    </div>
  );
}
