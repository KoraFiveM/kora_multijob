declare global { interface Window { GetParentResourceName?: () => string } }
export const resource = () => window.GetParentResourceName?.() ?? "qbmultijob";
export async function nui<T>(action: string, data: unknown = {}): Promise<T | null> {
  try {
    const response = await fetch(`https://${resource()}/${action}`, { method: "POST", headers: { "Content-Type": "application/json; charset=UTF-8" }, body: JSON.stringify(data) });
    return response.ok ? await response.json() as T : null;
  } catch { return null; }
}
export function applyTheme(tokens: unknown) {
  if (!tokens || typeof tokens !== "object") return;
  for (const [key, value] of Object.entries(tokens as Record<string, unknown>)) if (typeof value === "string") document.documentElement.style.setProperty(`--${key}`, value);
}
