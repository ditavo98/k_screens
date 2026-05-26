import { useState, useEffect } from 'react';
import { useParams, Link } from 'react-router-dom';
import { Play, Star, Clock, Calendar, ArrowLeft, User, Award, Share } from 'lucide-react';
import { Movie, Review } from '@/api/entities';
import MovieCard from '../components/MovieCard';
import TrailerModal from '../components/TrailerModal';
export default function MovieDetail() {
  const { slug } = useParams();
  const [movie, setMovie] = useState(null);
  const [relatedMovies, setRelatedMovies] = useState([]);
  const [reviews, setReviews] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [showTrailer, setShowTrailer] = useState(false);
  const [activeTrailer, setActiveTrailer] = useState(null);
  useEffect(() => {
    const fetchData = async () => {
      setLoading(true);
      setError(null);
      try {
        const res = await Movie.get(slug);
        const m = res.data;
        setMovie(m);
        // Fetch related (same genre) and reviews
        const [relatedRes, reviewsRes] = await Promise.all([
          Movie.paging({
            page: 1,
            limit: 6,
            filter: { genreSlug: m.genreSlug },
            sort: '-rating'
          }),
          Review.paging({
            page: 1,
            limit: 10,
            filter: { movieId: m.id },
            sort: '-createdAt'
          })
        ]);
        setRelatedMovies((relatedRes.data.data || []).filter(rm => rm.id !== m.id));
        setReviews(reviewsRes.data.data || []);
      } catch (e) {
        console.error('Failed to fetch movie', e);
        setError('Không tìm thấy phim');
      } finally {
        setLoading(false);
      }
    };
    if (slug) fetchData();
    window.scrollTo(0, 0);
  }, [slug]);
  if (loading) {
    return (
      <div className="min-h-screen bg-zinc-950 flex items-center justify-center">
        <div className="w-12 h-12 border-4 border-amber-500/30 border-t-amber-500 rounded-full animate-spin"></div>
      </div>
    );
  }
  if (error || !movie) {
    return (
      <div className="min-h-screen bg-zinc-950 flex items-center justify-center pt-20">
        <div className="text-center px-4">
          <h2 className="font-display text-2xl md:text-3xl font-bold text-white mb-3">Không tìm thấy phim</h2>
          <p className="text-zinc-400 mb-6">Bộ phim bạn tìm có thể đã bị xóa hoặc không tồn tại.</p>
          <Link
            to="/movies"
            className="inline-flex items-center gap-2 px-6 py-3 bg-amber-500 text-zinc-950 rounded-full font-semibold hover:bg-amber-400 transition-colors"
          >
            <ArrowLeft className="w-4 h-4" />
            Quay lại thư viện
          </Link>
        </div>
      </div>
    );
  }
  return (
    <>
      {/* HERO with backdrop poster */}
      <section className="relative w-full pt-24 md:pt-28 overflow-hidden">
        {/* Background blurred poster */}
        <div className="absolute inset-0 z-0">
          <img
            src={movie.posterUrl}
            alt=""
            className="w-full h-full object-cover opacity-25 blur-2xl scale-110"
          />
          <div className="absolute inset-0 bg-gradient-to-b from-zinc-950/80 via-zinc-950/90 to-zinc-950" />
          <div className="absolute top-0 right-0 w-[600px] h-[600px] bg-amber-500/10 rounded-full blur-[120px] pointer-events-none" />
        </div>
        <div className="relative z-10 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8 md:py-12">
          <Link
            to="/movies"
            className="inline-flex items-center gap-2 text-zinc-400 hover:text-amber-500 text-sm font-medium mb-6 transition-colors"
          >
            <ArrowLeft className="w-4 h-4" />
            Quay lại thư viện
          </Link>
          <div className="grid lg:grid-cols-12 gap-8 lg:gap-12 items-start">
            {/* Poster */}
            <div className="lg:col-span-4">
              <div className="relative max-w-sm mx-auto lg:mx-0">
                <div className="absolute -inset-2 bg-amber-500/20 rounded-2xl blur-2xl"></div>
                <div className="relative aspect-[2/3] rounded-2xl overflow-hidden border border-amber-500/20 shadow-2xl shadow-amber-500/20">
                  <img
                    src={movie.posterUrl}
                    alt={movie.title}
                    className="w-full h-full object-cover"
                  />
                  <button
                    onClick={() => setShowTrailer(true)}
                    className="absolute inset-0 flex items-center justify-center bg-black/30 hover:bg-black/50 transition-colors group"
                  >
                    <div className="w-20 h-20 rounded-full bg-amber-500/90 flex items-center justify-center shadow-2xl group-hover:scale-110 transition-transform">
                      <Play className="w-9 h-9 text-zinc-950 ml-1 fill-zinc-950" />
                    </div>
                  </button>
                </div>
              </div>
            </div>
            {/* Info */}
            <div className="lg:col-span-8">
              <div className="flex flex-wrap items-center gap-2 mb-4">
                <span className="px-3 py-1 bg-amber-500/10 border border-amber-500/30 rounded-full text-xs font-semibold text-amber-400 uppercase tracking-wider">
                  {movie.genre}
                </span>
                {movie.isComingSoon && (
                  <span className="px-3 py-1 bg-zinc-900 border border-zinc-700 rounded-full text-xs font-semibold text-white">
                    📅 Sắp ra mắt
                  </span>
                )}
                {movie.isTrending && !movie.isComingSoon && (
                  <span className="px-3 py-1 bg-red-600/20 border border-red-600/40 rounded-full text-xs font-semibold text-red-400">
                    🔥 Thịnh hành
                  </span>
                )}
              </div>
              <h1 className="font-display text-4xl md:text-5xl lg:text-6xl font-black text-white leading-tight mb-5">
                {movie.title}
              </h1>
              {/* Stats row */}
              <div className="flex flex-wrap items-center gap-4 md:gap-6 text-zinc-300 mb-6">
                {movie.rating && (
                  <div className="flex items-center gap-2">
                    <Star className="w-5 h-5 text-amber-400 fill-amber-400" />
                    <span className="font-bold text-white text-lg">{movie.rating}</span>
                    <span className="text-zinc-500 text-sm">/10</span>
                  </div>
                )}
                {movie.year && (
                  <div className="flex items-center gap-2 text-sm">
                    <Calendar className="w-4 h-4 text-amber-500/70" />
                    <span>{movie.year}</span>
                  </div>
                )}
                {movie.duration && (
                  <div className="flex items-center gap-2 text-sm">
                    <Clock className="w-4 h-4 text-amber-500/70" />
                    <span>{movie.duration} phút</span>
                  </div>
                )}
              </div>
              {/* CTAs */}
              <div className="flex flex-col sm:flex-row items-stretch sm:items-center gap-3 mb-8">
                <button
                  onClick={() => setShowTrailer(true)}
                  className="flex items-center justify-center gap-3 px-7 py-3.5 bg-amber-500 text-zinc-950 rounded-full font-bold hover:bg-amber-400 hover:scale-105 transition-all shadow-xl shadow-amber-500/30"
                >
                  <Play className="w-5 h-5 fill-zinc-950" />
                  Xem trailer
                </button>
                <button
                  onClick={() => {
                    if (navigator.share) {
                      navigator.share({ title: movie.title, url: window.location.href }).catch(() => {});
                    } else {
                      navigator.clipboard.writeText(window.location.href);
                    }
                  }}
                  className="flex items-center justify-center gap-2 px-6 py-3.5 bg-zinc-900/80 backdrop-blur-md border border-zinc-700 text-white rounded-full font-semibold hover:border-amber-500/50 transition-colors"
                >
                  <Share className="w-4 h-4" />
                  Chia sẻ
                </button>
              </div>
              {/* Description */}
              <div className="mb-8">
                <h3 className="font-display text-lg font-bold text-amber-500 mb-3">Nội dung</h3>
                <p className="text-zinc-300 text-base md:text-lg leading-relaxed">
                  {movie.description}
                </p>
              </div>
              {/* Details grid */}
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                {movie.director && (
                  <div className="bg-zinc-900/60 backdrop-blur-md border border-zinc-800 rounded-xl p-4">
                    <div className="flex items-center gap-2 text-xs text-amber-500 font-semibold uppercase tracking-wider mb-2">
                      <Award className="w-3.5 h-3.5" />
                      Đạo diễn
                    </div>
                    <p className="text-white font-medium">{movie.director}</p>
                  </div>
                )}
                {movie.cast && movie.cast.length > 0 && (
                  <div className="bg-zinc-900/60 backdrop-blur-md border border-zinc-800 rounded-xl p-4">
                    <div className="flex items-center gap-2 text-xs text-amber-500 font-semibold uppercase tracking-wider mb-2">
                      <User className="w-3.5 h-3.5" />
                      Diễn viên
                    </div>
                    <p className="text-white text-sm leading-relaxed">{movie.cast.join(', ')}</p>
                  </div>
                )}
                {movie.releaseDate && (
                  <div className="bg-zinc-900/60 backdrop-blur-md border border-zinc-800 rounded-xl p-4">
                    <div className="flex items-center gap-2 text-xs text-amber-500 font-semibold uppercase tracking-wider mb-2">
                      <Calendar className="w-3.5 h-3.5" />
                      Ngày phát hành
                    </div>
                    <p className="text-white font-medium">
                      {new Date(movie.releaseDate).toLocaleDateString('vi-VN', { day: '2-digit', month: 'long', year: 'numeric' })}
                    </p>
                  </div>
                )}
                {movie.duration && (
                  <div className="bg-zinc-900/60 backdrop-blur-md border border-zinc-800 rounded-xl p-4">
                    <div className="flex items-center gap-2 text-xs text-amber-500 font-semibold uppercase tracking-wider mb-2">
                      <Clock className="w-3.5 h-3.5" />
                      Thời lượng
                    </div>
                    <p className="text-white font-medium">{movie.duration} phút</p>
                  </div>
                )}
              </div>
            </div>
          </div>
        </div>
      </section>
      {/* Embedded trailer section */}
      {movie.trailerYoutubeId && (
        <section className="relative w-full py-12 md:py-16 bg-zinc-900/30 border-y border-zinc-800/50">
          <div className="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8">
            <div className="text-center mb-8">
              <p className="text-amber-500 text-sm font-bold uppercase tracking-widest mb-2">▶ Trailer chính thức</p>
              <h2 className="font-display text-2xl md:text-3xl lg:text-4xl font-black text-white">
                Xem trước
              </h2>
            </div>
            <div className="relative aspect-video w-full rounded-2xl overflow-hidden border border-zinc-800 shadow-2xl shadow-amber-500/10 bg-zinc-900">
              <iframe
                src={`https://www.youtube.com/embed/${movie.trailerYoutubeId}?rel=0`}
                title={`${movie.title} Trailer`}
                className="absolute inset-0 w-full h-full"
                allow="accelerometer; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
                allowFullScreen
              />
            </div>
          </div>
        </section>
      )}
      {/* Reviews */}
      {reviews.length > 0 && (
        <section className="relative w-full py-16 md:py-20">
          <div className="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8">
            <h2 className="font-display text-2xl md:text-3xl lg:text-4xl font-black text-white mb-8">
              Đánh giá từ khán giả
            </h2>
            <div className="space-y-4">
              {reviews.map(review => (
                <div
                  key={review.id}
                  className="bg-zinc-900/60 backdrop-blur-md border border-zinc-800 rounded-2xl p-5 md:p-6"
                >
                  <div className="flex items-start gap-4">
                    <div className="w-12 h-12 rounded-full bg-zinc-800 overflow-hidden flex-shrink-0">
                      {review.avatarUrl && (
                        <img src={review.avatarUrl} alt={review.userName} className="w-full h-full object-cover" />
                      )}
                    </div>
                    <div className="flex-1 min-w-0">
                      <div className="flex flex-wrap items-center justify-between gap-2 mb-2">
                        <p className="font-semibold text-white">{review.userName}</p>
                        <div className="flex items-center gap-0.5">
                          {[...Array(5)].map((_, i) => (
                            <Star
                              key={i}
                              className={`w-3.5 h-3.5 ${i < review.rating ? 'text-amber-400 fill-amber-400' : 'text-zinc-700'}`}
                            />
                          ))}
                        </div>
                      </div>
                      <p className="text-zinc-300 text-sm md:text-base leading-relaxed">
                        "{review.comment}"
                      </p>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          </div>
        </section>
      )}
      {/* Related */}
      {relatedMovies.length > 0 && (
        <section className="relative w-full py-16 md:py-20 border-t border-zinc-900">
          <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
            <div className="mb-8">
              <p className="text-amber-500 text-sm font-bold uppercase tracking-widest mb-2">Xem thêm</p>
              <h2 className="font-display text-2xl md:text-3xl lg:text-4xl font-black text-white">
                Phim cùng thể loại
              </h2>
            </div>
            <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-5 gap-4 md:gap-6">
              {relatedMovies.slice(0, 5).map(rm => (
                <MovieCard
                  key={rm.id}
                  movie={rm}
                  onPlayTrailer={(m) => setActiveTrailer({ youtubeId: m.trailerYoutubeId, title: m.title })}
                />
              ))}
            </div>
          </div>
        </section>
      )}
      {showTrailer && (
        <TrailerModal
          youtubeId={movie.trailerYoutubeId}
          title={movie.title}
          onClose={() => setShowTrailer(false)}
        />
      )}
      {activeTrailer && (
        <TrailerModal
          youtubeId={activeTrailer.youtubeId}
          title={activeTrailer.title}
          onClose={() => setActiveTrailer(null)}
        />
      )}
    </>
  );
}