import React, { useState, useEffect } from 'react';
import { useParams, Link } from 'react-router-dom';
import { Actor, Movie } from '@/api/entities';
import MovieCard from '@/components/MovieCard';
import { ChevronLeft, Calendar, Award, Film } from 'lucide-react';
import { motion } from 'framer-motion';
export default function ActorDetail() {
  const { slug } = useParams();
  const [actor, setActor] = useState(null);
  const [movies, setMovies] = useState([]);
  const [loading, setLoading] = useState(true);
  useEffect(() => {
    const load = async () => {
      setLoading(true);
      try {
        const aRes = await Actor.get(slug);
        const a = aRes.data;
        setActor(a);
        const mRes = await Movie.paging({ page: 1, limit: 100 });
        const allMovies = mRes.data?.data || [];
        setMovies(allMovies.filter(m => (m.actorIds || []).includes(a.id)));
      } catch (e) {
        console.error(e);
      } finally {
        setLoading(false);
      }
    };
    load();
    window.scrollTo(0, 0);
  }, [slug]);
  if (loading) return (
    <div className="min-h-screen bg-stone-950 pt-24 flex items-center justify-center">
      <div className="w-12 h-12 border-4 border-red-600 border-t-transparent rounded-full animate-spin" />
    </div>
  );
  if (!actor) return (
    <div className="min-h-screen bg-stone-950 pt-24 flex flex-col items-center justify-center text-center px-4">
      <h1 className="text-3xl font-bold text-white mb-2">Không tìm thấy diễn viên</h1>
      <Link to="/Actors" className="text-red-500 hover:text-red-400 mt-4">← Quay lại danh sách</Link>
    </div>
  );
  return (
    <div className="bg-stone-950 min-h-screen pt-24 relative overflow-hidden">
      <div className="absolute -right-32 top-0 w-96 h-96 bg-red-600/10 rounded-full blur-3xl pointer-events-none" />
      <div className="absolute -left-32 top-1/3 w-80 h-80 bg-amber-600/10 rounded-full blur-3xl pointer-events-none" />
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8 pb-20 relative">
        <Link to="/Actors" className="inline-flex items-center gap-2 text-stone-400 hover:text-white mb-8 transition-colors">
          <ChevronLeft className="w-5 h-5" /> Quay lại danh sách diễn viên
        </Link>
        <div className="flex flex-col md:flex-row gap-8 md:gap-12 mb-12 md:mb-16">
          <motion.div
            initial={{ opacity: 0, scale: 0.9 }}
            animate={{ opacity: 1, scale: 1 }}
            transition={{ duration: 0.6 }}
            className="flex-shrink-0 mx-auto md:mx-0"
          >
            <div className="w-48 h-48 md:w-64 md:h-64 rounded-full overflow-hidden ring-4 ring-red-600/50 shadow-2xl shadow-red-900/40">
              <div className="w-full h-full bg-gradient-to-br from-red-900 via-red-800 to-amber-900 flex items-center justify-center">
                <span className="font-serif text-7xl md:text-9xl font-bold text-white drop-shadow-2xl">{actor.name.split(' ').pop().charAt(0)}</span>
              </div>
            </div>
          </motion.div>
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.6, delay: 0.2 }}
            className="flex-1 text-center md:text-left"
          >
            <p className="text-amber-400 text-sm font-semibold tracking-[0.3em] uppercase mb-3">🏮 Diễn viên</p>
            <h1 className="font-serif text-4xl md:text-5xl lg:text-6xl font-bold text-white mb-4 leading-tight">{actor.name}</h1>
            {actor.birthYear && (
              <p className="text-stone-300 flex items-center gap-2 justify-center md:justify-start mb-4">
                <Calendar className="w-5 h-5 text-red-500" /> Sinh năm {actor.birthYear}
              </p>
            )}
            <p className="text-stone-200 leading-relaxed mb-6 text-base md:text-lg max-w-2xl">{actor.bio}</p>
            <div className="inline-flex items-start gap-2 bg-red-600/10 border border-red-600/30 rounded-lg px-4 py-3">
              <Award className="w-5 h-5 text-amber-400 flex-shrink-0 mt-0.5" />
              <div className="text-left">
                <p className="text-amber-400 font-semibold text-sm">Tác phẩm tiêu biểu</p>
                <p className="text-stone-200 text-sm">{actor.knownFor}</p>
              </div>
            </div>
          </motion.div>
        </div>
        <div className="flex items-center gap-3 mb-6">
          <div className="w-1 h-7 md:h-9 rounded-full bg-red-600" />
          <h2 className="font-serif text-2xl md:text-3xl font-bold text-white">
            Phim đã tham gia <span className="text-red-500">({movies.length})</span>
          </h2>
        </div>
        {movies.length === 0 ? (
          <div className="text-center py-12 bg-stone-900/40 rounded-2xl border border-stone-800">
            <Film className="w-12 h-12 text-stone-700 mx-auto mb-3" />
            <p className="text-stone-400">Chưa có thông tin phim trong cơ sở dữ liệu</p>
          </div>
        ) : (
          <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-6 gap-4 md:gap-6">
            {movies.map(m => <MovieCard key={m.id} movie={m} />)}
          </div>
        )}
      </div>
    </div>
  );
}