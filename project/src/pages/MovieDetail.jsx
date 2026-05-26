import React, { useState, useEffect } from 'react';
import { useParams, Link } from 'react-router-dom';
import { Movie, Genre, Actor, Review } from '@/api/entities';
import { Play, Star, Heart, Share2, Clock, Calendar, Film, ChevronLeft, Eye } from 'lucide-react';
import MovieCard from '@/components/MovieCard';
import { motion } from 'framer-motion';
export default function MovieDetail() {
  const { slug } = useParams();
  const [movie, setMovie] = useState(null);
  const [genre, setGenre] = useState(null);
  const [actors, setActors] = useState([]);
  const [reviews, setReviews] = useState([]);
  const [similar, setSimilar] = useState([]);
  const [loading, setLoading] = useState(true);
  const [isFavorite, setIsFavorite] = useState(false);
  const [reviewForm, setReviewForm] = useState({ rating: 5, comment: '', userName: '' });
  const [submitting, setSubmitting] = useState(false);
  const [notification, setNotification] = useState(null);
  useEffect(() => {
    const load = async () => {
      setLoading(true);
      try {
        const res = await Movie.get(slug);
        const m = res.data;
        setMovie(m);
        const favs = JSON.parse(localStorage.getItem('vdrama_favorites') || '[]');
        setIsFavorite(favs.includes(m.id));
        const [gRes, aRes, rRes, sRes] = await Promise.all([
          Genre.paging({ page: 1, limit: 50 }),
          Actor.paging({ page: 1, limit: 50 }),
          Review.paging({ page: 1, limit: 20, filter: { movieId: m.id }, sort: '-createdAt' }),
          Movie.paging({ page: 1, limit: 10, filter: { genreId: m.genreId } }),
        ]);
        const allGenres = gRes.data?.data || [];
        setGenre(allGenres.find(g => g.id === m.genreId));
        const allActors = aRes.data?.data || [];
        setActors(allActors.filter(a => (m.actorIds || []).includes(a.id)));
        setReviews(rRes.data?.data || []);
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
  const toggleFavorite = () => {
    if (!movie) return;
    const favs = JSON.parse(localStorage.getItem('vdrama_favorites') || '[]');
    const updated = isFavorite ? favs.filter(id => id !== movie.id) : [...favs, movie.id];
    localStorage.setItem('vdrama_favorites', JSON.stringify(updated));
    setIsFavorite(!isFavorite);
    setNotification({ type: 'success', message: !isFavorite ? 'Đã thêm vào yêu thích!' : 'Đã xóa khỏi yêu thích' });
    setTimeout(() => setNotification(null), 2500);
  };
  const handleShare = async () => {
    try {
      await navigator.clipboard?.writeText(window.location.href);
      setNotification({ type: 'success', message: 'Đã sao chép liên kết!' });
      setTimeout(() => setNotification(null), 2500);
    } catch (e) {
      console.error(e);
    }
  };
  const submitReview = async () => {
    if (!reviewForm.userName.trim() || !reviewForm.comment.trim() || submitting) return;
    setSubmitting(true);
    try {
      await Review.create({
        movieId: movie.id,
        userName: reviewForm.userName.trim(),
        rating: reviewForm.rating,
        comment: reviewForm.comment.trim(),
        userAvatar: '',
        createdAt: new Date().toISOString(),
      });
      const r = await Review.paging({ page: 1, limit: 20, filter: { movieId: movie.id }, sort: '-createdAt' });
      setReviews(r.data?.data || []);
      setReviewForm({ rating: 5, comment: '', userName: '' });
      setNotification({ type: 'success', message: 'Cảm ơn bạn đã đánh giá!' });
      setTimeout(() => setNotification(null), 2500);
    } catch (e) {
      console.error(e);
      setNotification({ type: 'error', message: 'Có lỗi xảy ra, vui lòng thử lại' });
      setTimeout(() => setNotification(null), 2500);
    } finally {
      setSubmitting(false);
    }
  };
  if (loading) return (
    <div className="min-h-screen bg-stone-950 pt-24 flex items-center justify-center">
      <div className="w-12 h-12 border-4 border-red-600 border-t-transparent rounded-full animate-spin" />
    </div>
  );
  if (!movie) return (
    <div className="min-h-screen bg-stone-950 pt-24 flex flex-col items-center justify-center text-center px-4">
      <Film className="w-16 h-16 text-stone-700 mb-4" />
      <h1 className="text-3xl font-bold text-white mb-2">Không tìm thấy phim</h1>
      <Link to="/Movies" className="text-red-500 hover:text-red-400 mt-4">← Quay lại danh sách phim</Link>
    </div>
  );
  return (
    <div className="min-h-screen bg-stone-950 relative">
      {notification && (
        <div className={`fixed top-24 right-4 z-50 px-5 py-3 rounded-lg font-medium shadow-2xl ${notification.type === 'success' ? 'bg-red-600 text-white' : 'bg-amber-600 text-white'} animate-in slide-in-from-top`}>
          {notification.message}
        </div>
      )}
      {/* Backdrop hero */}
      <section className="relative w-full h-[60vh] md:h-[80vh] overflow-hidden">
        <img src={movie.backdropUrl} alt={movie.title} className="w-full h-full object-cover" />
        <div className="absolute inset-0 bg-gradient-to-t from-stone-950 via-stone-950/70 to-stone-950/30" />
        <div className="absolute inset-0 bg-gradient-to-r from-stone-950/80 to-transparent" />
      </section>
      {/* Movie info card */}
      <section className="relative -mt-48 md:-mt-64 z-10">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex flex-col md:flex-row gap-6 md:gap-10">
            <motion.div
              initial={{ opacity: 0, y: 30 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.6 }}
              className="flex-shrink-0 mx-auto md:mx-0"
            >
              <div className="w-56 md:w-72 aspect-[2/3] rounded-2xl overflow-hidden shadow-2xl shadow-red-900/40 ring-1 ring-red-900/30">
                <img src={movie.posterUrl} alt={movie.title} className="w-full h-full object-cover" />
              </div>
            </motion.div>
            <motion.div
              initial={{ opacity: 0, y: 30 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.6, delay: 0.2 }}
              className="flex-1 text-center md:text-left"
            >
              {genre && (
                <Link to={`/genres/${genre.slug}`} className="inline-block bg-red-600/90 hover:bg-red-700 text-white text-xs font-bold px-3 py-1 rounded uppercase tracking-wider mb-3 transition-colors">
                  {genre.name}
                </Link>
              )}
              <h1 className="font-serif text-4xl md:text-5xl lg:text-6xl font-bold text-white mb-3 drop-shadow-2xl leading-tight">{movie.title}</h1>
              {movie.originalTitle && movie.originalTitle !== movie.title && (
                <p className="text-stone-400 italic mb-4 text-lg">{movie.originalTitle}</p>
              )}
              <div className="flex flex-wrap items-center gap-3 md:gap-4 mb-6 justify-center md:justify-start">
                <div className="flex items-center gap-1 bg-amber-500/20 text-amber-400 px-3 py-1 rounded">
                  <Star className="w-4 h-4 fill-amber-400" />
                  <span className="font-bold">{movie.rating?.toFixed(1)}</span>
                </div>
                <span className="flex items-center gap-1 text-stone-300"><Calendar className="w-4 h-4" /> {movie.year}</span>
                <span className="flex items-center gap-1 text-stone-300"><Clock className="w-4 h-4" /> {movie.duration} phút</span>
                {movie.totalEpisodes > 1 && <span className="flex items-center gap-1 text-stone-300"><Film className="w-4 h-4" /> {movie.totalEpisodes} tập</span>}
                {movie.viewCount && <span className="flex items-center gap-1 text-stone-300"><Eye className="w-4 h-4" /> {(movie.viewCount / 1000).toFixed(0)}K lượt xem</span>}
              </div>
              <p className="text-stone-200 text-base md:text-lg leading-relaxed mb-8 max-w-3xl">{movie.description}</p>
              {movie.director && (
                <p className="text-stone-300 text-sm mb-6">
                  <span className="text-amber-400 font-semibold">Đạo diễn:</span> {movie.director}
                </p>
              )}
              <div className="flex flex-wrap gap-3 justify-center md:justify-start">
                <Link to={`/watch/${movie.slug}`} className="bg-red-600 hover:bg-red-700 text-white px-8 py-4 rounded-lg font-semibold flex items-center gap-2 transition-all shadow-lg shadow-red-900/50 hover:scale-105 active:scale-95">
                  <Play className="w-5 h-5 fill-white" />
                  Xem phim
                </Link>
                <button onClick={toggleFavorite} className={`px-6 py-4 rounded-lg font-semibold flex items-center gap-2 border transition-all ${isFavorite ? 'bg-red-600/20 text-red-400 border-red-600 hover:bg-red-600/30' : 'bg-white/10 text-white border-white/20 hover:bg-white/20'}`}>
                  <Heart className={`w-5 h-5 ${isFavorite ? 'fill-red-500 text-red-500' : ''}`} />
                  {isFavorite ? 'Đã thích' : 'Yêu thích'}
                </button>
                <button onClick={handleShare} className="px-6 py-4 rounded-lg font-semibold flex items-center gap-2 bg-white/10 text-white border border-white/20 hover:bg-white/20 transition-all">
                  <Share2 className="w-5 h-5" />
                  Chia sẻ
                </button>
              </div>
            </motion.div>
          </div>
        </div>
      </section>
      {/* Cast */}
      {actors.length > 0 && (
        <section className="py-12 md:py-16">
          <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
            <div className="flex items-center gap-3 mb-6">
              <div className="w-1 h-7 md:h-9 rounded-full bg-red-600" />
              <h2 className="font-serif text-2xl md:text-3xl font-bold text-white">Dàn diễn viên</h2>
            </div>
            <div className="grid grid-cols-3 sm:grid-cols-4 md:grid-cols-6 gap-4 md:gap-6">
              {actors.map(a => (
                <Link key={a.id} to={`/actors/${a.slug}`} className="group text-center">
                  <div className="w-20 h-20 md:w-24 md:h-24 mx-auto mb-2 rounded-full overflow-hidden ring-2 ring-red-900/40 group-hover:ring-red-600 transition-all duration-500 group-hover:scale-105">
                    <div className="w-full h-full bg-gradient-to-br from-red-900 via-red-800 to-amber-900 flex items-center justify-center">
                      <span className="text-2xl md:text-3xl font-bold text-white font-serif">{a.name.split(' ').pop().charAt(0)}</span>
                    </div>
                  </div>
                  <p className="text-white text-sm font-medium line-clamp-1">{a.name}</p>
                </Link>
              ))}
            </div>
          </div>
        </section>
      )}
      {/* Episodes */}
      {movie.totalEpisodes > 1 && (
        <section className="py-12 bg-stone-900/40">
          <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
            <div className="flex items-center gap-3 mb-6">
              <div className="w-1 h-7 md:h-9 rounded-full bg-amber-500" />
              <h2 className="font-serif text-2xl md:text-3xl font-bold text-white">Danh sách tập</h2>
            </div>
            <div className="grid grid-cols-4 sm:grid-cols-6 md:grid-cols-8 lg:grid-cols-10 gap-2">
              {Array.from({ length: movie.totalEpisodes }).map((_, i) => (
                <Link key={i} to={`/watch/${movie.slug}?ep=${i + 1}`} className="bg-stone-800 hover:bg-red-600 text-white text-center py-3 rounded-lg font-semibold transition-colors text-sm">
                  Tập {i + 1}
                </Link>
              ))}
            </div>
          </div>
        </section>
      )}
      {/* Reviews */}
      <section className="py-12 md:py-16">
        <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex items-center gap-3 mb-6">
            <div className="w-1 h-7 md:h-9 rounded-full bg-red-600" />
            <h2 className="font-serif text-2xl md:text-3xl font-bold text-white">Bình luận & Đánh giá ({reviews.length})</h2>
          </div>
          <div className="bg-stone-900/70 backdrop-blur-sm rounded-2xl p-5 md:p-6 mb-8 border border-stone-800" role="form" aria-label="Đánh giá phim">
            <input
              type="text"
              value={reviewForm.userName}
              onChange={(e) => setReviewForm({ ...reviewForm, userName: e.target.value })}
              placeholder="Tên của bạn"
              className="w-full px-4 py-3 bg-stone-800 text-white rounded-lg border border-stone-700 focus:border-red-600 focus:ring-2 focus:ring-red-600/30 outline-none mb-3 placeholder:text-stone-500"
            />
            <div className="flex items-center gap-2 mb-3">
              <span className="text-stone-400 text-sm mr-2">Đánh giá:</span>
              {[1, 2, 3, 4, 5].map(n => (
                <button key={n} onClick={() => setReviewForm({ ...reviewForm, rating: n })} aria-label={`Đánh giá ${n} sao`}>
                  <Star className={`w-6 h-6 transition-colors ${n <= reviewForm.rating ? 'fill-amber-400 text-amber-400' : 'text-stone-600 hover:text-stone-400'}`} />
                </button>
              ))}
              <span className="text-amber-400 font-semibold ml-2">{reviewForm.rating}/5</span>
            </div>
            <textarea
              value={reviewForm.comment}
              onChange={(e) => setReviewForm({ ...reviewForm, comment: e.target.value })}
              placeholder="Cảm nhận của bạn về bộ phim..."
              rows={3}
              className="w-full px-4 py-3 bg-stone-800 text-white rounded-lg border border-stone-700 focus:border-red-600 focus:ring-2 focus:ring-red-600/30 outline-none mb-3 resize-none placeholder:text-stone-500"
            />
            <button
              onClick={submitReview}
              disabled={submitting || !reviewForm.userName.trim() || !reviewForm.comment.trim()}
              className="bg-red-600 hover:bg-red-700 disabled:bg-stone-700 disabled:cursor-not-allowed text-white px-6 py-3 rounded-lg font-semibold transition-colors"
            >
              {submitting ? 'Đang gửi...' : 'Gửi bình luận'}
            </button>
          </div>
          <div className="space-y-4">
            {reviews.length === 0 ? (
              <p className="text-stone-400 text-center py-12 italic">Chưa có bình luận nào. Hãy là người đầu tiên!</p>
            ) : reviews.map((r, i) => (
              <motion.div
                key={r.id}
                initial={{ opacity: 0, y: 10 }}
                whileInView={{ opacity: 1, y: 0 }}
                viewport={{ once: true }}
                transition={{ delay: i * 0.05 }}
                className="bg-stone-900/50 rounded-xl p-5 border border-stone-800 hover:border-stone-700 transition-colors"
              >
                <div className="flex items-start gap-3">
                  <div className="w-11 h-11 rounded-full bg-gradient-to-br from-red-900 to-amber-900 flex items-center justify-center font-bold text-white flex-shrink-0">
                    {r.userName.charAt(0).toUpperCase()}
                  </div>
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center justify-between flex-wrap gap-2 mb-1">
                      <p className="text-white font-semibold">{r.userName}</p>
                      <div className="flex items-center gap-0.5">
                        {Array.from({ length: 5 }).map((_, j) => (
                          <Star key={j} className={`w-4 h-4 ${j < r.rating ? 'fill-amber-400 text-amber-400' : 'text-stone-600'}`} />
                        ))}
                      </div>
                    </div>
                    <p className="text-stone-500 text-xs mb-2">{new Date(r.createdAt).toLocaleDateString('vi-VN', { day: 'numeric', month: 'long', year: 'numeric' })}</p>
                    <p className="text-stone-200 leading-relaxed">{r.comment}</p>
                  </div>
                </div>
              </motion.div>
            ))}
          </div>
        </div>
      </section>
      {/* Similar */}
      {similar.length > 0 && (
        <section className="py-12 md:py-16 bg-stone-900/40">
          <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
            <div className="flex items-center gap-3 mb-6">
              <div className="w-1 h-7 md:h-9 rounded-full bg-amber-500" />
              <h2 className="font-serif text-2xl md:text-3xl font-bold text-white">Phim cùng thể loại</h2>
            </div>
            <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-6 gap-4 md:gap-6">
              {similar.map(m => <MovieCard key={m.id} movie={m} />)}
            </div>
          </div>
        </section>
      )}
    </div>
  );
}