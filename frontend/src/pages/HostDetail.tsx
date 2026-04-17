import {
  ArrowDown,
  ArrowLeft,
  ArrowUp,
  ArrowUpDown,
  ExternalLink,
  Info,
  Search,
  Server,
} from "lucide-react";
import { useCallback, useEffect, useMemo, useState } from "react";
import { Link, useParams } from "react-router-dom";
import { api, ApiError } from "../api";
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
};

type Site = {
  id: string | null;
  name: string | null;
  host_id: string | null;
  statistics: unknown;
};

type HostDetail = {
  host: {
    id: string | null;
    name: string | null;
    type: string | null;
    version: string | null;
    host_ip: string | null;
    console_cloud_url: string | null;
    console_local_url: string | null;
  };
  sites: Site[];
  site_count: number;
  devices: Device[];
  total_devices: number;
  note?: string;
};

type SortKey =
  | "name"
  | "device_type"
  | "is_online"
  | "model"
  | "ip"
  | "mac"
  | "uptime_sec";
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

export default function HostDetailPage() {
  const { hostId } = useParams<{ hostId: string }>();
  const [data, setData] = useState<HostDetail | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [q, setQ] = useState("");
  const [siteQ, setSiteQ] = useState("");
  const [sort, setSort] = useState<{ key: SortKey; dir: SortDir }>({
    key: "name",
    dir: "asc",
  });

  const load = useCallback(async () => {
    if (!hostId) return;
    setError(null);
    try {
      const res = await api.get<HostDetail>(
        `/api/devices/hosts/${encodeURIComponent(hostId)}`
      );
      setData(res);
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "Load failed");
    }
  }, [hostId]);

  useEffect(() => {
    load();
  }, [load]);

  const toggleSort = (key: SortKey) => {
    setSort((prev) =>
      prev.key === key
        ? { key, dir: prev.dir === "asc" ? "desc" : "asc" }
        : { key, dir: "asc" }
    );
  };

  const filteredDevices = useMemo(() => {
    if (!data) return [];
    const needle = q.trim().toLowerCase();
    const filtered = needle
      ? data.devices.filter((d) =>
          [d.name, d.mac, d.ip, d.model, d.status, d.device_type]
            .filter(Boolean)
            .some((v) => String(v).toLowerCase().includes(needle))
        )
      : data.devices;
    return [...filtered].sort((a, b) => compare(a, b, sort.key, sort.dir));
  }, [data, q, sort]);

  const filteredSites = useMemo(() => {
    if (!data) return [];
    const needle = siteQ.trim().toLowerCase();
    if (!needle) return data.sites;
    return data.sites.filter((s) =>
      (s.name || "").toLowerCase().includes(needle)
    );
  }, [data, siteQ]);

  if (!hostId) return null;

  return (
    <div>
      <PageHeader
        title={data?.host.name || "Console"}
        subtitle={
          data
            ? `${data.host.type || "UniFi OS"} · ${data.host.version || "—"} · ${data.total_devices} device${data.total_devices === 1 ? "" : "s"} · ${data.site_count} site${data.site_count === 1 ? "" : "s"}`
            : "Loading…"
        }
        actions={
          <div className="flex gap-2">
            <Link to="/hosts" className="btn">
              <ArrowLeft size={14} />
              Back
            </Link>
            {data?.host.console_local_url && (
              <a
                className="btn"
                href={data.host.console_local_url}
                target="_blank"
                rel="noreferrer noopener"
              >
                <Server size={14} />
                Local
              </a>
            )}
            {data?.host.console_cloud_url && (
              <a
                className="btn btn-primary"
                href={data.host.console_cloud_url}
                target="_blank"
                rel="noreferrer noopener"
              >
                <ExternalLink size={14} />
                Open in UniFi
              </a>
            )}
          </div>
        }
      />
      <div className="px-8 py-6">
        {error && (
          <div className="mb-4 rounded-md border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-800">
            {error}
          </div>
        )}

        {data?.note && (
          <div className="mb-4 flex items-start gap-2 rounded-md border border-amber-200 bg-amber-50 px-3 py-2 text-xs text-amber-900">
            <Info size={14} className="mt-0.5 shrink-0" />
            <span>{data.note}</span>
          </div>
        )}

        <div className="grid grid-cols-1 gap-6 lg:grid-cols-[minmax(0,260px)_minmax(0,1fr)]">
          {/* Sites */}
          <div>
            <div className="mb-2 flex items-center justify-between">
              <h2 className="text-sm font-semibold text-ink-900">
                Sites ({data?.site_count ?? 0})
              </h2>
            </div>
            <div className="relative mb-2">
              <Search
                size={14}
                className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-ink-400"
              />
              <input
                className="input pl-9"
                placeholder="Filter sites…"
                value={siteQ}
                onChange={(e) => setSiteQ(e.target.value)}
              />
            </div>
            <div className="card max-h-[calc(100vh-300px)] overflow-auto">
              {filteredSites.length === 0 && (
                <div className="px-4 py-3 text-xs text-ink-500">
                  {data?.site_count ? "No matches." : "No sites."}
                </div>
              )}
              <ul className="divide-y divide-ink-100">
                {filteredSites.map((s) => (
                  <li
                    key={s.id || s.name || ""}
                    className="px-4 py-2 text-sm text-ink-800"
                  >
                    {s.name || "—"}
                  </li>
                ))}
              </ul>
            </div>
          </div>

          {/* Devices */}
          <div>
            <div className="mb-2 flex items-center justify-between">
              <h2 className="text-sm font-semibold text-ink-900">
                Devices ({data?.total_devices ?? 0})
              </h2>
            </div>
            <div className="relative mb-2 max-w-md">
              <Search
                size={14}
                className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-ink-400"
              />
              <input
                className="input pl-9"
                placeholder="Filter devices…"
                value={q}
                onChange={(e) => setQ(e.target.value)}
              />
            </div>
            <div className="card overflow-hidden">
              <div className="max-h-[calc(100vh-300px)] overflow-auto">
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
                    </tr>
                  </thead>
                  <tbody>
                    {filteredDevices.length === 0 && (
                      <tr>
                        <td className="td text-ink-500" colSpan={7}>
                          No devices match.
                        </td>
                      </tr>
                    )}
                    {filteredDevices.map((d, i) => (
                      <tr
                        key={(d.id || "") + (d.mac || "") + i}
                        className="border-t border-ink-100 hover:bg-ink-50"
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
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
