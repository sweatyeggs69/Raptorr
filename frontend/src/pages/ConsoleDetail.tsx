import {
  ArrowDown,
  ArrowLeft,
  ArrowUp,
  ArrowUpDown,
  ChevronDown,
  ChevronRight,
  RefreshCw,
  Search,
} from "lucide-react";
import { useCallback, useEffect, useMemo, useState } from "react";
import { Link, useParams } from "react-router-dom";
import { api, ApiError } from "../api";
import PageHeader from "../components/PageHeader";

type Console = {
  id: number;
  name: string;
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
  const s = (d.state || d.status || "").toString().toLowerCase();
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

export default function ConsoleDetailPage() {
  const { consoleId } = useParams<{ consoleId: string }>();
  const [console_, setConsole] = useState<Console | null>(null);
  const [sites, setSites] = useState<LocalSite[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [siteQ, setSiteQ] = useState("");
  const [openSite, setOpenSite] = useState<string | null>(null);
  const [refreshing, setRefreshing] = useState(false);

  const load = useCallback(async () => {
    if (!consoleId) return;
    setError(null);
    try {
      const [c, s] = await Promise.all([
        api.get<Console>(`/api/consoles/${consoleId}`),
        api.get<LocalSite[]>(`/api/consoles/${consoleId}/sites`),
      ]);
      setConsole(c);
      setSites(s);
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "Load failed");
    }
  }, [consoleId]);

  useEffect(() => {
    load();
  }, [load]);

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

  if (!consoleId) return null;

  return (
    <div>
      <PageHeader
        title={console_?.name || "Console"}
        subtitle={
          console_
            ? `${console_.base_url}${console_.last_test_message ? " · " + console_.last_test_message : ""}`
            : "Loading…"
        }
        actions={
          <div className="flex gap-2">
            <Link to="/consoles" className="btn">
              <ArrowLeft size={14} />
              Back
            </Link>
            <button
              className="btn"
              onClick={async () => {
                setRefreshing(true);
                await load();
                setRefreshing(false);
              }}
              disabled={refreshing}
            >
              <RefreshCw size={14} className={refreshing ? "animate-spin" : ""} />
              Refresh
            </button>
          </div>
        }
      />
      <div className="px-8 py-6">
        {error && (
          <div className="mb-4 rounded-md border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-800">
            {error}
          </div>
        )}

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

        {sites === null && !error && (
          <div className="text-sm text-ink-500">Loading sites from console…</div>
        )}

        <div className="mb-2 text-xs text-ink-500">
          {sites ? `${filtered.length} site(s)` : ""}
          {sites && filtered.length !== sites.length && ` of ${sites.length}`}
        </div>

        <div className="space-y-2">
          {filtered.map((s) => (
            <SiteRow
              key={s.id}
              consoleId={consoleId}
              site={s}
              open={openSite === s.id}
              onToggle={() =>
                setOpenSite(openSite === s.id ? null : s.id)
              }
            />
          ))}
          {sites && filtered.length === 0 && (
            <div className="text-sm text-ink-500">No sites match.</div>
          )}
        </div>
      </div>
    </div>
  );
}

function SiteRow({
  site,
  consoleId,
  open,
  onToggle,
}: {
  site: LocalSite;
  consoleId: string;
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
          `/api/consoles/${consoleId}/sites/${encodeURIComponent(site.id)}/devices`
        ),
        api.get<LocalClient[]>(
          `/api/consoles/${consoleId}/sites/${encodeURIComponent(site.id)}/clients`
        ),
      ]);
      setDevices(d);
      setClients(c);
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "Load failed");
    } finally {
      setLoading(false);
    }
  }, [consoleId, site.id]);

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

  const displayName = site.name || site.internalReference || site.id.slice(0, 8);

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
          {loading && <div className="px-5 py-3 text-sm text-ink-500">Loading…</div>}
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
                      <td className="td font-medium">{d.name || d.model || "—"}</td>
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
