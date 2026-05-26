import React, { useState, useEffect, useRef } from 'react';
import { useParams, useSearchParams, Link } from 'react-router-dom';
import { Movie } from '@/api/entities';
import { ChevronLeft, List, Star, Calendar, Clock, Film } from 'lucide-react';
import MovieCard from '@/components/MovieCard';
export default function Watch() {
  const { slug } = useParams();
  const [searchParams] = useSearchParams();
  const currentEp = Number(searchParams.get('ep') || 1);
  const [movie, setMovie] = useState(null);
  const [similar, setSimilar] = useState([]);
  const [loading, setLoading] = useState(true);
  const videoRef = useRef(null);
  useEffect(() => {
    setLoading(true);
    const load = async () => {
      try {
        const res = await Movie.get(slug);
        const m = res.data;
        setMovie(m);
        // Save to watch history
        const hist = JSON.parse(localStorage.getItem('vdrama_history') || '[]');
        const updated = [m.id, ...hist.filter(id => id !== m.id)].slice(0, 10);
        localStorage.setItem('vdrama_history', JSON.stringify(updated));
        // Fetch similar
        const sRes = await Movie.paging({ page: 1, limit: 10, filter: { genreId: m.genreId } });
        setSimilar((sRes.data?.data || []).filter(s => s.id !== m.id).slice(0, 6));
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
    <div className="min-h-screen bg-black flex items-center justify-center">
      <div className="w-12 h-12 border-4 border-red-600 border-t-transparent rounded-full animate-spin" />
    </div>
  );
  if (!movie) return (
    <div className="min-h-screen bg-black flex flex-col items-center justify-center text-center px-4">
      <Film className="w-16 h-16 text-stone-700 mb-4" />
      <h1 className="text-2xl font-bold text-white mb-2">Phim không tồn tại</h1>
      <Link to="/Movies" className="text-red-500 hover:text-red-400 mt-2">← Quay lại danh sách phim</Link>
    </div>
  );
  return (
    <div className="min-h-screen bg-black pb-16">
      <div className="max-w-7xl mx-auto pt-20 px-4 sm:px-6 lg:px-8">
        <Link to={`/movies/${movie.slug}`} className="inline-flex items-center gap-2 text-stone-400 hover:text-white mb-4 transition-colors">
          <ChevronLeft className="w-5 h-5" /> Quay lại chi tiết phim
        </Link>
        {/* Video player */}
        <div className="aspect-video w-full bg-black rounded-2xl overflow-hidden mb-6 ring-1 ring-stone-900 shadow-2xl shadow-red-900/30 relative">
          <video
            ref={videoRef}
            controls
            poster={movie.backdropUrl}
            className="w-full h-full"
            src={movie.videoUrl || "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4"}
          >
            Trình duyệt của bạn không hỗ trợ video.
          </video>
        </div>
        {/* Title bar */}
        <div className="flex items-start justify-between flex-wrap gap-4 mb-6">
          <div>
            <h1 className="font-serif text-2xl md:text-4xl font-bold text-white mb-2">{movie.title}</h1>
            <div className="flex flex-wrap items-center gap-4 text-sm">
              {movie.totalEpisodes > 1 && <span className="text-red-500 font-semibold">Tập {currentEp}/{movie.totalEpisodes}</span>}
              <span className="flex items-center gap-1 text-stone-400"><Star className="w-4 h-4 fill-amber-400 text-amber-400" /> {movie.rating?.toFixed(1)}</span>
              <span className="flex items-center gap-1 text-stone-400"><Calendar className="w-4 h-4" /> {movie.year}</span>
              <span className="flex items-center gap-1 text-stone-400"><Clock className="w-4 h-4" /> {movie.duration} phút</span>
            </div>
          </div>
        </div>
        {/* Main content */}
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6 lg:gap-8 mb-12">
          <div className="lg:col-span-2">
            <div className="bg-stone-900/50 rounded-2xl p-5 md:p-6 border border-stone-800 mb-6">
              <h3 className="text-white font-bold text-lg mb-3">Nội dung phim</h3>
              <p className="text-stone-300 leading-relaxed">{movie.description}</p>
            </div>
            {movie.totalEpisodes > 1 && (
              <div className="bg-stone-900/50 rounded-2xl p-5 md:p-6 border border-stone-800">
                <h2 className="text-white font-bold text-lg mb-4 flex items-center gap-2">
                  <List className="w-5 h-5 text-red-500" /> Danh sách tập
                </h2>
                <div className="grid grid-cols-4 sm:grid-cols-6 md:grid-cols-8 gap-2">
                  {Array.from({ length: movie.totalEpisodes }).map((_, i) => (
                    <Link
                      key={i}
                      to={`/watch/${movie.slug}?ep=${i + 1}`}
                      className={`text-center py-2.5 rounded-lg font-semibold transition-all text-sm ${currentEp === i + 1 ? 'bg-red-600 text-white shadow-lg shadow-red-900/50' : 'bg-stone-800 hover:bg-stone-700 text-stone-200'}`}
                    >
                      Tập {i + 1}
                    </Link>
                  ))}
                </div>
              </div>
            )}
          </div>
          <div className="bg-stone-900/50 rounded-2xl p-5 md:p-6 border border-stone-800 h-fit">
            <h3 className="text-white font-bold text-lg mb-4">Thông tin phim</h3>
            <dl className="space-y-3 text-sm">
              {movie.originalTitle && movie.originalTitle !== movie.title && (
                <div>
                  <dt className="text-stone-500 mb-0.5">Tên gốc</dt>
                  <dd className="text-white">{movie.originalTitle}</dd>
                </div>
              )}
              <div className="flex justify-between border-b border-stone-800 pb-2">
                <dt className="text-stone-500">Năm phát hành</dt>
                <dd className="text-white">{movie.year}</dd>
              </div>
              <div className="flex justify-between border-b border-stone-800 pb-2">
                <dt className="text-stone-500">Thời lượng</dt>
                <dd className="text-white">{movie.duration} phút</dd>
              </div>
              <div className="flex justify-between border-b border-stone-800 pb-2">
                <dt className="text-stone-500">Đánh giá</dt>
                <dd className="text-amber-400 font-semibold">★ {movie.rating?.toFixed(1)}/10</dd>
              </div>
              {movie.totalEpisodes > 1 && (
                <div className="flex justify-between border-b border-stone-800 pb-2">
                  <dt className="text-stone-500">Số tập</dt>
                  <dd className="text-white">{movie.totalEpisodes}</dd>
                </div>
              )}
              {movie.director && (
                <div>
                  <dt className="text-stone-500 mb-0.5">Đạo diễn</dt>
                  <dd className="text-white">{movie.director}</dd>
                </div>
              )}
              {movie.viewCount && (
                <div className="flex justify-between">
                  <dt className="text-stone-500">Lượt xem</dt>
                  <dd className="text-white">{movie.viewCount.toLocaleString('vi-VN')}</dd>
                </div>
              )}
            </dl>
          </div>
        </div>
        {/* Similar movies */}
        {similar.length > 0 && (
          <div>
            <h2 className="font-serif text-2xl md:text-3xl font-bold text-white mb-6">Phim cùng thể loại</h2>
            <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-6 gap-4 md:gap-6">
              {similar.map(m => <MovieCard key={m.id} movie={m} />)}
            </div>
          </div>
        )}
      </div>
    </div>
  );
}