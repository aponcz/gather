export function StatusBadge({ status }: { status?: string }) {
  return <span className={`badge badge-${status ?? 'default'}`}>{status ?? 'unknown'}</span>;
}
