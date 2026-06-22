'use client';
import { useRouter } from 'next/navigation';

export function MediaModerationForm({ photoId }: { photoId: string }) {
  const router = useRouter();
  async function moderate(status: 'APPROVED' | 'REJECTED') {
    const csrf = document.cookie.split('; ').find((row) => row.startsWith('nc_csrf='))?.split('=')[1];
    await fetch(`/admin-api/media/${photoId}`, {
      method: 'PATCH',
      headers: { 'content-type': 'application/json', ...(csrf ? { 'x-csrf-token': csrf } : {}) },
      body: JSON.stringify({ status })
    });
    router.refresh();
  }
  return (
    <div className="flex gap-2">
      <button type="button" onClick={() => moderate('APPROVED')} className="rounded-lg bg-emerald-600 px-3 py-1.5 text-sm font-semibold text-white hover:bg-emerald-700">
        Approve
      </button>
      <button type="button" onClick={() => moderate('REJECTED')} className="rounded-lg bg-rose-600 px-3 py-1.5 text-sm font-semibold text-white hover:bg-rose-700">
        Reject
      </button>
    </div>
  );
}
