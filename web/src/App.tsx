import { useEffect, useMemo, useState } from "react";
import { BriefcaseBusiness, Check, ChevronRight, CircleDollarSign, Clock3, LogOut, Power, Shield, X } from "lucide-react";
import { nui } from "./nui";

type Job = { name: string; label: string; level: number; rank: string; pay: number; icon: string; dutyLocked: boolean };
type Roster = { jobs: Job[]; active: { name: string; onDuty: boolean } };
type Reply = { ok: boolean; roster?: Roster; error?: string };

export function App() {
  const [roster, setRoster] = useState<Roster | null>(null);
  const [busy, setBusy] = useState(false);
  const [notice, setNotice] = useState<string | null>(null);
  const jobs = useMemo(() => [...(roster?.jobs ?? [])].sort((a, b) => b.pay - a.pay || a.label.localeCompare(b.label)), [roster]);

  useEffect(() => {
    const handler = (event: MessageEvent<{ action?: string; data?: unknown }>) => {
      if (event.data.action === "qbmultijob:open") setRoster(event.data.data as Roster);
      if (event.data.action === "qbmultijob:close") { setRoster(null); setNotice(null); }
    };
    const key = (event: KeyboardEvent) => { if (event.key === "Escape" && roster) void close(); };
    window.addEventListener("message", handler); window.addEventListener("keydown", key);
    return () => { window.removeEventListener("message", handler); window.removeEventListener("keydown", key); };
  }, [roster]);

  async function run(action: string, data: object = {}) {
    setBusy(true); setNotice(null);
    const reply = await nui<Reply>(action, data);
    setBusy(false);
    if (reply?.roster) setRoster(reply.roster);
    if (!reply?.ok) setNotice(reply?.error ?? "That action could not be completed.");
  }
  async function close() { await nui("qbmultijob:close"); setRoster(null); }
  if (!roster) return null;

  return <main className="roster-shell" aria-label="Job roster">
    <header className="topbar">
      <div className="brand-mark"><BriefcaseBusiness size={19} /><span><b>EMPLOYMENT</b><small>Job roster</small></span></div>
      <div className="topbar-status"><span className="pulse" />{roster.active.onDuty ? "On duty" : "Off duty"}</div>
      <button className="icon-button" onClick={() => void close()} aria-label="Close"><X size={17} /></button>
    </header>
    <section className="heading">
      <p className="eyebrow">AVAILABLE POSITIONS</p><h1>Your work portfolio</h1><p className="muted">Choose an active position, manage your duty status, or leave a role you no longer need.</p>
    </section>
    {notice && <div className="notice"><Shield size={15} />{notice}<button className="notice-dismiss" onClick={() => setNotice(null)} aria-label="Dismiss message"><X size={14} /></button></div>}
    <section className="job-grid">
      {jobs.map((job) => {
        const current = job.name === roster.active.name;
        return <article className={`job-card ${current ? "active" : ""}`} key={job.name}>
          <div className="job-card-head"><div className="job-icon"><BriefcaseBusiness size={21} /></div><div><h2>{job.label}</h2><p>{job.rank}</p></div>{current && <span className="active-chip"><Check size={11} /> Active</span>}</div>
          <div className="pay-row"><span><CircleDollarSign size={15} /> Paycheck</span><strong>${job.pay.toLocaleString()}<small>/hr</small></strong></div>
          <footer>
            {current
              ? <button className={`duty-button ${roster.active.onDuty ? "on" : ""}`} disabled={busy || job.dutyLocked} onClick={() => void run("qbmultijob:toggleDuty")}><Power size={14} />{job.dutyLocked ? "Duty locked" : roster.active.onDuty ? "End duty" : "Start duty"}</button>
              : <>
                <button className="select-button" disabled={busy} onClick={() => void run("qbmultijob:selectJob", { name: job.name })}>Set active <ChevronRight size={15} /></button>
                {job.name !== "unemployed" && <button className="leave-button" disabled={busy} onClick={() => void run("qbmultijob:quitJob", { name: job.name })} title="Leave role"><LogOut size={15} /></button>}
              </>}
          </footer>
        </article>;
      })}
    </section>
    <footer className="shortcut"><Clock3 size={13} /><span><kbd>ESC</kbd> Close employment</span></footer>
  </main>;
}
