import {
  AlertTriangle,
  ArrowDown,
  ArrowUp,
  ArrowUpDown,
  RefreshCw,
  Search,
  Server,
} from "lucide-react";
import { useCallback, useEffect, useMemo, useState } from "react";
import { Link } from "react-router-dom";
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
  is_online: boolean | null;
  device_type: string;
  uptime_sec: number | null;
  site_id: string | null;
  site_name: string | null;
  console_id: number;
  console_name: string;
  raw: Record<string, unknown>;
};

type SearchResponse = {
  devices: Device[];
  total_devices: number;
  total_sites: number;
  total_consoles: number;
  total_consoles_ok: number;
  errors: { console_id: number; console_name: string; error: string }[];
};

type SortKey =
  | "name"
  | "device_type"
  | "is_online"
  | "model"
  | "ip"
  | "mac"
  | "uptime_sec"
  | "site_name"
  | "console_name";
type SortDir = "asc" | "desc";

function statusBadge(d: Device) {
  if (d.is_online === true) {
    return <span className="badge badge-ok">{d.status || "online"}</span>;
  }
  if (d.is_online === false) {
    return <span className="badge badge-bad">{d.status || "offline"}</span>;
  }
  return <span className="badge badge-warn">{d.status || "unknown"}</span>;
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

function compare(a: Device, b: Device, key: SortKey, dir: SortDir): number {
  const sign = dir === "asc" ? 1 : -1;
  if (key === "is_online") {
    const rank = (v: boolean | null) => (v === true ? 0 : v === null ? 1 : 2);
    return (rank(a.is_online) - rank(b.is_online)) * sign;
  }
  if (key === "uptime_sec") {
    return ((a.uptime_sec ?? -1) - (b.uptime_sec ?? -1)) * sign;
  }
  const av = (a[key] as string | null) ?? "";
  const bv = (b[key] as string | null) ?? "";
  return av.localeCompare(bv, undefined, { numeric: true }) * sign;
}

function SortableTh({
  label,
  field,
  sort,
  onToggle,
}: {
  label: string;
  field: SortKey;
  sort: { key: SortKey; dir: SortDir };
  onToggle: (k: SortKey) => void;
}) {
  const active = sort.key === field;
  const Icon = active ? (sort.dir === "asc" ? ArrowUp : ArrowDown) : ArrowUpDown;
  return (
    <th className="th">
      <button
        onClick={() => onToggle(field)}
        className={`inline-flex items-center gap-1 ${active ? "text-ink-900" : "text-ink-500"} hover:text-ink-900`}
      >
        <span>{label}</span>
        <Icon size={12} />
      </button>
    </th>
  );
}

export default function DevicesPage() {
  const [q, setQ] = useState("");
  const [data, setData] = useState<SearchResponse | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [selected, setSelected] = useState<Device | null>(null);
  const [sort, setSort] = useState<{ key: SortKey; dir: SortDir }>({
    key: "name",
    dir: "asc",
  });

  const fetchDevices = useCallback(async (needle: string) => {
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
  }, []);

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

  const toggleSort = (key: SortKey) => {
    setSort((prev) =>
      prev.key === key
        ? { key, dir: prev.dir === "asc" ? "desc" : "asc" }
        : { key, dir: "asc" }
    );
  };

  const sorted = useMemo(() => {
    if (!data) return [];
    return [...data.devices].sort((a, b) => compare(a, b, sort.key, sort.dir));
  }, [data, sort]);

  const countLabel = useMemo(() => {
    if (!data) return "";
    return `${data.total_devices} device${data.total_devices === 1 ? "" : "s"} · ${data.total_sites} site${data.total_sites === 1 ? "" : "s"} · ${data.total_consoles_ok}/${data.total_consoles} console${data.total_consoles === 1 ? "" : "s"}`;
  }, [data]);

  return (
    <div>
      <PageHeader
        title="Devices"
        subtitle="Live device inventory aggregated across every configured console."
        actions={
          <button className="btn" onClick={refresh} disabled={loading}>
            <RefreshCw size={14} className={loading ? "animate-spin" : ""} />
            Refresh
          </button>
        }
      />
      <div className="px-8 py-6">
        {data && data.total_consoles === 0 && (
          <div className="card max-w-xl p-6">
            <div className="flex items-center gap-2 text-sm font-semibold text-ink-900">
              <Server size={16} /> No consoles configured yet
            </div>
            <p className="mt-2 text-sm text-ink-500">
              Raptorr reads device data directly from your UOS consoles. Add one
              to get started.
            </p>
            <Link to="/consoles" className="btn btn-primary mt-3">
              Add a console
            </Link>
          </div>
        )}

        {data && data.total_consoles > 0 && (
          <>
            <div className="relative mb-4 max-w-xl">
              <Search
                size={14}
                className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-ink-400"
              />
              <input
                className="input pl-9"
                placeholder="Search by name, MAC, IP, model, site, console…"
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

            {data.errors.length > 0 && (
              <div className="mb-4 rounded-md border border-amber-200 bg-amber-50 p-3 text-xs text-amber-900">
                <div className="flex items-center gap-2 font-semibold">
                  <AlertTriangle size={14} /> {data.errors.length} console
                  {data.errors.length === 1 ? "" : "s"} unreachable
                </div>
                <ul className="mt-2 space-y-0.5 pl-5">
                  {data.errors.map((e) => (
                    <li key={e.console_id}>
                      <Link
                        to={`/consoles/${e.console_id}`}
                        className="font-medium underline"
                      >
                        {e.console_name}
                      </Link>
                      : {e.error}
                    </li>
                  ))}
                </ul>
              </div>
            )}

            <div className="mb-2 text-xs text-ink-500">{countLabel}</div>

            <div className="card overflow-hidden">
              <div className="max-h-[calc(100vh-260px)] overflow-auto">
                <table className="w-full border-collapse">
                  <thead>
                    <tr>
                      <SortableTh label="Name" field="name" sort={sort} onToggle={toggleSort} />
                      <SortableTh label="Type" field="device_type" sort={sort} onToggle={toggleSort} />
                      <SortableTh label="Model" field="model" sort={sort} onToggle={toggleSort} />
                      <SortableTh label="MAC" field="mac" sort={sort} onToggle={toggleSort} />
                      <SortableTh label="IP" field="ip" sort={sort} onToggle={toggleSort} />
                      <SortableTh label="Status" field="is_online" sort={sort} onToggle={toggleSort} />
                      <SortableTh label="Uptime" field="uptime_sec" sort={sort} onToggle={toggleSort} />
                      <SortableTh label="Site" field="site_name" sort={sort} onToggle={toggleSort} />
                      <SortableTh label="Console" field="console_name" sort={sort} onToggle={toggleSort} />
                    </tr>
                  </thead>
                  <tbody>
                    {loading && !data?.devices.length && (
                      <tr>
                        <td className="td text-ink-500" colSpan={9}>
                          Loading…
                        </td>
                      </tr>
                    )}
                    {sorted.length === 0 && !loading && (
                      <tr>
                        <td className="td text-ink-500" colSpan={9}>
                          No devices match.
                        </td>
                      </tr>
                    )}
                    {sorted.map((d, i) => (
                      <tr
                        key={(d.id || "") + (d.mac || "") + i}
                        onClick={() => setSelected(d)}
                        className="cursor-pointer border-t border-ink-100 hover:bg-ink-50"
                      >
                        <td className="td font-medium">{d.name || "—"}</td>
                        <td className="td">
                          <span className="badge">{d.device_type}</span>
                        </td>
                        <td className="td">{d.model || "—"}</td>
                        <td className="td font-mono text-xs">{d.mac || "—"}</td>
                        <td className="td font-mono text-xs">{d.ip || "—"}</td>
                        <td className="td">{statusBadge(d)}</td>
                        <td className="td">{fmtUptime(d.uptime_sec)}</td>
                        <td className="td">{d.site_name || "—"}</td>
                        <td className="td text-ink-500">
                          <Link
                            to={`/consoles/${d.console_id}`}
                            onClick={(e) => e.stopPropagation()}
                            className="hover:underline"
                          >
                            {d.console_name}
                          </Link>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
          </>
        )}
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
                <div className="label">Type</div>
                <div>{selected.device_type}</div>
              </div>
              <div>
                <div className="label">Model</div>
                <div>{selected.model || "—"}</div>
              </div>
              <div>
                <div className="label">Status</div>
                <div>{statusBadge(selected)}</div>
              </div>
              <div>
                <div className="label">Firmware</div>
                <div>{selected.firmware || "—"}</div>
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
                <div className="label">Uptime</div>
                <div>{fmtUptime(selected.uptime_sec)}</div>
              </div>
              <div>
                <div className="label">Site</div>
                <div>{selected.site_name || "—"}</div>
              </div>
              <div>
                <div className="label">Console</div>
                <div>
                  <Link
                    to={`/consoles/${selected.console_id}`}
                    className="hover:underline"
                  >
                    {selected.console_name}
                  </Link>
                </div>
              </div>
            </div>
            <details>
              <summary className="cursor-pointer text-xs font-medium text-ink-500">
                Raw Network API response
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
