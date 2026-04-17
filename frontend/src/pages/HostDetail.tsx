import {
  ArrowDown,
  ArrowLeft,
  ArrowUp,
  ArrowUpDown,
  ChevronDown,
  ChevronRight,
  ExternalLink,
  Info,
  Plug,
  Search,
  Server,
  Zap,
} from "lucide-react";
import { useCallback, useEffect, useMemo, useState } from "react";
import { Link, useParams } from "react-router-dom";
import { api, ApiError } from "../api";
import PageHeader from "../components/PageHeader";

type CloudHost = {
  id: string | null;
  name: string | null;
  type: string | null;
  version: string | null;
  host_ip: string | null;
  console_cloud_url: string | null;
  console_local_url: string | null;
};

type CloudDevice = {
  id: string | null;
  name: string | null;
  model: string | null;
  mac: string | null;
  ip: string | null;
  status: string | null;
  is_online: boolean | null;
  device_type: string;
  uptime_sec: number | null;
};

type CloudHostDetail = {
  host: CloudHost;
  sites: {
    id: string | null;
    name: string | null;
  }[];
  site_count: number;
  devices: CloudDevice[];
  total_devices: number;
  note?: string;
};

type Integration = {
  host_id: string;
  base_url: string;
  last_test_ok: boolean | null;
  last_test_message: string | null;
};

type LocalSite = {
  id: string;
  internalReference?: string;
  name?: string;
};

type LocalDevice = Record<string, any>;
type LocalClient = Record<string, any>;

type SortKey = "name" | "model" | "ip" | "mac" | "state" | "uptime";
type SortDir = "asc" | "desc";

function statusFromLocal(d: LocalDevice): {
  online: boolean | null;
  label: string;
} {
  const s = (d.state || d.status || d.adoption?.state || "").toString().toLowerCase();
  if (!s) return { online: null, label: "unknown" };
  if (/online|connected|adopted/.test(s)) return { online: true, label: s };
  if (/offline|disconnected|unreachable|pending/.test(s))
    return { online: false, label: s };
  return { online: null, label: s };
}

function fmtUptime(sec: number | null | undefined) {
  if (!sec) return "—";
  const d = Math.floor(sec / 86400);
  const h = Math.floor((sec % 86400) / 3600);
  if (d > 0) return `${d}d ${h}h`;
  const m = Math.floor((sec % 3600) / 60);
  if (h > 0) return `${h}h ${m}m`;
  return `${m}m`;
}

function sortDevices(
  devices: LocalDevice[],
  key: SortKey,
  dir: SortDir
): LocalDevice[] {
  const sign = dir === "asc" ? 1 : -1;
  return [...devices].sort((a, b) => {
    if (key === "state") {
      const ra = statusFromLocal(a);
      const rb = statusFromLocal(b);
      const rank = (v: boolean | null) => (v === true ? 0 : v === null ? 1 : 2);
      return (rank(ra.online) - rank(rb.online)) * sign;
    }
    if (key === "uptime") {
      return ((a.uptime || 0) - (b.uptime || 0)) * sign;
    }
    const fld =
      key === "name"
        ? "name"
        : key === "model"
          ? "model"
          : key === "ip"
            ? "ipAddress"
            : "macAddress";
    const av = String(a[fld] || a[fld === "ipAddress" ? "ip" : "mac"] || "");
    const bv = String(b[fld] || b[fld === "ipAddress" ? "ip" : "mac"] || "");
    return av.localeCompare(bv, undefined, { numeric: true }) * sign;
  });
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
  const [cloud, setCloud] = useState<CloudHostDetail | null>(null);
  const [integration, setIntegration] = useState<Integration | null>(null);
  const [localSites, setLocalSites] = useState<LocalSite[] | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!hostId) return;
    (async () => {
      setError(null);
      try {
        const res = await api.get<CloudHostDetail>(
          `/api/devices/hosts/${encodeURIComponent(hostId)}`
        );
        setCloud(res);
      } catch (err) {
        setError(err instanceof ApiError ? err.message : "Load failed");
      }
      try {
        const i = await api.get<Integration>(
          `/api/consoles/integrations/${encodeURIComponent(hostId)}`
        );
        setIntegration(i);
      } catch (err) {
        if (err instanceof ApiError && err.status === 404) {
          setIntegration(null);
        }
      }
    })();
  }, [hostId]);

  useEffect(() => {
    if (!hostId || !integration) return;
    (async () => {
      try {
        const sites = await api.get<LocalSite[]>(
          `/api/consoles/${encodeURIComponent(hostId)}/sites`
        );
        setLocalSites(sites);
      } catch (err) {
        setError(err instanceof ApiError ? err.message : "Local sites failed");
      }
    })();
  }, [hostId, integration]);

  if (!hostId) return null;

  const useLocal = !!integration;

  return (
    <div>
      <PageHeader
        title={cloud?.host.name || "Console"}
        subtitle={
          cloud
            ? `${cloud.host.type || "UniFi OS"} · ${cloud.host.version || "—"}`
            : "Loading…"
        }
        actions={
          <div className="flex gap-2">
            <Link to="/hosts" className="btn">
              <ArrowLeft size={14} />
              Back
            </Link>
            {cloud?.host.console_local_url && (
              <a
                className="btn"
                href={cloud.host.console_local_url}
                target="_blank"
                rel="noreferrer noopener"
              >
                <Server size={14} />
                Local
              </a>
            )}
            {cloud?.host.console_cloud_url && (
              <a
                className="btn btn-primary"
                href={cloud.host.console_cloud_url}
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

        {useLocal ? (
          <div className="mb-4 flex items-start gap-2 rounded-md border border-emerald-200 bg-emerald-50 px-3 py-2 text-xs text-emerald-900">
            <Zap size={14} className="mt-0.5 shrink-0" />
            <span>
              Using live data from the local Network Integration API at{" "}
              <span className="font-mono">{integration!.base_url}</span>. Sites and
              devices below reflect real-time state on the console.
            </span>
          </div>
        ) : (
          <div className="mb-4 flex items-start gap-2 rounded-md border border-amber-200 bg-amber-50 px-3 py-2 text-xs text-amber-900">
            <Info size={14} className="mt-0.5 shrink-0" />
            <span>
              Showing cloud Site Manager data only — this can lag and has no per-site
              attribution.{" "}
              <Link to="/settings" className="inline-flex items-center gap-1 underline">
                <Plug size={12} /> Configure local integration
              </Link>{" "}
              for real-time devices per site.
            </span>
          </div>
        )}

        {useLocal ? (
          <LocalView hostId={hostId} sites={localSites} />
        ) : (
          <CloudView cloud={cloud} />
        )}
      </div>
    </div>
  );
}

function CloudView({ cloud }: { cloud: CloudHostDetail | null }) {
  const [q, setQ] = useState("");
  const [sort, setSort] = useState<{
    key: "name" | "device_type" | "model" | "ip" | "mac" | "is_online" | "uptime_sec";
    dir: SortDir;
  }>({ key: "name", dir: "asc" });

  const sorted = useMemo(() => {
    if (!cloud) return [];
    const needle = q.trim().toLowerCase();
    const filtered = needle
      ? cloud.devices.filter((d) =>
          [d.name, d.mac, d.ip, d.model, d.status, d.device_type]
            .filter(Boolean)
            .some((v) => String(v).toLowerCase().includes(needle))
        )
      : cloud.devices;
    const sign = sort.dir === "asc" ? 1 : -1;
    return [...filtered].sort((a, b) => {
      if (sort.key === "is_online") {
        const rank = (v: boolean | null) =>
          v === true ? 0 : v === null ? 1 : 2;
        return (rank(a.is_online) - rank(b.is_online)) * sign;
      }
      if (sort.key === "uptime_sec") {
        return ((a.uptime_sec ?? -1) - (b.uptime_sec ?? -1)) * sign;
      }
      return (
        String((a as any)[sort.key] ?? "").localeCompare(
          String((b as any)[sort.key] ?? ""),
          undefined,
          { numeric: true }
        ) * sign
      );
    });
  }, [cloud, q, sort]);

  const toggle = (k: typeof sort.key) =>
    setSort((p) =>
      p.key === k
        ? { key: k, dir: p.dir === "asc" ? "desc" : "asc" }
        : { key: k, dir: "asc" }
    );

  return (
    <div>
      <div className="relative mb-3 max-w-md">
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
      <div className="mb-2 text-xs text-ink-500">
        {cloud?.total_devices ?? 0} device(s) · {cloud?.site_count ?? 0} site(s)
      </div>
      <div className="card overflow-hidden">
        <div className="max-h-[calc(100vh-300px)] overflow-auto">
          <table className="w-full border-collapse">
            <thead>
              <tr>
                <th className="th">
                  <button onClick={() => toggle("name")} className="inline-flex items-center gap-1">
                    Name
                  </button>
                </th>
                <th className="th">
                  <button onClick={() => toggle("device_type")}>Type</button>
                </th>
                <th className="th">
                  <button onClick={() => toggle("model")}>Model</button>
                </th>
                <th className="th">
                  <button onClick={() => toggle("mac")}>MAC</button>
                </th>
                <th className="th">
                  <button onClick={() => toggle("ip")}>IP</button>
                </th>
                <th className="th">
                  <button onClick={() => toggle("is_online")}>Status</button>
                </th>
                <th className="th">
                  <button onClick={() => toggle("uptime_sec")}>Uptime</button>
                </th>
              </tr>
            </thead>
            <tbody>
              {sorted.length === 0 && (
                <tr>
                  <td className="td text-ink-500" colSpan={7}>
                    No devices.
                  </td>
                </tr>
              )}
              {sorted.map((d, i) => (
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
                  <td className="td">
                    {d.is_online === true ? (
                      <span className="badge badge-ok">{d.status || "online"}</span>
                    ) : d.is_online === false ? (
                      <span className="badge badge-bad">{d.status || "offline"}</span>
                    ) : (
                      <span className="badge badge-warn">{d.status || "unknown"}</span>
                    )}
                  </td>
                  <td className="td">{fmtUptime(d.uptime_sec)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}

function LocalView({
  hostId,
  sites,
}: {
  hostId: string;
  sites: LocalSite[] | null;
}) {
  const [siteQ, setSiteQ] = useState("");
  const [openSite, setOpenSite] = useState<string | null>(null);

  const filtered = useMemo(() => {
    if (!sites) return [];
    const needle = siteQ.trim().toLowerCase();
    const list = needle
      ? sites.filter((s) =>
          [s.name, s.internalReference, s.id]
            .filter(Boolean)
            .some((v) => String(v).toLowerCase().includes(needle))
        )
      : sites;
    return [...list].sort((a, b) =>
      (a.name || a.internalReference || a.id).localeCompare(
        b.name || b.internalReference || b.id
      )
    );
  }, [sites, siteQ]);

  if (!sites) {
    return <div className="text-sm text-ink-500">Loading sites from console…</div>;
  }

  return (
    <div>
      <div className="relative mb-3 max-w-md">
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
      <div className="mb-2 text-xs text-ink-500">
        {filtered.length} site(s){" "}
        {sites.length !== filtered.length && `of ${sites.length}`}
      </div>
      <div className="space-y-2">
        {filtered.map((s) => (
          <SiteRow
            key={s.id}
            site={s}
            hostId={hostId}
            open={openSite === s.id}
            onToggle={() => setOpenSite(openSite === s.id ? null : s.id)}
          />
        ))}
        {filtered.length === 0 && (
          <div className="text-sm text-ink-500">No sites match.</div>
        )}
      </div>
    </div>
  );
}

function SiteRow({
  site,
  hostId,
  open,
  onToggle,
}: {
  site: LocalSite;
  hostId: string;
  open: boolean;
  onToggle: () => void;
}) {
  const [devices, setDevices] = useState<LocalDevice[] | null>(null);
  const [clients, setClients] = useState<LocalClient[] | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [sort, setSort] = useState<{ key: SortKey; dir: SortDir }>({
    key: "name",
    dir: "asc",
  });

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const [d, c] = await Promise.all([
        api.get<LocalDevice[]>(
          `/api/consoles/${encodeURIComponent(hostId)}/sites/${encodeURIComponent(site.id)}/devices`
        ),
        api.get<LocalClient[]>(
          `/api/consoles/${encodeURIComponent(hostId)}/sites/${encodeURIComponent(site.id)}/clients`
        ),
      ]);
      setDevices(d);
      setClients(c);
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "Load failed");
    } finally {
      setLoading(false);
    }
  }, [hostId, site.id]);

  useEffect(() => {
    if (open && !devices && !loading) load();
  }, [open, devices, loading, load]);

  const sorted = useMemo(
    () => (devices ? sortDevices(devices, sort.key, sort.dir) : []),
    [devices, sort]
  );

  const toggle = (k: SortKey) =>
    setSort((p) =>
      p.key === k
        ? { key: k, dir: p.dir === "asc" ? "desc" : "asc" }
        : { key: k, dir: "asc" }
    );

  const displayName =
    site.name || site.internalReference || site.id.slice(0, 8);

  return (
    <div className="card overflow-hidden">
      <button
        onClick={onToggle}
        className="flex w-full items-center justify-between px-5 py-3 hover:bg-ink-50"
      >
        <div className="flex items-center gap-2">
          {open ? (
            <ChevronDown size={16} className="text-ink-500" />
          ) : (
            <ChevronRight size={16} className="text-ink-500" />
          )}
          <span className="text-sm font-semibold text-ink-900">{displayName}</span>
          {devices && (
            <span className="text-xs text-ink-500">
              {devices.length} device{devices.length === 1 ? "" : "s"}
              {clients && ` · ${clients.length} client${clients.length === 1 ? "" : "s"}`}
            </span>
          )}
        </div>
      </button>
      {open && (
        <div className="border-t border-ink-100">
          {loading && (
            <div className="px-5 py-3 text-sm text-ink-500">Loading…</div>
          )}
          {error && (
            <div className="m-3 rounded-md border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-800">
              {error}
            </div>
          )}
          {devices && !loading && (
            <table className="w-full border-collapse">
              <thead>
                <tr>
                  <SortableTh label="Name" field="name" sort={sort} onToggle={toggle} />
                  <SortableTh label="Model" field="model" sort={sort} onToggle={toggle} />
                  <SortableTh label="MAC" field="mac" sort={sort} onToggle={toggle} />
                  <SortableTh label="IP" field="ip" sort={sort} onToggle={toggle} />
                  <SortableTh label="State" field="state" sort={sort} onToggle={toggle} />
                  <SortableTh label="Uptime" field="uptime" sort={sort} onToggle={toggle} />
                </tr>
              </thead>
              <tbody>
                {sorted.length === 0 && (
                  <tr>
                    <td className="td text-ink-500" colSpan={6}>
                      No devices in this site.
                    </td>
                  </tr>
                )}
                {sorted.map((d, i) => {
                  const st = statusFromLocal(d);
                  return (
                    <tr
                      key={(d.id || d.macAddress || d.mac || "") + i}
                      className="border-t border-ink-100"
                    >
                      <td className="td font-medium">
                        {d.name || d.model || "—"}
                      </td>
                      <td className="td">{d.model || "—"}</td>
                      <td className="td font-mono text-xs">
                        {d.macAddress || d.mac || "—"}
                      </td>
                      <td className="td font-mono text-xs">
                        {d.ipAddress || d.ip || "—"}
                      </td>
                      <td className="td">
                        {st.online === true ? (
                          <span className="badge badge-ok">{st.label}</span>
                        ) : st.online === false ? (
                          <span className="badge badge-bad">{st.label}</span>
                        ) : (
                          <span className="badge badge-warn">{st.label}</span>
                        )}
                      </td>
                      <td className="td">{fmtUptime(d.uptime)}</td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          )}
        </div>
      )}
    </div>
  );
}
