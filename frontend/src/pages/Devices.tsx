import { RefreshCw, Search } from "lucide-react";
import { useCallback, useEffect, useMemo, useState } from "react";
import { api, ApiError } from "../api";
import Modal from "../components/Modal";
import PageHeader from "../components/PageHeader";

type Device = {
  id: string | null;
  name: string | null;
  model: string | null;
  mac: string | null;
  ip: string | null;
  firmware: string | null;
  status: string | null;
  adopted: boolean | null;
  uptime_sec: number | null;
  site: string | null;
  host_id: string | null;
  host_name: string | null;
  raw: Record<string, unknown>;
};

type SearchResponse = {
  total_hosts: number;
  total_devices: number;
  devices: Device[];
};

function statusBadge(status: string | null) {
  if (!status) return <span className="badge">unknown</span>;
  const s = status.toLowerCase();
  if (s.includes("online") || s.includes("connected") || s === "1") {
    return <span className="badge badge-ok">{status}</span>;
  }
  if (s.includes("offline") || s.includes("disconnected") || s === "0") {
    return <span className="badge badge-bad">{status}</span>;
  }
  return <span className="badge badge-warn">{status}</span>;
}

function fmtUptime(sec: number | null) {
  if (!sec) return "—";
  const d = Math.floor(sec / 86400);
  const h = Math.floor((sec % 86400) / 3600);
  if (d > 0) return `${d}d ${h}h`;
  const m = Math.floor((sec % 3600) / 60);
  if (h > 0) return `${h}h ${m}m`;
  return `${m}m`;
}

export default function DevicesPage() {
  const [q, setQ] = useState("");
  const [data, setData] = useState<SearchResponse | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [selected, setSelected] = useState<Device | null>(null);

  const fetchDevices = useCallback(
    async (needle: string) => {
      setLoading(true);
      setError(null);
      try {
        const res = await api.get<SearchResponse>(
          `/api/devices/search${needle ? `?q=${encodeURIComponent(needle)}` : ""}`
        );
        setData(res);
      } catch (err) {
        setError(err instanceof ApiError ? err.message : "Failed to load devices");
        setData(null);
      } finally {
        setLoading(false);
      }
    },
    []
  );

  useEffect(() => {
    fetchDevices("");
  }, [fetchDevices]);

  useEffect(() => {
    const handle = setTimeout(() => fetchDevices(q.trim()), 250);
    return () => clearTimeout(handle);
  }, [q, fetchDevices]);

  const refresh = async () => {
    try {
      await api.post("/api/devices/refresh");
    } finally {
      fetchDevices(q.trim());
    }
  };

  const countLabel = useMemo(() => {
    if (!data) return "";
    return `${data.total_devices} device${data.total_devices === 1 ? "" : "s"} across ${data.total_hosts} host${data.total_hosts === 1 ? "" : "s"}`;
  }, [data]);

  return (
    <div>
      <PageHeader
        title="Devices"
        subtitle="Search every device across all sites behind your API key."
        actions={
          <button className="btn" onClick={refresh} disabled={loading}>
            <RefreshCw size={14} className={loading ? "animate-spin" : ""} />
            Refresh
          </button>
        }
      />
      <div className="px-8 py-6">
        <div className="relative mb-4 max-w-xl">
          <Search
            size={14}
            className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-ink-400"
          />
          <input
            className="input pl-9"
            placeholder="Search by name, MAC, IP, model, site…"
            value={q}
            onChange={(e) => setQ(e.target.value)}
            autoFocus
          />
        </div>

        {error && (
          <div className="mb-4 rounded-md border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-800">
            {error}
          </div>
        )}

        <div className="mb-2 text-xs text-ink-500">{countLabel}</div>

        <div className="card overflow-hidden">
          <div className="max-h-[calc(100vh-260px)] overflow-auto">
            <table className="w-full border-collapse">
              <thead>
                <tr>
                  <th className="th">Name</th>
                  <th className="th">Model</th>
                  <th className="th">MAC</th>
                  <th className="th">IP</th>
                  <th className="th">Status</th>
                  <th className="th">Uptime</th>
                  <th className="th">Site</th>
                  <th className="th">Host</th>
                </tr>
              </thead>
              <tbody>
                {loading && !data && (
                  <tr>
                    <td className="td text-ink-500" colSpan={8}>
                      Loading…
                    </td>
                  </tr>
                )}
                {data && data.devices.length === 0 && (
                  <tr>
                    <td className="td text-ink-500" colSpan={8}>
                      No devices match.
                    </td>
                  </tr>
                )}
                {data?.devices.map((d, i) => (
                  <tr
                    key={(d.id || "") + (d.mac || "") + i}
                    onClick={() => setSelected(d)}
                    className="cursor-pointer border-t border-ink-100 hover:bg-ink-50"
                  >
                    <td className="td font-medium">{d.name || "—"}</td>
                    <td className="td">{d.model || "—"}</td>
                    <td className="td font-mono text-xs">{d.mac || "—"}</td>
                    <td className="td font-mono text-xs">{d.ip || "—"}</td>
                    <td className="td">{statusBadge(d.status)}</td>
                    <td className="td">{fmtUptime(d.uptime_sec)}</td>
                    <td className="td">{d.site || "—"}</td>
                    <td className="td text-ink-500">{d.host_name || "—"}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      </div>

      <Modal
        open={!!selected}
        onClose={() => setSelected(null)}
        title={selected?.name || "Device"}
        footer={
          <button className="btn" onClick={() => setSelected(null)}>
            Close
          </button>
        }
      >
        {selected && (
          <div className="space-y-3">
            <div className="grid grid-cols-2 gap-3 text-sm">
              <div>
                <div className="label">Model</div>
                <div>{selected.model || "—"}</div>
              </div>
              <div>
                <div className="label">Status</div>
                <div>{statusBadge(selected.status)}</div>
              </div>
              <div>
                <div className="label">MAC</div>
                <div className="font-mono text-xs">{selected.mac || "—"}</div>
              </div>
              <div>
                <div className="label">IP</div>
                <div className="font-mono text-xs">{selected.ip || "—"}</div>
              </div>
              <div>
                <div className="label">Firmware</div>
                <div>{selected.firmware || "—"}</div>
              </div>
              <div>
                <div className="label">Uptime</div>
                <div>{fmtUptime(selected.uptime_sec)}</div>
              </div>
              <div>
                <div className="label">Site</div>
                <div>{selected.site || "—"}</div>
              </div>
              <div>
                <div className="label">Host</div>
                <div>{selected.host_name || "—"}</div>
              </div>
            </div>
            <details>
              <summary className="cursor-pointer text-xs font-medium text-ink-500">
                Raw API response
              </summary>
              <pre className="mt-2 max-h-64 overflow-auto rounded-md bg-ink-900 p-3 font-mono text-xs text-ink-100">
                {JSON.stringify(selected.raw, null, 2)}
              </pre>
            </details>
          </div>
        )}
      </Modal>
    </div>
  );
}
