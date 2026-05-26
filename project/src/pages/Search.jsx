import React, { useState, useEffect, useRef } from 'react';
import { Movie, Genre } from '@/api/entities';
import MovieCard from '@/components/MovieCard';
import { Search as SearchIcon, X } from 'lucide-react';
export default function Search() {
  const [movies, setMovies] = useState([]);
  const [genres, setGenres] = useState([]);
  const [searchInput, setSearchInput] = useState('');
  const [search, setSearch] = useState('');
  const [genreFilter, setGenreFilter] = useState('');
  const [yearFilter, setYearFilter] = useState('');
  const [ratingFilter, setRatingFilter] = useState('');
  const [loading, setLoading] = useState(false);
  const isComposingRef = useRef(false);
  const requestId = useRef(0);
  useEffect(() => {
    Genre.paging({ page: 1, limit: 50 }).then(res => setGenres(res.data?.data || [])).catch(() => {});
  }, []);
  useEffect(() => {
    if (isComposingRef.current) return;
    const timer = setTimeout(() => setSearch(searchInput), 300);
    return () => clearTimeout(timer);
  }, [searchInput]);
  useEffect(() => {
    const load = async () => {
      const id = ++requestId.current;
      setLoading(true);
      try {
        const filter = { search };
        if (genreFilter) filter.genreId = Number(genreFilter);
        if (yearFilter) filter.year = Number(yearFilter);
        if (ratingFilter) filter.rating = { $gte: Number(ratingFilter) };
        const res = await Movie.paging({ page: 1, limit: 60, filter, sort: '-rating' });
        if (id !== requestId.current) return;
        setMovies(res.data?.data || []);
      } catch (e) {
        console.error(e);
      } finally {
        if (id === requestId.current) setLoading(false);
      }
    };
    load();
  }, [search, genreFilter, yearFilter, ratingFilter]);
  const years = [2024, 2023, 2022, 2021, 2020, 2019, 2018, 2017, 2016];
  const hasFilters = search || genreFilter || yearFilter || ratingFilter;
  const clearFilters = () => {
    setSearchInput('');
    setSearch('');
    setGenreFilter('');
    setYearFilter('');
    setRatingFilter('');
  };
  return (
    <div className="bg-stone-950 min-h-screen pt-24 relative overflow-hidden">
      <div className="absolute -right-32 top-1/4 w-96 h-96 bg-red-600/10 rounded-full blur-3xl pointer-events-none" />
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8 pb-20 relative">
        <div className="text-center mb-8">
          <p className="text-amber-400 text-sm font-semibold tracking-[0.3em] uppercase mb-3">🏮 Tìm Kiếm</p>
          <h1 className="font-serif text-4xl md:text-5xl font-bold text-white mb-2">Khám phá phim yêu thích</h1>
        </div>
        <div className="max-w-3xl mx-auto mb-6">
          <div className="relative">
            <SearchIcon className="absolute left-5 top-1/2 -translate-y-1/2 w-6 h-6 text-stone-500 pointer-events-none" />
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
              placeholder="Tìm phim, diễn viên, đạo diễn..."
              className="w-full pl-14 pr-12 py-5 bg-stone-900 text-white text-lg rounded-2xl border border-stone-800 focus:border-red-600 focus:ring-2 focus:ring-red-600/30 outline-none placeholder:text-stone-500 transition shadow-xl shadow-red-900/10"
              autoFocus
            />
            {searchInput && (
              <button onClick={() => setSearchInput('')} className="absolute right-4 top-1/2 -translate-y-1/2 p-2 text-stone-400 hover:text-white" aria-label="Xóa">
                <X className="w-5 h-5" />
              </button>
            )}
          </div>
        </div>
        <div className="max-w-3xl mx-auto grid grid-cols-1 md:grid-cols-3 gap-3 mb-8">
          <select value={genreFilter} onChange={(e) => setGenreFilter(e.target.value)} className="px-4 py-3 bg-stone-900 text-white rounded-lg border border-stone-800 focus:border-red-600 outline-none">
            <option value="">Tất cả thể loại</option>
            {genres.map(g => <option key={g.id} value={g.id}>{g.name}</option>)}
          </select>
          <select value={yearFilter} onChange={(e) => setYearFilter(e.target.value)} className="px-4 py-3 bg-stone-900 text-white rounded-lg border border-stone-800 focus:border-red-600 outline-none">
            <option value="">Tất cả năm</option>
            {years.map(y => <option key={y} value={y}>{y}</option>)}
          </select>
          <select value={ratingFilter} onChange={(e) => setRatingFilter(e.target.value)} className="px-4 py-3 bg-stone-900 text-white rounded-lg border border-stone-800 focus:border-red-600 outline-none">
            <option value="">Đánh giá bất kỳ</option>
            <option value="8">8.0+ Xuất sắc</option>
            <option value="7">7.0+ Tốt</option>
            <option value="6">6.0+ Khá</option>
          </select>
        </div>
        {hasFilters && (
          <div className="flex items-center justify-between mb-6 max-w-3xl mx-auto">
            <p className="text-stone-400">
              {loading ? 'Đang tìm kiếm...' : `Tìm thấy ${movies.length} kết quả`}
            </p>
            <button onClick={clearFilters} className="text-red-500 hover:text-red-400 text-sm font-medium flex items-center gap-1">
              <X className="w-4 h-4" /> Xóa bộ lọc
            </button>
          </div>
        )}
        {loading ? (
          <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-6 gap-4">
            {Array.from({ length: 12 }).map((_, i) => <div key={i} className="aspect-[2/3] bg-stone-800 rounded-xl animate-pulse" />)}
          </div>
        ) : movies.length === 0 ? (
          <div className="text-center py-20">
            <SearchIcon className="w-20 h-20 text-stone-700 mx-auto mb-4" />
            <h3 className="text-2xl font-semibold text-white mb-2">
              {hasFilters ? 'Không tìm thấy kết quả' : 'Bắt đầu tìm kiếm'}
            </h3>
            <p className="text-stone-400">
              {hasFilters ? 'Thử thay đổi từ khóa hoặc bộ lọc' : 'Nhập từ khóa để tìm phim yêu thích'}
            </p>
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