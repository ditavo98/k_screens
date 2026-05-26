import React from 'react';
import { Link } from 'react-router-dom';
import { Star, Play } from 'lucide-react';
export default function MovieCard({ movie }) {
  if (!movie) return null;
  return (
    <Link to={`/movies/${movie.slug}`} className="group block">
      <div className="relative aspect-[2/3] rounded-xl overflow-hidden bg-stone-900 shadow-lg shadow-black/40 transition-all duration-500 group-hover:scale-[1.04] group-hover:shadow-2xl group-hover:shadow-red-900/50 ring-1 ring-stone-800/50 group-hover:ring-red-600/40">
        <img
          src={movie.posterUrl}
          alt={movie.title}
          loading="lazy"
          className="w-full h-full object-cover transition-transform duration-700 group-hover:scale-110"
        />
        <div className="absolute inset-0 bg-gradient-to-t from-black/95 via-black/20 to-transparent" />
        {movie.isNew && (
          <span className="absolute top-2 left-2 bg-red-600 text-white text-[10px] font-bold px-2 py-0.5 rounded uppercase tracking-wider">Mới</span>
        )}
        <div className="absolute top-2 right-2 flex items-center gap-1 bg-black/60 backdrop-blur-sm px-2 py-0.5 rounded">
          <Star className="w-3 h-3 fill-amber-400 text-amber-400" />
          <span className="text-white text-xs font-semibold">{movie.rating?.toFixed(1)}</span>
        </div>
        <div className="absolute bottom-0 left-0 right-0 p-3">
          <h3 className="text-white font-bold text-sm md:text-base mb-1 line-clamp-1 drop-shadow-lg">{movie.title}</h3>
          <p className="text-stone-300 text-xs">{movie.year} • {movie.duration} phút</p>
        </div>
        <div className="absolute inset-0 flex items-center justify-center opacity-0 group-hover:opacity-100 bg-black/30 transition-opacity duration-500">
          <div className="w-12 h-12 md:w-14 md:h-14 rounded-full bg-red-600/90 flex items-center justify-center shadow-xl shadow-red-900/60">
            <Play className="w-5 h-5 md:w-7 md:h-7 fill-white text-white ml-0.5" />
          </div>
        </div>
      </div>
    </Link>
  );
}