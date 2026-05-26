import React, { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { Movie } from '@/api/entities';
import MovieCard from '@/components/MovieCard';
import { Heart, Trash2 } from 'lucide-react';
import { motion } from 'framer-motion';
export default function Favorites() {
  const [movies, setMovies] = useState([]);
  const [loading, setLoading] = useState(true);
  const load = async () => {
    setLoading(true);
    try {
      const favs = JSON.parse(localStorage.getItem('vdrama_favorites') || '[]');
      if (favs.length === 0) {
        setMovies([]);
        return;
      }
      const res = await Movie.paging({ page: 1, limit: 200 });
      const all = res.data?.data || [];
      setMovies(all.filter(m => favs.includes(m.id)));
    } catch (e) {
      console.error(e);
    } finally {
      setLoading(false);
    }
  };
  useEffect(() => {
    load();
  }, []);
  const clearAll = () => {
    if (window.confirm('Bạn có chắc muốn xóa tất cả phim yêu thích?')) {
      localStorage.setItem('vdrama_favorites', '[]');
      setMovies([]);
    }
  };
  return (
    <div className="bg-stone-950 min-h-screen pt-24 relative overflow-hidden">
      <div className="absolute -right-32 top-1/4 w-96 h-96 bg-red-600/10 rounded-full blur-3xl pointer-events-none" />
      <div className="absolute -left-32 top-1/2 w-80 h-80 bg-amber-600/10 rounded-full blur-3xl pointer-events-none" />
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8 pb-20 relative">
        <div className="text-center mb-12">
          <motion.div
            initial={{ scale: 0.5, opacity: 0 }}
            animate={{ scale: 1, opacity: 1 }}
            transition={{ type: 'spring', duration: 0.8 }}
            className="inline-block"
          >
            <Heart className="w-14 h-14 md:w-16 md:h-16 text-red-600 mx-auto mb-4 fill-red-600 drop-shadow-[0_0_20px_rgba(220,38,38,0.5)]" />
          </motion.div>
          <p className="text-amber-400 text-sm font-semibold tracking-[0.3em] uppercase mb-2">🏮 Bộ Sưu Tập</p>
          <h1 className="font-serif text-4xl md:text-5xl font-bold text-white mb-2">Phim Yêu Thích</h1>
          <p className="text-stone-400">
            {movies.length > 0 ? `${movies.length} phim đang chờ bạn xem` : 'Lưu lại những bộ phim đặc biệt của bạn'}
          </p>
        </div>
        {loading ? (
          <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-6 gap-4 md:gap-6">
            {Array.from({ length: 6 }).map((_, i) => <div key={i} className="aspect-[2/3] bg-stone-800 rounded-xl animate-pulse" />)}
          </div>
        ) : movies.length === 0 ? (
          <div className="text-center py-16">
            <div className="inline-block p-6 rounded-full bg-stone-900/60 border border-stone-800 mb-6">
              <Heart className="w-16 h-16 text-stone-700" />
            </div>
            <h3 className="text-2xl font-serif font-bold text-white mb-3">Chưa có phim yêu thích</h3>
            <p className="text-stone-400 mb-8 max-w-md mx-auto">Khám phá và thêm những bộ phim yêu thích vào bộ sưu tập của bạn để xem lại bất cứ lúc nào</p>
            <Link to="/Movies" className="inline-block bg-red-600 hover:bg-red-700 text-white px-8 py-4 rounded-lg font-semibold transition-all shadow-lg shadow-red-900/50 hover:scale-105">
              Khám phá phim ngay
            </Link>
          </div>
        ) : (
          <>
            <div className="flex items-center justify-between mb-6">
              <h2 className="text-white font-semibold text-lg">{movies.length} phim đã lưu</h2>
              <button onClick={clearAll} className="flex items-center gap-2 px-4 py-2 text-red-500 hover:text-white hover:bg-red-600 border border-red-600/30 hover:border-red-600 rounded-lg transition-all text-sm font-medium">
                <Trash2 className="w-4 h-4" /> Xóa tất cả
              </button>
            </div>
            <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-6 gap-4 md:gap-6">
              {movies.map(m => <MovieCard key={m.id} movie={m} />)}
            </div>
          </>
        )}
      </div>
    </div>
  );
}