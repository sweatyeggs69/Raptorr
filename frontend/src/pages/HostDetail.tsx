import { ArrowLeft, ChevronDown, ChevronRight, ExternalLink, Server } from "lucide-react";
import { useCallback, useEffect, useState } from "react";
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
  uptime_sec: number | null;
  site_id: string | null;
  site_name: string | null;
};

type Site = {
  id: string | null;
  name: string | null;
  host_id: string | null;
  device_count: number;
  devices: Device[];
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
  total_devices: number;
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

export default function HostDetailPage() {
  const { hostId } = useParams<{ hostId: string }>();
  const [data, setData] = useState<HostDetail | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [openSites, setOpenSites] = useState<Set<string>>(new Set());

  const load = useCallback(async () => {
    if (!hostId) return;
    setError(null);
    try {
      const res = await api.get<HostDetail>(
        `/api/devices/hosts/${encodeURIComponent(hostId)}`
      );
      setData(res);
      // expand first site by default
      if (res.sites[0]?.id) {
        setOpenSites(new Set([res.sites[0].id]));
      } else if (res.sites[0]) {
        setOpenSites(new Set(["__unassigned"]));
      }
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "Load failed");
    }
  }, [hostId]);

  useEffect(() => {
    load();
  }, [load]);

  function toggle(key: string) {
    const next = new Set(openSites);
    if (next.has(key)) next.delete(key);
    else next.add(key);
    setOpenSites(next);
  }

  if (!hostId) return null;

  return (
    <div>
      <PageHeader
        title={data?.host.name || "Console"}
        subtitle={
          data
            ? `${data.host.type || "UniFi OS"} · ${data.host.version || "—"} · ${data.total_devices} device${data.total_devices === 1 ? "" : "s"} across ${data.sites.length} site${data.sites.length === 1 ? "" : "s"}`
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

        {data && data.sites.length === 0 && (
          <div className="card p-6 text-sm text-ink-500">
            No sites found on this console.
          </div>
        )}

        <div className="space-y-3">
          {data?.sites.map((s) => {
            const key = s.id || "__unassigned";
            const isOpen = openSites.has(key);
            return (
              <div key={key} className="card overflow-hidden">
                <button
                  onClick={() => toggle(key)}
                  className="flex w-full items-center justify-between px-5 py-3 hover:bg-ink-50"
                >
                  <div className="flex items-center gap-2">
                    {isOpen ? (
                      <ChevronDown size={16} className="text-ink-500" />
                    ) : (
                      <ChevronRight size={16} className="text-ink-500" />
                    )}
                    <span className="text-sm font-semibold text-ink-900">
                      {s.name || "(unnamed site)"}
                    </span>
                    <span className="text-xs text-ink-500">
                      {s.device_count} device{s.device_count === 1 ? "" : "s"}
                    </span>
                  </div>
                </button>
                {isOpen && (
                  <div className="border-t border-ink-100">
                    <table className="w-full border-collapse">
                      <thead>
                        <tr>
                          <th className="th">Name</th>
                          <th className="th">Model</th>
                          <th className="th">MAC</th>
                          <th className="th">IP</th>
                          <th className="th">Status</th>
                          <th className="th">Uptime</th>
                        </tr>
                      </thead>
                      <tbody>
                        {s.devices.length === 0 && (
                          <tr>
                            <td className="td text-ink-500" colSpan={6}>
                              No devices in this site.
                            </td>
                          </tr>
                        )}
                        {s.devices.map((d, i) => (
                          <tr
                            key={(d.id || "") + (d.mac || "") + i}
                            className="border-t border-ink-100"
                          >
                            <td className="td font-medium">{d.name || "—"}</td>
                            <td className="td">{d.model || "—"}</td>
                            <td className="td font-mono text-xs">
                              {d.mac || "—"}
                            </td>
                            <td className="td font-mono text-xs">
                              {d.ip || "—"}
                            </td>
                            <td className="td">{statusBadge(d.status)}</td>
                            <td className="td">{fmtUptime(d.uptime_sec)}</td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                )}
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
}
