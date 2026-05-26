import React, { useRef } from 'react';
import { ChevronLeft, ChevronRight } from 'lucide-react';
import MovieCard from './MovieCard';
export default function MovieRow({ title, movies, loading, accent = 'red' }) {
  const scrollRef = useRef(null);
  const scroll = (dir) => {
    if (!scrollRef.current) return;
    const card = scrollRef.current.querySelector('.movie-card-item');
    const cardWidth = card ? card.offsetWidth + 16 : 220;
    scrollRef.current.scrollBy({ left: dir * cardWidth * 2, behavior: 'smooth' });
  };
  if (!loading && (!movies || movies.length === 0)) return null;
  return (
    <section className="py-10 md:py-14 overflow-hidden relative">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex items-center justify-between mb-6">
          <div className="flex items-center gap-3">
            <div className={`w-1 h-7 md:h-9 rounded-full ${accent === 'amber' ? 'bg-amber-500' : 'bg-red-600'}`} />
            <h2 className="font-serif text-2xl md:text-3xl lg:text-4xl font-bold text-white">{title}</h2>
          </div>
          <div className="hidden md:flex gap-2">
            <button onClick={() => scroll(-1)} className="w-10 h-10 rounded-full bg-stone-800/80 hover:bg-red-600 text-white flex items-center justify-center transition-all border border-stone-700 hover:border-red-600" aria-label="Trước">
              <ChevronLeft className="w-5 h-5" />
            </button>
            <button onClick={() => scroll(1)} className="w-10 h-10 rounded-full bg-stone-800/80 hover:bg-red-600 text-white flex items-center justify-center transition-all border border-stone-700 hover:border-red-600" aria-label="Sau">
              <ChevronRight className="w-5 h-5" />
            </button>
          </div>
        </div>
        <div ref={scrollRef} className="flex gap-4 overflow-x-auto pb-4 scrollbar-hide -mx-4 px-4">
          {loading ? Array.from({ length: 6 }).map((_, i) => (
            <div key={i} className="movie-card-item flex-shrink-0 w-36 md:w-48 lg:w-52 aspect-[2/3] bg-stone-800 rounded-xl animate-pulse" />
          )) : movies.map(movie => (
            <div key={movie.id} className="movie-card-item flex-shrink-0 w-36 md:w-48 lg:w-52">
              <MovieCard movie={movie} />
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}