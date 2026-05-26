import React, { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { Genre, Movie } from '@/api/entities';
import { motion } from 'framer-motion';
import { Film } from 'lucide-react';
export default function Genres() {
  const [genres, setGenres] = useState([]);
  const [counts, setCounts] = useState({});
  const [loading, setLoading] = useState(true);
  useEffect(() => {
    const load = async () => {
      setLoading(true);
      try {
        const [gRes, mRes] = await Promise.all([
          Genre.paging({ page: 1, limit: 50 }),
          Movie.paging({ page: 1, limit: 200 }),
        ]);
        const gs = gRes.data?.data || [];
        const movies = mRes.data?.data || [];
        setGenres(gs);
        const c = {};
        gs.forEach(g => {
          c[g.id] = movies.filter(m => m.genreId === g.id).length;
        });
        setCounts(c);
      } catch (e) {
        console.error(e);
      } finally {
        setLoading(false);
      }
    };
    load();
  }, []);
  return (
    <div className="bg-stone-950 min-h-screen pt-24">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8 pb-20">
        <div className="text-center mb-12">
          <p className="text-amber-400 text-sm font-semibold tracking-[0.3em] uppercase mb-3">🏮 Thể Loại Phim</p>
          <h1 className="font-serif text-4xl md:text-5xl lg:text-6xl font-bold text-white mb-4">Khám Phá Theo Thể Loại</h1>
          <div className="w-24 h-1 bg-gradient-to-r from-red-600 to-amber-500 mx-auto rounded-full" />
          <p className="text-stone-400 mt-6 max-w-2xl mx-auto">Mỗi thể loại là một thế giới điện ảnh riêng. Chọn thể loại bạn yêu thích để bắt đầu hành trình khám phá.</p>
        </div>
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
          {loading ? Array.from({ length: 6 }).map((_, i) => (
            <div key={i} className="aspect-[4/3] bg-stone-800 rounded-2xl animate-pulse" />
          )) : genres.map((g, i) => (
            <motion.div
              key={g.id}
              initial={{ opacity: 0, y: 30 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: i * 0.08, duration: 0.5 }}
            >
              <Link to={`/genres/${g.slug}`} className="group block aspect-[4/3] relative rounded-2xl overflow-hidden shadow-lg shadow-black/50 hover:shadow-2xl hover:shadow-red-900/40 transition-all duration-500 hover:scale-[1.02] ring-1 ring-stone-800 hover:ring-red-600/50">
                <img src={g.thumbnailUrl} alt={g.name} className="w-full h-full object-cover transition-transform duration-700 group-hover:scale-110" />
                <div className="absolute inset-0 bg-gradient-to-t from-stone-950 via-stone-950/50 to-stone-950/10 group-hover:from-red-950/90 group-hover:via-red-950/40 transition-all duration-500" />
                <div className="absolute inset-0 flex flex-col items-center justify-end p-6 text-center">
                  <h2 className="font-serif text-3xl md:text-4xl font-bold text-white mb-2 drop-shadow-2xl">{g.name}</h2>
                  <p className="text-stone-300 text-sm mb-3 line-clamp-2 max-w-xs">{g.description}</p>
                  <span className="bg-red-600/90 backdrop-blur-sm text-white text-xs font-bold px-4 py-1.5 rounded-full inline-flex items-center gap-1.5">
                    <Film className="w-3.5 h-3.5" />
                    {counts[g.id] || 0} phim
                  </span>
                </div>
              </Link>
            </motion.div>
          ))}
        </div>
      </div>
    </div>
  );
}