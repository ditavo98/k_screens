import React, { useState, useEffect } from 'react';
import { useParams, Link } from 'react-router-dom';
import { Genre, Movie } from '@/api/entities';
import MovieCard from '@/components/MovieCard';
import { ChevronLeft, Film } from 'lucide-react';
export default function GenreDetail() {
  const { slug } = useParams();
  const [genre, setGenre] = useState(null);
  const [movies, setMovies] = useState([]);
  const [loading, setLoading] = useState(true);
  const [sort, setSort] = useState('-rating');
  useEffect(() => {
    const load = async () => {
      setLoading(true);
      try {
        const gRes = await Genre.get(slug);
        const g = gRes.data;
        setGenre(g);
        const mRes = await Movie.paging({ page: 1, limit: 100, filter: { genreId: g.id }, sort });
        setMovies(mRes.data?.data || []);
      } catch (e) {
        console.error(e);
      } finally {
        setLoading(false);
      }
    };
    load();
    window.scrollTo(0, 0);
  }, [slug, sort]);
  if (loading && !genre) return (
    <div className="min-h-screen bg-stone-950 pt-24 flex items-center justify-center">
      <div className="w-12 h-12 border-4 border-red-600 border-t-transparent rounded-full animate-spin" />
    </div>
  );
  if (!genre) return (
    <div className="min-h-screen bg-stone-950 pt-24 flex flex-col items-center justify-center text-center px-4">
      <Film className="w-16 h-16 text-stone-700 mb-4" />
      <h1 className="text-3xl font-bold text-white">Không tìm thấy thể loại</h1>
      <Link to="/Genres" className="text-red-500 hover:text-red-400 mt-4">← Quay lại danh sách thể loại</Link>
    </div>
  );
  return (
    <div className="bg-stone-950 min-h-screen">
      {/* Hero */}
      <section className="relative h-[50vh] md:h-[60vh] overflow-hidden">
        <img src={genre.thumbnailUrl} alt={genre.name} className="w-full h-full object-cover" />
        <div className="absolute inset-0 bg-gradient-to-t from-stone-950 via-stone-950/70 to-stone-950/30" />
        <div className="absolute inset-0 bg-gradient-to-r from-stone-950/80 to-transparent" />
        <div className="absolute -right-20 top-1/4 w-72 h-72 bg-red-600/20 rounded-full blur-3xl pointer-events-none" />
        <div className="absolute inset-0 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 flex flex-col justify-end pb-12 pt-24">
          <Link to="/Genres" className="inline-flex items-center gap-2 text-stone-300 hover:text-white mb-4 self-start transition-colors">
            <ChevronLeft className="w-5 h-5" /> Quay lại thể loại
          </Link>
          <span className="text-amber-400 text-sm font-semibold tracking-widest uppercase mb-2">🏮 Thể loại</span>
          <h1 className="font-serif text-5xl md:text-7xl font-bold text-white mb-3 drop-shadow-2xl leading-none">{genre.name}</h1>
          <p className="text-stone-300 text-lg max-w-2xl drop-shadow">{genre.description}</p>
        </div>
      </section>
      <section className="py-12 md:py-16">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between mb-8 gap-4">
            <h2 className="font-serif text-2xl md:text-3xl font-bold text-white">
              <span className="text-red-500">{movies.length}</span> phim {genre.name.toLowerCase()}
            </h2>
            <select value={sort} onChange={(e) => setSort(e.target.value)} className="px-4 py-2 bg-stone-800 text-white rounded-lg border border-stone-700 focus:border-red-600 outline-none">
              <option value="-rating">Đánh giá cao</option>
              <option value="-releaseDate">Mới nhất</option>
              <option value="-viewCount">Lượt xem nhiều</option>
              <option value="title">Tên A-Z</option>
            </select>
          </div>
          {loading ? (
            <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-6 gap-4 md:gap-6">
              {Array.from({ length: 6 }).map((_, i) => <div key={i} className="aspect-[2/3] bg-stone-800 rounded-xl animate-pulse" />)}
            </div>
          ) : movies.length === 0 ? (
            <div className="text-center py-16">
              <Film className="w-16 h-16 text-stone-700 mx-auto mb-4" />
              <p className="text-stone-400">Chưa có phim nào trong thể loại này</p>
            </div>
          ) : (
            <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-6 gap-4 md:gap-6">
              {movies.map(m => <MovieCard key={m.id} movie={m} />)}
            </div>
          )}
        </div>
      </section>
    </div>
  );
}