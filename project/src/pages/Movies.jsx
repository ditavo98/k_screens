import React, { useState, useEffect, useRef } from 'react';
import { Movie, Genre } from '@/api/entities';
import MovieCard from '@/components/MovieCard';
import { Search as SearchIcon, Film } from 'lucide-react';
export default function Movies() {
  const [movies, setMovies] = useState([]);
  const [genres, setGenres] = useState([]);
  const [page, setPage] = useState(1);
  const [hasMore, setHasMore] = useState(true);
  const [loading, setLoading] = useState(false);
  const [total, setTotal] = useState(0);
  const [searchInput, setSearchInput] = useState('');
  const [search, setSearch] = useState('');
  const [genreFilter, setGenreFilter] = useState('');
  const [yearFilter, setYearFilter] = useState('');
  const [sortBy, setSortBy] = useState('-releaseDate');
  const isComposingRef = useRef(false);
  const isFirstMount = useRef(true);
  const loaderRef = useRef(null);
  const requestId = useRef(0);
  useEffect(() => {
    Genre.paging({ page: 1, limit: 50 }).then(res => setGenres(res.data?.data || [])).catch(() => {});
  }, []);
  const fetchData = async (pageNum, reset = false) => {
    const id = ++requestId.current;
    setLoading(true);
    try {
      const filter = { search };
      if (genreFilter) filter.genreId = Number(genreFilter);
      if (yearFilter) filter.year = Number(yearFilter);
      const res = await Movie.paging({ page: pageNum, limit: 12, filter, sort: sortBy });
      if (id !== requestId.current) return;
      const data = res.data?.data || [];
      setMovies(prev => reset ? data : [...prev, ...data]);
      setHasMore(pageNum < (res.data?.totalPages || 1));
      setTotal(res.data?.total || 0);
      setPage(pageNum);
    } catch (e) {
      console.error(e);
    } finally {
      if (id === requestId.current) setLoading(false);
    }
  };
  // Debounce search input
  useEffect(() => {
    if (isComposingRef.current) return;
    const timer = setTimeout(() => setSearch(searchInput), 300);
    return () => clearTimeout(timer);
  }, [searchInput]);
  // Initial + filter changes
  useEffect(() => {
    setMovies([]);
    setHasMore(true);
    fetchData(1, true);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [search, genreFilter, yearFilter, sortBy]);
  // Infinite scroll
  useEffect(() => {
    if (!loaderRef.current || !hasMore) return;
    const observer = new IntersectionObserver(entries => {
      if (entries[0].isIntersecting && !loading && hasMore) {
        fetchData(page + 1);
      }
    }, { rootMargin: '200px' });
    observer.observe(loaderRef.current);
    return () => observer.disconnect();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [hasMore, loading, page]);
  const years = [2024, 2023, 2022, 2021, 2020, 2019, 2018, 2017, 2016];
  return (
    <div className="bg-stone-950 min-h-screen pt-24">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8 pb-20">
        <div className="mb-8">
          <p className="text-amber-400 text-sm font-semibold tracking-widest uppercase mb-2">🏮 Thư viện</p>
          <h1 className="font-serif text-4xl md:text-5xl font-bold text-white mb-2">Tất Cả Phim</h1>
          <p className="text-stone-400">Khám phá kho phim Việt Nam đặc sắc với {total > 0 ? total : '...'} tựa phim</p>
        </div>
        {/* Filters */}
        <div className="bg-stone-900/60 backdrop-blur-md rounded-2xl p-4 md:p-6 mb-8 border border-stone-800" role="form" aria-label="Bộ lọc phim">
          <div className="grid grid-cols-1 md:grid-cols-4 gap-3 md:gap-4">
            <div className="relative">
              <SearchIcon className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-stone-500 pointer-events-none" />
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
                placeholder="Tìm phim..."
                className="w-full pl-10 pr-4 py-3 bg-stone-800 text-white rounded-lg border border-stone-700 focus:border-red-600 focus:ring-2 focus:ring-red-600/30 outline-none placeholder:text-stone-500 transition"
              />
            </div>
            <select value={genreFilter} onChange={(e) => setGenreFilter(e.target.value)} className="px-4 py-3 bg-stone-800 text-white rounded-lg border border-stone-700 focus:border-red-600 focus:ring-2 focus:ring-red-600/30 outline-none">
              <option value="">Tất cả thể loại</option>
              {genres.map(g => <option key={g.id} value={g.id}>{g.name}</option>)}
            </select>
            <select value={yearFilter} onChange={(e) => setYearFilter(e.target.value)} className="px-4 py-3 bg-stone-800 text-white rounded-lg border border-stone-700 focus:border-red-600 focus:ring-2 focus:ring-red-600/30 outline-none">
              <option value="">Tất cả năm</option>
              {years.map(y => <option key={y} value={y}>{y}</option>)}
            </select>
            <select value={sortBy} onChange={(e) => setSortBy(e.target.value)} className="px-4 py-3 bg-stone-800 text-white rounded-lg border border-stone-700 focus:border-red-600 focus:ring-2 focus:ring-red-600/30 outline-none">
              <option value="-releaseDate">Mới nhất</option>
              <option value="-rating">Đánh giá cao</option>
              <option value="-viewCount">Lượt xem nhiều</option>
              <option value="title">Tên A-Z</option>
            </select>
          </div>
        </div>
        {/* Grid */}
        <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-6 gap-4 md:gap-6">
          {movies.map(m => <MovieCard key={m.id} movie={m} />)}
          {loading && Array.from({ length: 6 }).map((_, i) => (
            <div key={`skel-${i}`} className="aspect-[2/3] bg-stone-800 rounded-xl animate-pulse" />
          ))}
        </div>
        {!loading && movies.length === 0 && (
          <div className="text-center py-20">
            <Film className="w-16 h-16 text-stone-700 mx-auto mb-4" />
            <h3 className="text-xl font-semibold text-white mb-2">Không tìm thấy phim</h3>
            <p className="text-stone-400">Thử tìm kiếm với từ khóa hoặc bộ lọc khác</p>
          </div>
        )}
        {hasMore && <div ref={loaderRef} className="h-10" />}
      </div>
    </div>
  );
}