import { api } from '@/lib/api'; import { StatCard } from '@/components/stat-card';
type Metrics = { users: number; activeUsers: number; friendRequests: number; messages: number; activeSubscriptions: number };
export default async function Dashboard() { const data = await api<Metrics>('/admin/analytics'); return <><h2 className="text-3xl font-black">Platform health</h2><p className="mt-2 text-slate-500">Thirty-day operating snapshot.</p><div className="mt-8 grid gap-5 sm:grid-cols-2 xl:grid-cols-5"><StatCard label="All users" value={data.users}/><StatCard label="Active users" value={data.activeUsers}/><StatCard label="New friends" value={data.friendRequests}/><StatCard label="Messages" value={data.messages}/><StatCard label="Premium" value={data.activeSubscriptions}/></div></>; }

