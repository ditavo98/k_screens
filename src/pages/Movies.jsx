import { useState, useEffect, useRef } from 'react';
import { useSearchParams } from 'react-router-dom';
import { Search, Filter, X } from 'lucide-react';
import { Movie, Genre } from '@/api/entities';
import MovieCard from '../components/MovieCard';
import TrailerModal from '../components/TrailerModal';
export default function Movies() {
  const [searchParams, setSearchParams] = useSearchParams();
  const [movies, setMovies] = useState([]);
  const [genres, setGenres] = useState([]);
  const [page, setPage] = useState(1);
  const [hasMore, setHasMore] = useState(true);
  const [loading, setLoading] = useState(false);
  const [initialLoaded, setInitialLoaded] = useState(false);
  const [searchInput, setSearchInput] = useState('');
  const [search, setSearch] = useState('');
  const [selectedGenre, setSelectedGenre] = useState(searchParams.get('genre') || '');
  const [filterMode, setFilterMode] = useState(searchParams.get('filter') || '');
  const [activeTrailer, setActiveTrailer] = useState(null);
  const isComposingRef = useRef(false);
  const loaderRef = useRef(null);
  // Load genres once
  useEffect(() => {
    Genre.paging({ page: 1, limit: 50 }).then(res => {
      setGenres(res.data.data || []);
    }).catch(e => console.error(e));
  }, []);
  // Debounced search input → commit search
  useEffect(() => {
    if (isComposingRef.current) return;
    const timer = setTimeout(() => setSearch(searchInput), 300);
    return () => clearTimeout(timer);
  }, [searchInput]);
  const fetchData = async (pageNum, reset = false) => {
    if (loading) return;
    setLoading(true);
    try {
      const filter = { search };
      if (selectedGenre) filter.genreSlug = selectedGenre;
      if (filterMode === 'coming-soon') filter.isComingSoon = true;
      if (filterMode === 'trending') filter.isTrending = true;
      const res = await Movie.paging({
        page: pageNum,
        limit: 12,
        filter,
        sort: '-rating'
      });
      setMovies(prev => reset ? (res.data.data || []) : [...prev, ...(res.data.data || [])]);
      setHasMore(pageNum < (res.data.totalPages || 1));
      setInitialLoaded(true);
    } catch (e) {
      console.error('Failed to fetch movies', e);
    } finally {
      setLoading(false);
    }
  };
  // Reset when filters/search change
  useEffect(() => {
    setMovies([]);
    setHasMore(true);
    if (page === 1) {
      fetchData(1, true);
    } else {
      setPage(1);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [search, selectedGenre, filterMode]);
  // Page change → fetch
  useEffect(() => {
    if (page > 1) fetchData(page, false);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [page]);
  // Infinite scroll
  useEffect(() => {
    if (!loaderRef.current || !hasMore || loading) return;
    const observer = new IntersectionObserver(entries => {
      if (entries[0].isIntersecting && !loading && hasMore) {
        setPage(p => p + 1);
      }
    });
    observer.observe(loaderRef.current);
    return () => observer.disconnect();
  }, [hasMore, loading]);
  const handleGenreSelect = (slug) => {
    setSelectedGenre(slug);
    setFilterMode('');
    const params = new URLSearchParams();
    if (slug) params.set('genre', slug);
    setSearchParams(params);
  };
  const handleFilterMode = (mode) => {
    setFilterMode(mode);
    setSelectedGenre('');
    const params = new URLSearchParams();
    if (mode) params.set('filter', mode);
    setSearchParams(params);
  };
  const clearFilters = () => {
    setSelectedGenre('');
    setFilterMode('');
    setSearchInput('');
    setSearch('');
    setSearchParams({});
  };
  const hasActiveFilter = selectedGenre || filterMode || search;
  return (
    <>
      <section className="relative w-full pt-28 md:pt-36 pb-12 md:pb-16 overflow-hidden">
        <div className="absolute inset-0 projector-glow opacity-50 pointer-events-none" />
        <div className="relative max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="text-center md:text-left mb-8">
            <p className="text-amber-500 text-sm font-bold uppercase tracking-widest mb-2">Thư viện phim</p>
            <h1 className="font-display text-4xl md:text-5xl lg:text-6xl font-black text-white">
              Tìm bộ phim của bạn
            </h1>
            <p className="text-zinc-400 text-base md:text-lg mt-3 max-w-2xl">
              Từ hành động kịch tính đến tài liệu khám phá - kho phim luôn được cập nhật.
            </p>
          </div>
          {/* Search bar */}
          <div className="relative max-w-2xl mb-8">
            <Search className="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-zinc-500" />
            <input
              type="text"
              value={searchInput}
              onChange={(e) => setSearchInput(e.target.value)}
              onCompositionStart={() => { isComposingRef.current = true; }}
              onCompositionEnd={(e) => {
                isComposingRef.current = false;
                setSearchInput(e.currentTarget.value);
              }}
              onKeyDown={(e) => {
                if (e.key === 'Enter' && !e.nativeEvent.isComposing && !isComposingRef.current) {
                  setSearch(searchInput);
                }
              }}
              placeholder="Tìm phim theo tên..."
              className="w-full pl-12 pr-4 py-4 bg-zinc-900/80 backdrop-blur-md border border-zinc-800 rounded-2xl text-white placeholder-zinc-500 focus:border-amber-500/50 focus:ring-2 focus:ring-amber-500/20 outline-none transition-all"
            />
            {searchInput && (
              <button
                onClick={() => { setSearchInput(''); setSearch(''); }}
                className="absolute right-4 top-1/2 -translate-y-1/2 text-zinc-500 hover:text-amber-500"
                aria-label="Clear search"
              >
                <X className="w-5 h-5" />
              </button>
            )}
          </div>
          {/* Filter chips */}
          <div className="flex flex-wrap items-center gap-2">
            <div className="flex items-center gap-2 text-zinc-400 text-sm mr-2">
              <Filter className="w-4 h-4" />
              <span className="hidden sm:inline">Lọc:</span>
            </div>
            <button
              onClick={() => handleFilterMode('')}
              className={`px-4 py-2 rounded-full text-sm font-semibold transition-all ${
                !selectedGenre && !filterMode
                  ? 'bg-amber-500 text-zinc-950'
                  : 'bg-zinc-900 text-zinc-400 border border-zinc-800 hover:border-amber-500/30 hover:text-amber-400'
              }`}
            >
              Tất cả
            </button>
            <button
              onClick={() => handleFilterMode('trending')}
              className={`px-4 py-2 rounded-full text-sm font-semibold transition-all ${
                filterMode === 'trending'
                  ? 'bg-amber-500 text-zinc-950'
                  : 'bg-zinc-900 text-zinc-400 border border-zinc-800 hover:border-amber-500/30 hover:text-amber-400'
              }`}
            >
              🔥 Thịnh hành
            </button>
            <button
              onClick={() => handleFilterMode('coming-soon')}
              className={`px-4 py-2 rounded-full text-sm font-semibold transition-all ${
                filterMode === 'coming-soon'
                  ? 'bg-amber-500 text-zinc-950'
                  : 'bg-zinc-900 text-zinc-400 border border-zinc-800 hover:border-amber-500/30 hover:text-amber-400'
              }`}
            >
              📅 Sắp ra mắt
            </button>
            {genres.map(genre => (
              <button
                key={genre.id}
                onClick={() => handleGenreSelect(genre.slug)}
                className={`px-4 py-2 rounded-full text-sm font-semibold transition-all ${
                  selectedGenre === genre.slug
                    ? 'bg-amber-500 text-zinc-950'
                    : 'bg-zinc-900 text-zinc-400 border border-zinc-800 hover:border-amber-500/30 hover:text-amber-400'
                }`}
              >
                {genre.name}
              </button>
            ))}
            {hasActiveFilter && (
              <button
                onClick={clearFilters}
                className="flex items-center gap-1 px-3 py-2 text-amber-500 hover:text-amber-400 text-sm font-medium"
              >
                <X className="w-3.5 h-3.5" />
                Xóa lọc
              </button>
            )}
          </div>
        </div>
      </section>
      <section className="relative w-full pb-20 md:pb-24">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          {!initialLoaded && loading ? (
            <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4 md:gap-6">
              {[...Array(8)].map((_, i) => (
                <div key={i} className="animate-pulse">
                  <div className="aspect-[2/3] bg-zinc-900 rounded-xl"></div>
                </div>
              ))}
            </div>
          ) : movies.length === 0 ? (
            <div className="text-center py-20">
              <div className="w-16 h-16 mx-auto mb-4 rounded-full bg-zinc-900 flex items-center justify-center">
                <Search className="w-7 h-7 text-zinc-600" />
              </div>
              <h3 className="font-display text-xl font-bold text-white mb-2">Không tìm thấy phim nào</h3>
              <p className="text-zinc-500 text-sm">Hãy thử từ khóa khác hoặc bỏ bộ lọc</p>
              {hasActiveFilter && (
                <button
                  onClick={clearFilters}
                  className="mt-4 px-5 py-2 bg-amber-500 text-zinc-950 rounded-full font-semibold text-sm hover:bg-amber-400 transition-colors"
                >
                  Xóa tất cả bộ lọc
                </button>
              )}
            </div>
          ) : (
            <>
              <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4 md:gap-6">
                {movies.map(movie => (
                  <MovieCard
                    key={movie.id}
                    movie={movie}
                    onPlayTrailer={(m) => setActiveTrailer({ youtubeId: m.trailerYoutubeId, title: m.title })}
                  />
                ))}
              </div>
              {hasMore && (
                <div ref={loaderRef} className="flex justify-center py-12">
                  {loading && (
                    <div className="w-8 h-8 border-4 border-amber-500/30 border-t-amber-500 rounded-full animate-spin"></div>
                  )}
                </div>
              )}
              {!hasMore && movies.length > 0 && (
                <p className="text-center text-zinc-600 text-sm mt-12">
                  Đã hiển thị tất cả {movies.length} phim
                </p>
              )}
            </>
          )}
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