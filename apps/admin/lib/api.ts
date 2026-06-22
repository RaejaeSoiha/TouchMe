import { cookies } from 'next/headers';

const baseUrl = process.env.API_INTERNAL_URL ?? process.env.NEXT_PUBLIC_API_URL ?? 'http://localhost:3000/api/v1';

export async function api<T>(path: string): Promise<T> {
  const token = (await cookies()).get('nc_admin_access')?.value;
  if (!token) throw new Error('UNAUTHORIZED');
  const response = await fetch(`${baseUrl}${path}`, { headers: { authorization: `Bearer ${token}` }, cache: 'no-store' });
  if (response.status === 401 || response.status === 403) throw new Error('UNAUTHORIZED');
  if (!response.ok) throw new Error(`API request failed: ${response.status}`);
  return response.json() as Promise<T>;
}

export type UserRow = { id: string; email?: string; phone?: string; role: string; status: string; createdAt: string; lastActiveAt: string; profile?: { displayName: string; verificationStatus: string } };
export type ReportRow = { id: string; reason: string; status: string; details?: string; createdAt: string; reporter: { id: string; profile?: { displayName: string } }; reported: { id: string; status: string; profile?: { displayName: string; photos: { url: string }[] } } };
export type SubscriptionRow = { id: string; status: string; currentPeriodEnd: string; user: { email?: string; profile?: { displayName: string } }; plan: { name: string; priceCents: number } };
export type MediaRow = { id: string; url: string; createdAt: string; profile: { userId: string; displayName: string } };
export type PlanRow = { id: string; name: string; code: string; priceCents: number; active: boolean; unlimitedLikes: boolean; passportMode: boolean; monthlyBoosts: number };

