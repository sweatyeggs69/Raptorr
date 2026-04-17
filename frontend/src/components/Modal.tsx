import { X } from "lucide-react";
import { ReactNode, useEffect } from "react";

export default function Modal({
  open,
  onClose,
  title,
  children,
  footer,
}: {
  open: boolean;
  onClose: () => void;
  title: string;
  children: ReactNode;
  footer?: ReactNode;
}) {
  useEffect(() => {
    if (!open) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") onClose();
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [open, onClose]);

  if (!open) return null;
  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-ink-900/40 p-4"
      onClick={onClose}
    >
      <div
        className="card w-full max-w-lg"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="flex items-center justify-between border-b border-ink-200 px-5 py-3">
          <h2 className="text-sm font-semibold text-ink-900">{title}</h2>
          <button
            onClick={onClose}
            className="rounded p-1 text-ink-500 hover:bg-ink-100"
            aria-label="Close"
          >
            <X size={16} />
          </button>
        </div>
        <div className="px-5 py-4">{children}</div>
        {footer && (
          <div className="flex justify-end gap-2 border-t border-ink-200 bg-ink-50 px-5 py-3">
            {footer}
          </div>
        )}
      </div>
    </div>
  );
}
