'use client';
import { useRouter } from 'next/navigation';

export function PlanToggleForm({ planId, active }: { planId: string; active: boolean }) {
  const router = useRouter();
  async function toggle() {
    const csrf = document.cookie.split('; ').find((row) => row.startsWith('nc_csrf='))?.split('=')[1];
    await fetch(`/admin-api/plans/${planId}`, {
      method: 'PATCH',
      headers: { 'content-type': 'application/json', ...(csrf ? { 'x-csrf-token': csrf } : {}) },
      body: JSON.stringify({ active: !active })
    });
    router.refresh();
  }
  return (
    <button
      type="button"
      onClick={toggle}
      className={`rounded-lg px-3 py-1.5 text-sm font-semibold text-white ${active ? 'bg-slate-600 hover:bg-slate-700' : 'bg-emerald-600 hover:bg-emerald-700'}`}
    >
      {active ? 'Deactivate' : 'Activate'}
    </button>
  );
}
