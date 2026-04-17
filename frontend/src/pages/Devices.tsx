import {
  ArrowDown,
  ArrowUp,
  ArrowUpDown,
  ExternalLink,
  RefreshCw,
  Search,
  Server,
} from "lucide-react";
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
  is_online: boolean | null;
  device_type: string;
  adopted: boolean | null;
  uptime_sec: number | null;
  site: string | null;
  site_id: string | null;
  site_name: string | null;
  host_id: string | null;
  host_name: string | null;
  host_ip: string | null;
  console_cloud_url: string | null;
  console_local_url: string | null;
  raw: Record<string, unknown>;
};

type SearchResponse = {
  total_hosts: number;
  total_sites: number;
  total_devices: number;
  devices: Device[];
  cache: { age_seconds: number | null; ttl_seconds: number };
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
  | "host_name";

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

function fmtCacheAge(sec: number | null): string {
  if (sec === null || Number.isNaN(sec)) return "just now";
  const s = Math.round(sec);
  if (s < 5) return "just now";
  if (s < 60) return `${s}s ago`;
  const m = Math.floor(s / 60);
  return `${m}m ago`;
}

function compare(a: Device, b: Device, key: SortKey, dir: SortDir): number {
  const sign = dir === "asc" ? 1 : -1;
  if (key === "is_online") {
    // online (true) > unknown (null) > offline (false)
    const rank = (v: boolean | null) => (v === true ? 0 : v === null ? 1 : 2);
    return (rank(a.is_online) - rank(b.is_online)) * sign;
  }
  if (key === "uptime_sec") {
    const av = a.uptime_sec ?? -1;
    const bv = b.uptime_sec ?? -1;
    return (av - bv) * sign;
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
  align = "left",
}: {
  label: string;
  field: SortKey;
  sort: { key: SortKey; dir: SortDir };
  onToggle: (k: SortKey) => void;
  align?: "left" | "right";
}) {
  const active = sort.key === field;
  const Icon = active ? (sort.dir === "asc" ? ArrowUp : ArrowDown) : ArrowUpDown;
  return (
    <th className="th">
      <button
        onClick={() => onToggle(field)}
        className={`inline-flex items-center gap-1 ${active ? "text-ink-900" : "text-ink-500"} hover:text-ink-900 ${align === "right" ? "ml-auto" : ""}`}
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
  const [now, setNow] = useState(Date.now());
  const [fetchedAt, setFetchedAt] = useState<number | null>(null);

  const fetchDevices = useCallback(async (needle: string) => {
    setLoading(true);
    setError(null);
    try {
      const res = await api.get<SearchResponse>(
        `/api/devices/search${needle ? `?q=${encodeURIComponent(needle)}` : ""}`
      );
      setData(res);
      setFetchedAt(Date.now());
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

  // tick every 5s so the "updated Ns ago" label stays fresh
  useEffect(() => {
    const id = setInterval(() => setNow(Date.now()), 5000);
    return () => clearInterval(id);
  }, []);

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
    return `${data.total_devices} device${data.total_devices === 1 ? "" : "s"} · ${data.total_sites} site${data.total_sites === 1 ? "" : "s"} · ${data.total_hosts} console${data.total_hosts === 1 ? "" : "s"}`;
  }, [data]);

  const cacheLabel = useMemo(() => {
    if (!data?.cache || fetchedAt === null) return "";
    const baseAge = data.cache.age_seconds ?? 0;
    const extra = Math.max(0, (now - fetchedAt) / 1000);
    return `updated ${fmtCacheAge(baseAge + extra)}`;
  }, [data, fetchedAt, now]);

  return (
    <div>
      <PageHeader
        title="Devices"
        subtitle="Search every device across all sites behind your API key."
        actions={
          <div className="flex items-center gap-3">
            {data?.cache && (
              <span className="text-xs text-ink-500">{cacheLabel}</span>
            )}
            <button className="btn" onClick={refresh} disabled={loading}>
              <RefreshCw size={14} className={loading ? "animate-spin" : ""} />
              Refresh
            </button>
          </div>
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
            placeholder="Search by name, MAC, IP, model, site, type…"
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
                  <SortableTh label="Name" field="name" sort={sort} onToggle={toggleSort} />
                  <SortableTh label="Type" field="device_type" sort={sort} onToggle={toggleSort} />
                  <SortableTh label="Model" field="model" sort={sort} onToggle={toggleSort} />
                  <SortableTh label="MAC" field="mac" sort={sort} onToggle={toggleSort} />
                  <SortableTh label="IP" field="ip" sort={sort} onToggle={toggleSort} />
                  <SortableTh label="Status" field="is_online" sort={sort} onToggle={toggleSort} />
                  <SortableTh label="Uptime" field="uptime_sec" sort={sort} onToggle={toggleSort} />
                  <SortableTh label="Site" field="site_name" sort={sort} onToggle={toggleSort} />
                  <SortableTh label="Console" field="host_name" sort={sort} onToggle={toggleSort} />
                  <th className="th text-right">Open</th>
                </tr>
              </thead>
              <tbody>
                {loading && !data && (
                  <tr>
                    <td className="td text-ink-500" colSpan={10}>
                      Loading…
                    </td>
                  </tr>
                )}
                {data && sorted.length === 0 && (
                  <tr>
                    <td className="td text-ink-500" colSpan={10}>
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
                    <td className="td">{d.site_name || d.site || "—"}</td>
                    <td className="td text-ink-500">{d.host_name || "—"}</td>
                    <td className="td text-right">
                      {d.console_cloud_url ? (
                        <a
                          href={d.console_cloud_url}
                          target="_blank"
                          rel="noreferrer noopener"
                          onClick={(e) => e.stopPropagation()}
                          className="inline-flex items-center gap-1 text-ink-500 hover:text-ink-900"
                          title="Open console at unifi.ui.com"
                        >
                          <ExternalLink size={14} />
                        </a>
                      ) : (
                        <span className="text-ink-300">—</span>
                      )}
                    </td>
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
          <>
            {selected?.console_local_url && (
              <a
                className="btn mr-auto"
                href={selected.console_local_url}
                target="_blank"
                rel="noreferrer noopener"
              >
                <Server size={14} />
                Open local ({selected.host_ip})
              </a>
            )}
            {selected?.console_cloud_url && (
              <a
                className="btn btn-primary"
                href={selected.console_cloud_url}
                target="_blank"
                rel="noreferrer noopener"
              >
                <ExternalLink size={14} />
                Open in UniFi
              </a>
            )}
            <button className="btn" onClick={() => setSelected(null)}>
              Close
            </button>
          </>
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
                <div>{selected.site_name || selected.site || "—"}</div>
              </div>
              <div>
                <div className="label">Console</div>
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
