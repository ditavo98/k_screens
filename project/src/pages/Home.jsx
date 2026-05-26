import React, { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { Play, Info, Star, ChevronRight, Clock } from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';
import { Movie, Genre, Actor } from '@/api/entities';
import MovieRow from '@/components/MovieRow';
import MovieCard from '@/components/MovieCard';
const HERO_BG = "https://dev-cdn.vibe-x.app/apps/c1c5a2aea6bd7484870548fc/assets/original/hero-1-e12b1a8b-1a00-467c-a785-ef2d7c462610.png";
export default function Home() {
  const [featured, setFeatured] = useState([]);
  const [trending, setTrending] = useState([]);
  const [newReleases, setNewReleases] = useState([]);
  const [genres, setGenres] = useState([]);
  const [actors, setActors] = useState([]);
  const [history, setHistory] = useState([]);
  const [loading, setLoading] = useState(true);
  const [heroIndex, setHeroIndex] = useState(0);
  useEffect(() => {
    const fetchData = async () => {
      setLoading(true);
      try {
        const [featRes, trendRes, newRes, genRes, actRes, allMovRes] = await Promise.all([
          Movie.paging({ page: 1, limit: 5, filter: { isFeatured: true } }),
          Movie.paging({ page: 1, limit: 12, filter: { isTrending: true }, sort: '-viewCount' }),
          Movie.paging({ page: 1, limit: 12, filter: { isNew: true }, sort: '-releaseDate' }),
          Genre.paging({ page: 1, limit: 10 }),
          Actor.paging({ page: 1, limit: 8 }),
          Movie.paging({ page: 1, limit: 200 }),
        ]);
        setFeatured(featRes.data?.data || []);
        setTrending(trendRes.data?.data || []);
        setNewReleases(newRes.data?.data || []);
        setGenres(genRes.data?.data || []);
        setActors(actRes.data?.data || []);
        const histIds = JSON.parse(localStorage.getItem('vdrama_history') || '[]');
        if (histIds.length > 0) {
          const all = allMovRes.data?.data || [];
          const histMovies = histIds.map(id => all.find(m => m.id === id)).filter(Boolean).slice(0, 10);
          setHistory(histMovies);
        }
      } catch (e) {
        console.error(e);
      } finally {
        setLoading(false);
      }
    };
    fetchData();
  }, []);
  useEffect(() => {
    if (featured.length <= 1) return;
    const timer = setInterval(() => {
      setHeroIndex(i => (i + 1) % featured.length);
    }, 6000);
    return () => clearInterval(timer);
  }, [featured.length]);
  const current = featured[heroIndex];
  return (
    <div className="bg-stone-950 min-h-screen">
      {/* HERO */}
      <section className="relative w-full min-h-[85vh] md:min-h-[95vh] overflow-hidden">
        <AnimatePresence mode="wait">
          {current && (
            <motion.div
              key={current.id}
              initial={{ opacity: 0, scale: 1.05 }}
              animate={{ opacity: 1, scale: 1 }}
              exit={{ opacity: 0 }}
              transition={{ duration: 1.2 }}
              className="absolute inset-0"
            >
              <img src={current.backdropUrl} alt={current.title} className="w-full h-full object-cover" />
              <div className="absolute inset-0 bg-gradient-to-r from-stone-950 via-stone-950/80 to-stone-950/30" />
              <div className="absolute inset-0 bg-gradient-to-t from-stone-950 via-stone-950/30 to-transparent" />
            </motion.div>
          )}
        </AnimatePresence>
        {/* Lantern glow decoration */}
        <div className="absolute -right-32 top-1/4 w-96 h-96 bg-red-600/20 rounded-full blur-3xl pointer-events-none animate-pulse" />
        <div className="absolute -left-20 bottom-1/4 w-80 h-80 bg-amber-500/10 rounded-full blur-3xl pointer-events-none" />
        <div className="relative z-10 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 min-h-[85vh] md:min-h-[95vh] flex items-end pb-20 md:pb-32 pt-32">
          <AnimatePresence mode="wait">
            {current && (
              <motion.div
                key={current.id}
                initial={{ opacity: 0, y: 40 }}
                animate={{ opacity: 1, y: 0 }}
                exit={{ opacity: 0, y: -20 }}
                transition={{ duration: 0.7, delay: 0.2 }}
                className="max-w-2xl"
              >
                <div className="flex flex-wrap items-center gap-3 mb-4">
                  <span className="bg-red-600 text-white text-xs font-bold px-3 py-1 rounded uppercase tracking-widest">🏮 Phim Hot</span>
                  <div className="flex items-center gap-1 bg-black/40 backdrop-blur-sm px-3 py-1 rounded">
                    <Star className="w-4 h-4 fill-amber-400 text-amber-400" />
                    <span className="text-white text-sm font-semibold">{current.rating?.toFixed(1)}</span>
                  </div>
                  <span className="text-stone-200 text-sm flex items-center gap-1.5">
                    <Clock className="w-4 h-4" />
                    {current.year} • {current.duration} phút
                  </span>
                </div>
                <h1 className="font-serif text-4xl md:text-6xl lg:text-7xl font-bold text-white mb-6 drop-shadow-2xl leading-[1.05]">
                  {current.title}
                </h1>
                <p className="text-stone-200 text-base md:text-lg mb-8 line-clamp-3 leading-relaxed drop-shadow-lg max-w-xl">
                  {current.description}
                </p>
                <div className="flex flex-wrap gap-3">
                  <Link to={`/watch/${current.slug}`} className="bg-red-600 hover:bg-red-700 text-white px-6 md:px-8 py-3 md:py-4 rounded-lg font-semibold flex items-center gap-2 transition-all shadow-lg shadow-red-900/50 hover:shadow-red-700/70 hover:scale-105 active:scale-95">
                    <Play className="w-5 h-5 fill-white" />
                    Xem ngay
                  </Link>
                  <Link to={`/movies/${current.slug}`} className="bg-white/10 backdrop-blur-md hover:bg-white/20 text-white px-6 md:px-8 py-3 md:py-4 rounded-lg font-semibold flex items-center gap-2 border border-white/20 transition-all">
                    <Info className="w-5 h-5" />
                    Chi tiết
                  </Link>
                </div>
              </motion.div>
            )}
          </AnimatePresence>
        </div>
        {featured.length > 1 && (
          <div className="absolute bottom-8 left-1/2 -translate-x-1/2 z-10 flex gap-2">
            {featured.map((_, i) => (
              <button
                key={i}
                onClick={() => setHeroIndex(i)}
                className={`h-1 transition-all rounded-full ${i === heroIndex ? 'w-12 bg-red-600' : 'w-8 bg-white/30 hover:bg-white/50'}`}
                aria-label={`Slide ${i + 1}`}
              />
            ))}
          </div>
        )}
      </section>
      {/* Red glow divider */}
      <div className="h-px bg-gradient-to-r from-transparent via-red-600/60 to-transparent" />
      {/* Continue watching */}
      {history.length > 0 && (
        <MovieRow title="Tiếp tục xem" movies={history} loading={false} accent="amber" />
      )}
      {/* TRENDING NOW */}
      <MovieRow title="🔥 Phim đang hot" movies={trending} loading={loading} />
      {/* GENRES */}
      <section className="py-16 md:py-24 bg-stone-900/40 relative overflow-hidden">
        <div className="absolute -right-32 top-1/3 w-96 h-96 bg-red-600/10 rounded-full blur-3xl pointer-events-none" />
        <div className="absolute -left-32 bottom-0 w-80 h-80 bg-amber-600/10 rounded-full blur-3xl pointer-events-none" />
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 relative">
          <div className="text-center mb-12">
            <p className="text-amber-400 text-sm font-semibold tracking-[0.3em] uppercase mb-3">🏮 Khám phá</p>
            <h2 className="font-serif text-3xl md:text-5xl font-bold text-white mb-4">Theo Thể Loại</h2>
            <div className="w-20 h-1 bg-gradient-to-r from-red-600 to-amber-500 mx-auto rounded-full" />
          </div>
          <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-4 md:gap-6">
            {loading ? Array.from({ length: 6 }).map((_, i) => (
              <div key={i} className="aspect-[3/4] bg-stone-800 rounded-xl animate-pulse" />
            )) : genres.map((g, i) => (
              <motion.div
                key={g.id}
                initial={{ opacity: 0, y: 30 }}
                whileInView={{ opacity: 1, y: 0 }}
                viewport={{ once: true, margin: "-50px" }}
                transition={{ delay: i * 0.08, duration: 0.6 }}
              >
                <Link to={`/genres/${g.slug}`} className="group block relative aspect-[3/4] rounded-xl overflow-hidden ring-1 ring-stone-800 hover:ring-red-600/60 transition-all duration-500 hover:scale-[1.03]">
                  <img src={g.thumbnailUrl} alt={g.name} className="w-full h-full object-cover transition-transform duration-700 group-hover:scale-110" />
                  <div className="absolute inset-0 bg-gradient-to-t from-stone-950 via-stone-950/40 to-transparent group-hover:from-red-950/90 transition-all duration-500" />
                  <div className="absolute bottom-0 left-0 right-0 p-3 md:p-4 text-center">
                    <h3 className="font-serif text-lg md:text-xl lg:text-2xl font-bold text-white drop-shadow-lg">{g.name}</h3>
                  </div>
                </Link>
              </motion.div>
            ))}
          </div>
        </div>
      </section>
      {/* NEW RELEASES */}
      <MovieRow title="✨ Mới cập nhật" movies={newReleases} loading={loading} accent="amber" />
      {/* ACTOR SPOTLIGHT */}
      <section className="py-16 md:py-24 bg-stone-950 relative overflow-hidden">
        <div className="absolute -left-32 top-0 w-96 h-96 bg-amber-600/10 rounded-full blur-3xl pointer-events-none" />
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 relative">
          <div className="flex flex-col md:flex-row items-start md:items-end justify-between mb-12 gap-4">
            <div>
              <p className="text-amber-400 text-sm font-semibold tracking-[0.3em] uppercase mb-3">Nghệ Sĩ</p>
              <h2 className="font-serif text-3xl md:text-5xl font-bold text-white">Diễn Viên Nổi Bật</h2>
            </div>
            <Link to="/Actors" className="flex items-center gap-1 text-red-500 hover:text-red-400 transition font-medium">
              Xem tất cả <ChevronRight className="w-4 h-4" />
            </Link>
          </div>
          <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 gap-6 md:gap-8">
            {loading ? Array.from({ length: 8 }).map((_, i) => (
              <div key={i} className="text-center">
                <div className="w-24 h-24 md:w-32 md:h-32 mx-auto rounded-full bg-stone-800 animate-pulse" />
              </div>
            )) : actors.slice(0, 8).map((a, i) => (
              <motion.div
                key={a.id}
                initial={{ opacity: 0, scale: 0.85 }}
                whileInView={{ opacity: 1, scale: 1 }}
                viewport={{ once: true, margin: "-50px" }}
                transition={{ delay: i * 0.06, duration: 0.5 }}
              >
                <Link to={`/actors/${a.slug}`} className="group block text-center">
                  <div className="relative w-24 h-24 md:w-32 md:h-32 mx-auto mb-4 rounded-full overflow-hidden ring-4 ring-red-900/40 group-hover:ring-red-600 transition-all duration-500 group-hover:scale-105 shadow-xl shadow-red-900/30">
                    <div className="w-full h-full bg-gradient-to-br from-red-900 via-red-800 to-amber-900 flex items-center justify-center">
                      <span className="font-serif text-3xl md:text-5xl font-bold text-white drop-shadow">{a.name.split(' ').pop().charAt(0)}</span>
                    </div>
                  </div>
                  <h3 className="text-white font-semibold text-base md:text-lg mb-1">{a.name}</h3>
                  <p className="text-stone-400 text-xs md:text-sm line-clamp-1">{a.knownFor}</p>
                </Link>
              </motion.div>
            ))}
          </div>
        </div>
      </section>
      {/* CTA */}
      <section className="relative overflow-hidden py-20 md:py-32">
        <div className="absolute inset-0">
          <img src={HERO_BG} alt="" className="w-full h-full object-cover opacity-30" />
          <div className="absolute inset-0 bg-gradient-to-br from-red-950/90 via-stone-950/95 to-amber-950/80" />
        </div>
        <div className="absolute -right-20 top-10 w-72 h-72 bg-red-600/30 rounded-full blur-3xl animate-pulse" />
        <div className="absolute -left-20 bottom-10 w-72 h-72 bg-amber-600/20 rounded-full blur-3xl" />
        <div className="relative max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="max-w-3xl mx-auto text-center">
            <motion.div
              initial={{ opacity: 0, scale: 0.5, rotate: -15 }}
              whileInView={{ opacity: 1, scale: 1, rotate: 0 }}
              viewport={{ once: true }}
              transition={{ duration: 0.8, type: 'spring' }}
              className="inline-block mb-6"
            >
              <span className="text-6xl md:text-7xl drop-shadow-2xl">🏮</span>
            </motion.div>
            <h2 className="font-serif text-3xl md:text-5xl lg:text-6xl font-bold text-white mb-6 leading-tight drop-shadow-2xl">
              Đắm chìm trong<br />
              <span className="bg-gradient-to-r from-red-400 via-amber-400 to-red-500 bg-clip-text text-transparent">điện ảnh Việt Nam</span>
            </h2>
            <p className="text-stone-200 text-base md:text-xl mb-10 leading-relaxed drop-shadow">
              Khám phá hàng nghìn bộ phim đặc sắc, từ kinh điển đến hiện đại. Trải nghiệm điện ảnh chuẩn rạp ngay tại nhà.
            </p>
            <div className="flex flex-col sm:flex-row gap-4 justify-center">
              <Link to="/Movies" className="bg-red-600 hover:bg-red-700 text-white px-8 py-4 rounded-lg font-bold text-lg transition-all shadow-2xl shadow-red-900/60 hover:shadow-red-700/80 hover:scale-105 active:scale-95">
                Khám phá ngay
              </Link>
              <Link to="/Genres" className="bg-white/10 backdrop-blur-md hover:bg-white/20 text-white px-8 py-4 rounded-lg font-semibold text-lg border border-white/20 transition-all">
                Xem theo thể loại
              </Link>
            </div>
          </div>
        </div>
      </section>
    </div>
  );
}