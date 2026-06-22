import { api } from '@/lib/api';

type Metrics = {
  metrics: {
    date: string;
    activeUsers: number;
    signups: number;
    friendRequests: number;
    messages: number;
    revenueCents: number;
  }[];
};

function maxMetric(metrics: Metrics['metrics'], key: keyof Metrics['metrics'][number]) {
  return Math.max(1, ...metrics.map((metric) => metric[key] as number));
}

export default async function Analytics() {
  const { metrics } = await api<Metrics>('/admin/analytics');
  const maxSignups = maxMetric(metrics, 'signups');
  const maxFriends = maxMetric(metrics, 'friendRequests');
  return (
    <>
      <h2 className="text-3xl font-black">Analytics</h2>
      <div className="mt-8 grid gap-6 lg:grid-cols-2">
        <div className="rounded-2xl border bg-white p-6">
          <h3 className="font-bold">Daily signups</h3>
          <div className="mt-4 flex h-40 items-end gap-1">
            {metrics.map((metric) => (
              <div key={`signup-${metric.date}`} className="flex flex-1 flex-col items-center gap-1">
                <div className="w-full rounded-t bg-rose-500" style={{ height: `${(metric.signups / maxSignups) * 100}%`, minHeight: metric.signups ? 4 : 0 }} />
                <span className="text-[10px] text-slate-500">{new Date(metric.date).getDate()}</span>
              </div>
            ))}
          </div>
        </div>
        <div className="rounded-2xl border bg-white p-6">
          <h3 className="font-bold">New friendships</h3>
          <div className="mt-4 flex h-40 items-end gap-1">
            {metrics.map((metric) => (
              <div key={`friend-${metric.date}`} className="flex flex-1 flex-col items-center gap-1">
                <div className="w-full rounded-t bg-indigo-500" style={{ height: `${(metric.friendRequests / maxFriends) * 100}%`, minHeight: metric.friendRequests ? 4 : 0 }} />
                <span className="text-[10px] text-slate-500">{new Date(metric.date).getDate()}</span>
              </div>
            ))}
          </div>
        </div>
      </div>
      <div className="mt-8 overflow-x-auto rounded-2xl border bg-white">
        <table className="w-full text-left text-sm">
          <thead className="bg-slate-100">
            <tr>
              {['Date', 'Active', 'Signups', 'Friends', 'Messages', 'Revenue'].map((label) => (
                <th key={label} className="p-4">
                  {label}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {metrics.map((metric) => (
              <tr key={metric.date} className="border-t">
                <td className="p-4">{new Date(metric.date).toLocaleDateString()}</td>
                <td className="p-4">{metric.activeUsers}</td>
                <td className="p-4">{metric.signups}</td>
                <td className="p-4">{metric.friendRequests}</td>
                <td className="p-4">{metric.messages}</td>
                <td className="p-4">${(metric.revenueCents / 100).toFixed(2)}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </>
  );
}
