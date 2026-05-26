import { useEffect } from 'react';
import { X } from 'lucide-react';
export default function TrailerModal({ youtubeId, title, onClose }) {
  useEffect(() => {
    const handleEsc = (e) => {
      if (e.key === 'Escape') onClose();
    };
    document.addEventListener('keydown', handleEsc);
    document.body.style.overflow = 'hidden';
    return () => {
      document.removeEventListener('keydown', handleEsc);
      document.body.style.overflow = '';
    };
  }, [onClose]);
  if (!youtubeId) return null;
  return (
    <div
      className="fixed inset-0 z-50 bg-black/95 backdrop-blur-sm flex items-center justify-center p-4 animate-fadeInUp"
      onClick={onClose}
    >
      <button
        onClick={onClose}
        className="absolute top-4 right-4 md:top-6 md:right-6 z-10 w-10 h-10 md:w-12 md:h-12 rounded-full bg-zinc-900/80 border border-zinc-700 text-white hover:bg-amber-500 hover:text-zinc-950 hover:border-amber-500 transition-all flex items-center justify-center"
        aria-label="Close trailer"
      >
        <X className="w-5 h-5 md:w-6 md:h-6" />
      </button>
      <div
        className="w-full max-w-5xl"
        onClick={(e) => e.stopPropagation()}
      >
        {title && (
          <h3 className="font-display text-xl md:text-2xl font-bold text-white mb-4">
            {title}
          </h3>
        )}
        <div className="relative aspect-video w-full bg-zinc-900 rounded-xl overflow-hidden shadow-2xl shadow-amber-500/10">
          <iframe
            src={`https://www.youtube.com/embed/${youtubeId}?autoplay=1&rel=0`}
            title={title || 'Movie Trailer'}
            className="absolute inset-0 w-full h-full"
            allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
            allowFullScreen
          />
        </div>
      </div>
    </div>
  );
}