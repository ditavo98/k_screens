import { Link } from 'react-router-dom';
import { Play, Star, Clock } from 'lucide-react';
export default function MovieCard({ movie, onPlayTrailer, size = 'default' }) {
  const handlePlayClick = (e) => {
    e.preventDefault();
    e.stopPropagation();
    if (onPlayTrailer) onPlayTrailer(movie);
  };
  return (
    <Link
      to={`/movies/${movie.slug}`}
      className="group block"
    >
      <div className="relative aspect-[2/3] rounded-xl overflow-hidden bg-zinc-900 border border-zinc-800 group-hover:border-amber-500/40 transition-all duration-500 shadow-lg group-hover:shadow-2xl group-hover:shadow-amber-500/10">
        {movie.posterUrl ? (
          <img
            src={movie.posterUrl}
            alt={movie.title}
            className="w-full h-full object-cover group-hover:scale-110 transition-transform duration-700"
          />
        ) : (
          <div className="w-full h-full bg-zinc-900 flex items-center justify-center">
            <span className="font-display text-zinc-700 text-2xl">K</span>
          </div>
        )}
        <div className="absolute inset-0 bg-gradient-to-t from-zinc-950 via-zinc-950/40 to-transparent opacity-90" />
        {movie.isComingSoon && (
          <div className="absolute top-3 left-3 px-2.5 py-1 bg-amber-500 text-zinc-950 text-xs font-bold rounded-md">
            SẮP RA MẮT
          </div>
        )}
        {movie.isTrending && !movie.isComingSoon && (
          <div className="absolute top-3 left-3 px-2.5 py-1 bg-red-600 text-white text-xs font-bold rounded-md">
            HOT
          </div>
        )}
        {movie.rating && (
          <div className="absolute top-3 right-3 px-2 py-1 bg-zinc-950/80 backdrop-blur-md rounded-md flex items-center gap-1">
            <Star className="w-3 h-3 text-amber-400 fill-amber-400" />
            <span className="text-xs font-bold text-white">{movie.rating}</span>
          </div>
        )}
        <button
          onClick={handlePlayClick}
          className="absolute inset-0 flex items-center justify-center opacity-0 group-hover:opacity-100 transition-all duration-300"
          aria-label={`Phát trailer ${movie.title}`}
        >
          <div className="w-16 h-16 md:w-20 md:h-20 rounded-full bg-amber-500/90 backdrop-blur-md flex items-center justify-center shadow-2xl shadow-amber-500/50 transform group-hover:scale-110 transition-transform">
            <Play className="w-7 h-7 md:w-9 md:h-9 text-zinc-950 ml-1 fill-zinc-950" />
          </div>
        </button>
        <div className="absolute bottom-0 left-0 right-0 p-3 md:p-4">
          <h3 className={`font-display font-bold text-white leading-tight ${size === 'large' ? 'text-xl md:text-2xl' : 'text-base md:text-lg'}`}>
            {movie.title}
          </h3>
          <div className="flex items-center gap-2 text-xs text-zinc-400 mt-1.5">
            <span>{movie.year}</span>
            <span className="text-amber-500/60">•</span>
            <span>{movie.genre}</span>
            {movie.duration && (
              <>
                <span className="text-amber-500/60">•</span>
                <span className="flex items-center gap-1">
                  <Clock className="w-3 h-3" />
                  {movie.duration}p
                </span>
              </>
            )}
          </div>
        </div>
      </div>
    </Link>
  );
}