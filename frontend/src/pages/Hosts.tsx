import { ExternalLink, Server } from "lucide-react";
import { useEffect, useState } from "react";
import { api, ApiError } from "../api";
import PageHeader from "../components/PageHeader";

type Host = {
  id: string | null;
  name: string | null;
  hardware_id: string | null;
  type: string | null;
  version: string | null;
  host_ip: string | null;
  console_cloud_url: string | null;
  console_local_url: string | null;
  raw: Record<string, unknown>;
};

export default function HostsPage() {
  const [hosts, setHosts] = useState<Host[] | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    (async () => {
      try {
        setHosts(await api.get<Host[]>("/api/devices/hosts"));
      } catch (err) {
        setError(err instanceof ApiError ? err.message : "Load failed");
      }
    })();
  }, []);

  return (
    <div>
      <PageHeader
        title="UOS consoles"
        subtitle="Every UniFi OS server visible to your API key."
      />
      <div className="px-8 py-6">
        {error && (
          <div className="mb-4 rounded-md border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-800">
            {error}
          </div>
        )}
        <div className="card overflow-hidden">
          <table className="w-full border-collapse">
            <thead>
              <tr>
                <th className="th">Name</th>
                <th className="th">Type</th>
                <th className="th">Version</th>
                <th className="th">IP</th>
                <th className="th text-right">Open</th>
              </tr>
            </thead>
            <tbody>
              {!hosts && !error && (
                <tr>
                  <td className="td text-ink-500" colSpan={5}>
                    Loading…
                  </td>
                </tr>
              )}
              {hosts && hosts.length === 0 && (
                <tr>
                  <td className="td text-ink-500" colSpan={5}>
                    No hosts visible.
                  </td>
                </tr>
              )}
              {hosts?.map((h) => (
                <tr
                  key={h.id || h.hardware_id || h.name || ""}
                  className="border-t border-ink-100 hover:bg-ink-50"
                >
                  <td className="td font-medium">{h.name || "—"}</td>
                  <td className="td">{h.type || "—"}</td>
                  <td className="td text-ink-500">{h.version || "—"}</td>
                  <td className="td font-mono text-xs">{h.host_ip || "—"}</td>
                  <td className="td text-right">
                    <div className="flex justify-end gap-1">
                      {h.console_local_url && (
                        <a
                          className="btn btn-ghost px-2 py-1"
                          href={h.console_local_url}
                          target="_blank"
                          rel="noreferrer noopener"
                          title={`Local UI at ${h.host_ip}`}
                        >
                          <Server size={14} />
                        </a>
                      )}
                      {h.console_cloud_url && (
                        <a
                          className="btn px-2 py-1"
                          href={h.console_cloud_url}
                          target="_blank"
                          rel="noreferrer noopener"
                          title="Open in unifi.ui.com"
                        >
                          <ExternalLink size={14} />
                        </a>
                      )}
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
