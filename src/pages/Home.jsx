import { useState, useEffect, useRef } from 'react';
import { Link } from 'react-router-dom';
import { Play, Info, Star, ChevronLeft, ChevronRight, Calendar, Zap, Heart, Award, Eye, Coffee, Target, BookOpen, ArrowRight } from 'lucide-react';
import { Movie, Genre, Review } from '@/api/entities';
import MovieCard from '../components/MovieCard';
import TrailerModal from '../components/TrailerModal';
const iconMap = {
  Zap, Star, Heart, Award, Eye, Coffee, Target, BookOpen
};
export default function Home() {
  const [movies, setMovies] = useState([]);
  const [genres, setGenres] = useState([]);
  const [reviews, setReviews] = useState([]);
  const [loading, setLoading] = useState(true);
  const [activeTrailer, setActiveTrailer] = useState(null);
  const trendingRef = useRef(null);
  useEffect(() => {
    const fetchData = async () => {
      setLoading(true);
      try {
        const [moviesRes, genresRes, reviewsRes] = await Promise.all([
          Movie.paging({ page: 1, limit: 50, sort: '-rating' }),
          Genre.paging({ page: 1, limit: 20 }),
          Review.paging({ page: 1, limit: 10, sort: '-createdAt' })
        ]);
        setMovies(moviesRes.data.data || []);
        setGenres(genresRes.data.data || []);
        setReviews(reviewsRes.data.data || []);
      } catch (e) {
        console.error('Failed to fetch home data', e);
      } finally {
        setLoading(false);
      }
    };
    fetchData();
  }, []);
  const featuredMovie = movies.find(m => m.isFeatured) || movies[0];
  const trendingMovies = movies.filter(m => m.isTrending && !m.isComingSoon);
  const comingSoonMovies = movies.filter(m => m.isComingSoon);
  const allRegularMovies = movies.filter(m => !m.isComingSoon);
  const handlePlayTrailer = (movie) => {
    setActiveTrailer({ youtubeId: movie.trailerYoutubeId, title: movie.title });
  };
  const scrollTrending = (direction) => {
    if (trendingRef.current) {
      const scrollAmount = direction === 'left' ? -400 : 400;
      trendingRef.current.scrollBy({ left: scrollAmount, behavior: 'smooth' });
    }
  };
  if (loading) {
    return (
      <div className="min-h-screen bg-zinc-950 flex items-center justify-center">
        <div className="text-center">
          <div className="w-12 h-12 border-4 border-amber-500/30 border-t-amber-500 rounded-full animate-spin mx-auto mb-4"></div>
          <p className="text-zinc-400 font-display">Đang tải...</p>
        </div>
      </div>
    );
  }
  return (
    <>
      {/* HERO — Gradient Float with Featured Movie */}
      {featuredMovie && (
        <section className="relative w-full min-h-[90vh] md:min-h-screen overflow-hidden flex items-end md:items-center pt-20 md:pt-24 pb-12 md:pb-0">
          {/* Background poster with projector light effect */}
          <div className="absolute inset-0 z-0">
            <img
              src={featuredMovie.posterUrl}
              alt=""
              className="w-full h-full object-cover opacity-30 md:opacity-40"
            />
            <div className="absolute inset-0 bg-gradient-to-r from-zinc-950 via-zinc-950/80 to-zinc-950/30" />
            <div className="absolute inset-0 bg-gradient-to-t from-zinc-950 via-transparent to-zinc-950/60" />
            {/* Projector light cone */}
            <div className="absolute top-0 right-1/4 w-[800px] h-[800px] bg-amber-500/10 rounded-full blur-[120px] pointer-events-none" />
            <div className="absolute bottom-0 left-1/4 w-[600px] h-[600px] bg-amber-600/5 rounded-full blur-[100px] pointer-events-none" />
          </div>
          <div className="relative z-10 w-full">
            <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
              <div className="grid lg:grid-cols-12 gap-8 lg:gap-12 items-center">
                <div className="lg:col-span-7 text-center md:text-left animate-fadeInUp">
                  <div className="inline-flex items-center gap-2 px-3 py-1.5 bg-amber-500/10 border border-amber-500/30 rounded-full mb-5">
                    <span className="w-2 h-2 rounded-full bg-amber-500 animate-pulse"></span>
                    <span className="text-xs font-semibold text-amber-400 uppercase tracking-wider">Phim nổi bật hôm nay</span>
                  </div>
                  <h1 className="font-display text-4xl md:text-6xl lg:text-7xl font-black text-white leading-tight mb-4">
                    {featuredMovie.title}
                  </h1>
                  <div className="flex items-center justify-center md:justify-start gap-3 md:gap-4 text-zinc-300 text-sm md:text-base mb-5">
                    <span className="flex items-center gap-1.5">
                      <Star className="w-4 h-4 text-amber-400 fill-amber-400" />
                      <span className="font-bold text-white">{featuredMovie.rating}</span>
                    </span>
                    <span className="text-amber-500">•</span>
                    <span>{featuredMovie.year}</span>
                    <span className="text-amber-500">•</span>
                    <span>{featuredMovie.duration} phút</span>
                    <span className="text-amber-500">•</span>
                    <span className="px-2 py-0.5 bg-zinc-800/80 rounded border border-zinc-700 text-xs">{featuredMovie.genre}</span>
                  </div>
                  <p className="text-zinc-300 text-base md:text-lg leading-relaxed mb-8 max-w-2xl mx-auto md:mx-0 line-clamp-4">
                    {featuredMovie.description}
                  </p>
                  <div className="flex flex-col sm:flex-row items-center justify-center md:justify-start gap-3 md:gap-4">
                    <button
                      onClick={() => handlePlayTrailer(featuredMovie)}
                      className="group flex items-center gap-3 px-7 py-3.5 bg-amber-500 text-zinc-950 rounded-full font-bold text-base hover:bg-amber-400 hover:scale-105 transition-all shadow-xl shadow-amber-500/30 w-full sm:w-auto justify-center"
                    >
                      <Play className="w-5 h-5 fill-zinc-950" />
                      Xem trailer
                    </button>
                    <Link
                      to={`/movies/${featuredMovie.slug}`}
                      className="group flex items-center gap-3 px-7 py-3.5 bg-zinc-900/80 backdrop-blur-md border border-zinc-700 text-white rounded-full font-semibold text-base hover:bg-zinc-800 hover:border-amber-500/50 transition-all w-full sm:w-auto justify-center"
                    >
                      <Info className="w-5 h-5" />
                      Chi tiết
                    </Link>
                  </div>
                </div>
                {/* Featured poster card - desktop only */}
                <div className="hidden lg:block lg:col-span-5 relative">
                  <div className="relative animate-float">
                    <div className="absolute -inset-4 bg-amber-500/20 rounded-3xl blur-3xl"></div>
                    <div className="relative aspect-[2/3] max-w-sm mx-auto rounded-2xl overflow-hidden border border-amber-500/20 shadow-2xl shadow-amber-500/20">
                      <img
                        src={featuredMovie.posterUrl}
                        alt={featuredMovie.title}
                        className="w-full h-full object-cover"
                      />
                      <button
                        onClick={() => handlePlayTrailer(featuredMovie)}
                        className="absolute inset-0 flex items-center justify-center bg-black/20 hover:bg-black/50 transition-colors group"
                      >
                        <div className="w-20 h-20 rounded-full bg-amber-500/90 backdrop-blur-md flex items-center justify-center shadow-2xl group-hover:scale-110 transition-transform">
                          <Play className="w-10 h-10 text-zinc-950 ml-1 fill-zinc-950" />
                        </div>
                      </button>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </section>
      )}
      {/* TRENDING — Horizontal scroll carousel */}
      {trendingMovies.length > 0 && (
        <section className="relative w-full py-16 md:py-20 overflow-hidden">
          <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
            <div className="flex items-end justify-between mb-8">
              <div>
                <p className="text-amber-500 text-sm font-bold uppercase tracking-widest mb-2">🔥 Thịnh hành</p>
                <h2 className="font-display text-3xl md:text-4xl lg:text-5xl font-black text-white">
                  Đang được xem nhiều
                </h2>
              </div>
              <div className="hidden md:flex items-center gap-2">
                <button
                  onClick={() => scrollTrending('left')}
                  className="w-11 h-11 rounded-full bg-zinc-900 border border-zinc-800 text-zinc-400 hover:text-amber-500 hover:border-amber-500/40 transition-all flex items-center justify-center"
                  aria-label="Scroll left"
                >
                  <ChevronLeft className="w-5 h-5" />
                </button>
                <button
                  onClick={() => scrollTrending('right')}
                  className="w-11 h-11 rounded-full bg-zinc-900 border border-zinc-800 text-zinc-400 hover:text-amber-500 hover:border-amber-500/40 transition-all flex items-center justify-center"
                  aria-label="Scroll right"
                >
                  <ChevronRight className="w-5 h-5" />
                </button>
              </div>
            </div>
            <div
              ref={trendingRef}
              className="flex gap-4 md:gap-6 overflow-x-auto scrollbar-hide pb-4 -mx-4 px-4"
              style={ { scrollSnapType: 'x mandatory' } }
            >
              {trendingMovies.map((movie) => (
                <div
                  key={movie.id}
                  className="flex-shrink-0 w-44 md:w-56 lg:w-64"
                  style={ { scrollSnapAlign: 'start' } }
                >
                  <MovieCard movie={movie} onPlayTrailer={handlePlayTrailer} />
                </div>
              ))}
            </div>
          </div>
        </section>
      )}
      {/* GENRES — Bento grid */}
      {genres.length > 0 && (
        <section className="relative w-full py-16 md:py-24 bg-gradient-to-b from-zinc-950 via-zinc-900/30 to-zinc-950 overflow-hidden">
          <div className="absolute inset-0 projector-glow opacity-50 pointer-events-none" />
          <div className="relative max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
            <div className="text-center mb-12">
              <p className="text-amber-500 text-sm font-bold uppercase tracking-widest mb-2">Khám phá</p>
              <h2 className="font-display text-3xl md:text-4xl lg:text-5xl font-black text-white">
                Thể loại phim
              </h2>
              <p className="text-zinc-400 text-base md:text-lg mt-3 max-w-2xl mx-auto">
                Mỗi thể loại là một thế giới riêng. Bạn đang ở tâm trạng nào?
              </p>
            </div>
            <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-3 md:gap-4">
              {genres.map((genre) => {
                const Icon = iconMap[genre.iconName] || Star;
                return (
                  <Link
                    key={genre.id}
                    to={`/movies?genre=${genre.slug}`}
                    className="group relative bg-zinc-900/60 backdrop-blur-md border border-zinc-800 rounded-2xl p-5 md:p-6 hover:border-amber-500/40 hover:bg-zinc-900 transition-all duration-500 hover:-translate-y-1"
                  >
                    <div className="w-12 h-12 md:w-14 md:h-14 rounded-2xl bg-amber-500/10 border border-amber-500/20 flex items-center justify-center mb-4 group-hover:bg-amber-500 group-hover:border-amber-500 transition-all">
                      <Icon className="w-5 h-5 md:w-6 md:h-6 text-amber-500 group-hover:text-zinc-950 transition-colors" />
                    </div>
                    <h3 className="font-display font-bold text-white text-base md:text-lg mb-1">
                      {genre.name}
                    </h3>
                    <p className="text-xs md:text-sm text-zinc-500 line-clamp-2">
                      {genre.description}
                    </p>
                    <div className="flex items-center gap-1 text-xs text-amber-500/70 mt-3 font-medium">
                      <span>{genre.movieCount} phim</span>
                      <ArrowRight className="w-3 h-3 group-hover:translate-x-1 transition-transform" />
                    </div>
                  </Link>
                );
              })}
            </div>
          </div>
        </section>
      )}
      {/* MOVIE GRID — All movies */}
      <section className="relative w-full py-16 md:py-24 overflow-hidden">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex flex-col md:flex-row items-start md:items-end justify-between gap-4 mb-10">
            <div>
              <p className="text-amber-500 text-sm font-bold uppercase tracking-widest mb-2">Thư viện</p>
              <h2 className="font-display text-3xl md:text-4xl lg:text-5xl font-black text-white">
                Tất cả phim
              </h2>
            </div>
            <Link
              to="/movies"
              className="flex items-center gap-2 text-amber-500 hover:text-amber-400 font-semibold text-sm group"
            >
              Xem tất cả
              <ArrowRight className="w-4 h-4 group-hover:translate-x-1 transition-transform" />
            </Link>
          </div>
          <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4 md:gap-6">
            {allRegularMovies.slice(0, 8).map((movie) => (
              <MovieCard
                key={movie.id}
                movie={movie}
                onPlayTrailer={handlePlayTrailer}
              />
            ))}
          </div>
        </div>
      </section>
      {/* COMING SOON — Quieter section, full-bleed dark with horizontal cards */}
      {comingSoonMovies.length > 0 && (
        <section className="relative w-full py-16 md:py-24 bg-zinc-900/30 border-y border-zinc-800/50 overflow-hidden">
          <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
            <div className="text-center mb-12">
              <div className="inline-flex items-center gap-2 px-3 py-1.5 bg-amber-500/10 border border-amber-500/30 rounded-full mb-3">
                <Calendar className="w-3.5 h-3.5 text-amber-500" />
                <span className="text-xs font-semibold text-amber-400 uppercase tracking-wider">Sắp ra mắt</span>
              </div>
              <h2 className="font-display text-3xl md:text-4xl lg:text-5xl font-black text-white">
                Đừng bỏ lỡ
              </h2>
              <p className="text-zinc-400 text-base md:text-lg mt-3 max-w-2xl mx-auto">
                Những bộ phim hứa hẹn sẽ làm rung động màn ảnh trong năm 2026
              </p>
            </div>
            <div className="grid md:grid-cols-2 gap-6 md:gap-8">
              {comingSoonMovies.map((movie) => (
                <div
                  key={movie.id}
                  className="group relative flex gap-4 md:gap-6 bg-zinc-950/60 backdrop-blur-md border border-zinc-800 rounded-2xl p-4 md:p-5 hover:border-amber-500/40 transition-all duration-500"
                >
                  <Link to={`/movies/${movie.slug}`} className="flex-shrink-0 w-24 md:w-32">
                    <div className="aspect-[2/3] rounded-xl overflow-hidden bg-zinc-900">
                      <img
                        src={movie.posterUrl}
                        alt={movie.title}
                        className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-700"
                      />
                    </div>
                  </Link>
                  <div className="flex-1 min-w-0 flex flex-col justify-between py-1">
                    <div>
                      <div className="flex items-center gap-2 mb-2">
                        <Calendar className="w-3.5 h-3.5 text-amber-500" />
                        <span className="text-xs font-semibold text-amber-400">
                          {new Date(movie.releaseDate).toLocaleDateString('vi-VN', { day: '2-digit', month: '2-digit', year: 'numeric' })}
                        </span>
                      </div>
                      <Link to={`/movies/${movie.slug}`}>
                        <h3 className="font-display font-bold text-white text-lg md:text-xl mb-2 hover:text-amber-400 transition-colors line-clamp-2">
                          {movie.title}
                        </h3>
                      </Link>
                      <p className="text-zinc-400 text-xs md:text-sm line-clamp-2 md:line-clamp-3">
                        {movie.description}
                      </p>
                    </div>
                    <button
                      onClick={() => handlePlayTrailer(movie)}
                      className="flex items-center gap-2 text-amber-500 hover:text-amber-400 text-sm font-semibold mt-3 self-start"
                    >
                      <Play className="w-4 h-4 fill-current" />
                      Xem trailer
                    </button>
                  </div>
                </div>
              ))}
            </div>
          </div>
        </section>
      )}
      {/* REVIEWS — Image-led cards, lighter mood */}
      {reviews.length > 0 && (
        <section className="relative w-full py-16 md:py-24 overflow-hidden">
          <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
            <div className="text-center mb-12">
              <p className="text-amber-500 text-sm font-bold uppercase tracking-widest mb-2">Cộng đồng</p>
              <h2 className="font-display text-3xl md:text-4xl lg:text-5xl font-black text-white">
                Khán giả nói gì?
              </h2>
            </div>
            <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-5 md:gap-6">
              {reviews.slice(0, 6).map((review) => {
                const movie = movies.find(m => m.id === review.movieId);
                return (
                  <div
                    key={review.id}
                    className="bg-zinc-900/60 backdrop-blur-md border border-zinc-800 rounded-2xl p-6 hover:border-amber-500/30 transition-all duration-500"
                  >
                    <div className="flex items-center gap-1 mb-4">
                      {[...Array(5)].map((_, i) => (
                        <Star
                          key={i}
                          className={`w-4 h-4 ${i < review.rating ? 'text-amber-400 fill-amber-400' : 'text-zinc-700'}`}
                        />
                      ))}
                    </div>
                    <p className="text-zinc-300 text-sm md:text-base leading-relaxed mb-5 line-clamp-4">
                      "{review.comment}"
                    </p>
                    <div className="flex items-center gap-3 pt-4 border-t border-zinc-800">
                      <div className="w-10 h-10 rounded-full bg-zinc-800 overflow-hidden flex-shrink-0">
                        {review.avatarUrl && (
                          <img src={review.avatarUrl} alt={review.userName} className="w-full h-full object-cover" />
                        )}
                      </div>
                      <div className="flex-1 min-w-0">
                        <p className="font-semibold text-white text-sm truncate">{review.userName}</p>
                        {movie && (
                          <p className="text-xs text-amber-500/70 truncate">về {movie.title}</p>
                        )}
                      </div>
                    </div>
                  </div>
                );
              })}
            </div>
          </div>
        </section>
      )}
      {/* CTA — DOMINANT closing section */}
      <section className="relative w-full py-20 md:py-32 overflow-hidden">
        <div className="absolute inset-0">
          <div className="absolute inset-0 bg-gradient-to-br from-amber-500/10 via-zinc-950 to-zinc-950" />
          <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[800px] h-[800px] bg-amber-500/15 rounded-full blur-[150px] pointer-events-none" />
        </div>
        <div className="relative max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
          <h2 className="font-display text-4xl md:text-5xl lg:text-6xl font-black text-white mb-6 leading-tight">
            Bước vào ánh đèn chiếu.<br />
            <span className="text-amber-500">Khám phá điện ảnh.</span>
          </h2>
          <p className="text-zinc-300 text-lg md:text-xl mb-10 max-w-2xl mx-auto leading-relaxed">
            Hàng trăm trailer phim đỉnh cao đang chờ bạn. Tìm bộ phim tiếp theo cho buổi tối của mình.
          </p>
          <Link
            to="/movies"
            className="inline-flex items-center gap-3 px-8 py-4 bg-amber-500 text-zinc-950 rounded-full font-bold text-base md:text-lg hover:bg-amber-400 hover:scale-105 transition-all shadow-2xl shadow-amber-500/30"
          >
            <Play className="w-5 h-5 fill-zinc-950" />
            Khám phá thư viện phim
          </Link>
        </div>
      </section>
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