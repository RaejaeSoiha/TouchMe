import { api, type MediaRow } from '@/lib/api';
import { MediaModerationForm } from '@/components/media-moderation-form';

export default async function MediaPage() {
  const photos = await api<MediaRow[]>('/admin/media');
  return (
    <>
      <h2 className="text-3xl font-black">Media moderation</h2>
      <p className="mt-2 text-slate-600">Review pending profile photos before they appear in discovery.</p>
      <div className="mt-8 overflow-x-auto rounded-2xl border bg-white">
        <table className="w-full text-left text-sm">
          <thead className="bg-slate-100">
            <tr>
              {['Preview', 'User', 'Uploaded', 'Actions'].map((label) => (
                <th key={label} className="p-4">
                  {label}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {photos.length === 0 ? (
              <tr>
                <td colSpan={4} className="p-8 text-center text-slate-500">
                  No photos awaiting review.
                </td>
              </tr>
            ) : (
              photos.map((photo) => (
                <tr key={photo.id} className="border-t">
                  <td className="p-4">
                    <img src={photo.url} alt="" className="h-24 w-24 rounded-xl object-cover" />
                  </td>
                  <td className="p-4">{photo.profile.displayName}</td>
                  <td className="p-4">{new Date(photo.createdAt).toLocaleString()}</td>
                  <td className="p-4">
                    <MediaModerationForm photoId={photo.id} />
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>
    </>
  );
}
