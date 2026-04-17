export type Me = {
  user: { id: number; username: string; email: string | null; role: string };
  permissions: string[];
};

export class ApiError extends Error {
  status: number;
  constructor(message: string, status: number) {
    super(message);
    this.status = status;
  }
}

async function request<T>(
  path: string,
  init: RequestInit & { json?: unknown } = {}
): Promise<T> {
  const { json, headers, ...rest } = init;
  const res = await fetch(path, {
    ...rest,
    credentials: "same-origin",
    headers: {
      ...(json !== undefined ? { "Content-Type": "application/json" } : {}),
      Accept: "application/json",
      ...(headers || {}),
    },
    body: json !== undefined ? JSON.stringify(json) : rest.body,
  });
  if (res.status === 204) return undefined as T;
  const text = await res.text();
  const data = text ? JSON.parse(text) : null;
  if (!res.ok) {
    const msg =
      (data && (data.detail || data.message)) || res.statusText || "Request failed";
    throw new ApiError(typeof msg === "string" ? msg : JSON.stringify(msg), res.status);
  }
  return data as T;
}

export const api = {
  get: <T>(path: string) => request<T>(path),
  post: <T>(path: string, json?: unknown) =>
    request<T>(path, { method: "POST", json }),
  put: <T>(path: string, json?: unknown) =>
    request<T>(path, { method: "PUT", json }),
  patch: <T>(path: string, json?: unknown) =>
    request<T>(path, { method: "PATCH", json }),
  del: <T>(path: string) => request<T>(path, { method: "DELETE" }),
};
