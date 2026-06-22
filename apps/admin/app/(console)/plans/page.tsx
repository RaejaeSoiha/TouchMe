import { api, type PlanRow } from '@/lib/api';
import { PlanToggleForm } from '@/components/plan-toggle-form';

export default async function PlansPage() {
  const plans = await api<PlanRow[]>('/admin/plans');
  return (
    <>
      <h2 className="text-3xl font-black">Subscription plans</h2>
      <p className="mt-2 text-slate-600">Enable or disable premium plans offered at checkout.</p>
      <div className="mt-8 overflow-x-auto rounded-2xl border bg-white">
        <table className="w-full text-left text-sm">
          <thead className="bg-slate-100">
            <tr>
              {['Plan', 'Price', 'Features', 'Status', 'Actions'].map((label) => (
                <th key={label} className="p-4">
                  {label}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {plans.map((plan) => (
              <tr key={plan.id} className="border-t">
                <td className="p-4 font-semibold">{plan.name}</td>
                <td className="p-4">${(plan.priceCents / 100).toFixed(2)}/mo</td>
                <td className="p-4">
                  <ul className="list-disc pl-4 text-slate-600">
                    {plan.unlimitedLikes && <li>Unlimited friend requests</li>}
                    {plan.passportMode && <li>Explore other cities</li>}
                    {plan.monthlyBoosts > 0 && <li>{plan.monthlyBoosts} featured boosts/month</li>}
                  </ul>
                </td>
                <td className="p-4">
                  <span className={`rounded-full px-3 py-1 text-xs font-bold ${plan.active ? 'bg-emerald-100 text-emerald-800' : 'bg-slate-200 text-slate-700'}`}>
                    {plan.active ? 'Active' : 'Inactive'}
                  </span>
                </td>
                <td className="p-4">
                  <PlanToggleForm planId={plan.id} active={plan.active} />
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </>
  );
}
