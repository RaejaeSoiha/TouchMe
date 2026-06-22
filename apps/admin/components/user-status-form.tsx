'use client';
import { useState } from 'react';
export function UserStatusForm({ userId, current }: { userId: string; current: string }) {
  const [status, setStatus] = useState(current); const [busy, setBusy] = useState(false);
  async function update(next: string) { setBusy(true); const csrf = document.cookie.split('; ').find((part) => part.startsWith('nc_csrf='))?.split('=')[1] ?? ''; const response = await fetch(`/admin-api/users/${userId}/status`, { method: 'PATCH', headers: { 'content-type': 'application/json', 'x-csrf-token': decodeURIComponent(csrf) }, body: JSON.stringify({ status: next }) }); if (response.ok) setStatus(next); setBusy(false); }
  return <select aria-label="Account status" disabled={busy} value={status} onChange={(event) => update(event.target.value)} className="rounded-lg border p-2 text-sm"><option>ACTIVE</option><option>SUSPENDED</option><option>BANNED</option></select>;
}
