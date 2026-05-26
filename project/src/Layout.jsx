import React, { useState, useEffect } from 'react';
import { Link, NavLink, useLocation, Outlet } from 'react-router-dom';
import { Menu, X, Search, Heart, Film, Mail, MapPin } from 'lucide-react';
const LOGO = "https://dev-cdn.vibe-x.app/apps/c1c5a2aea6bd7484870548fc/assets/original/logo-0-299048f6-9082-4c21-85d6-c44d83544dc8.png";
const navLinks = [
  { path: '/', label: 'Trang chủ', end: true },
  { path: '/Movies', label: 'Phim' },
  { path: '/Genres', label: 'Thể loại' },
  { path: '/Actors', label: 'Diễn viên' },
  { path: '/Favorites', label: 'Yêu thích' },
];
function Navbar() {
  const [scrolled, setScrolled] = useState(false);
  const [menuOpen, setMenuOpen] = useState(false);
  const location = useLocation();
  useEffect(() => {
    const handler = () => setScrolled(window.scrollY > 40);
    window.addEventListener('scroll', handler);
    return () => window.removeEventListener('scroll', handler);
  }, []);
  useEffect(() => {
    setMenuOpen(false);
  }, [location.pathname]);
  return (
    <header className={`fixed top-0 left-0 right-0 z-50 transition-all duration-500 ${scrolled || menuOpen ? 'bg-[#0F0705]/95 backdrop-blur-lg shadow-lg shadow-black/40' : 'bg-gradient-to-b from-black/80 via-black/40 to-transparent'}`}>
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex items-center justify-between h-16 md:h-20">
          <Link to="/" className="flex items-center flex-shrink-0">
            <img src={LOGO} alt="V Drama" className="h-10 md:h-12 w-auto object-contain" />
          </Link>
          <nav className="hidden lg:flex items-center gap-1">
            {navLinks.map(link => (
              <NavLink
                key={link.path}
                to={link.path}
                end={link.end}
                className={({ isActive }) => `px-4 py-2 rounded-lg font-medium text-sm transition-all ${isActive ? 'text-red-500 bg-red-600/10' : 'text-stone-300 hover:text-white hover:bg-white/5'}`}
              >
                {link.label}
              </NavLink>
            ))}
          </nav>
          <div className="flex items-center gap-1">
            <Link to="/Search" className="p-2 text-stone-300 hover:text-white transition-colors hidden md:block" aria-label="Tìm kiếm">
              <Search className="w-5 h-5" />
            </Link>
            <Link to="/Favorites" className="p-2 text-stone-300 hover:text-red-500 transition-colors hidden md:block" aria-label="Yêu thích">
              <Heart className="w-5 h-5" />
            </Link>
            <button onClick={() => setMenuOpen(!menuOpen)} className="lg:hidden p-2 text-white" aria-label="Menu">
              {menuOpen ? <X className="w-6 h-6" /> : <Menu className="w-6 h-6" />}
            </button>
          </div>
        </div>
      </div>
      {menuOpen && (
        <div className="lg:hidden bg-[#0F0705] border-t border-stone-900">
          <div className="max-w-7xl mx-auto px-4 py-3 space-y-1">
            {navLinks.map(link => (
              <NavLink
                key={link.path}
                to={link.path}
                end={link.end}
                className={({ isActive }) => `block px-4 py-3 rounded-lg font-medium ${isActive ? 'text-red-500 bg-red-600/10' : 'text-stone-300 hover:bg-white/5'}`}
              >
                {link.label}
              </NavLink>
            ))}
            <Link to="/Search" className="px-4 py-3 rounded-lg font-medium text-stone-300 hover:bg-white/5 flex items-center gap-2">
              <Search className="w-5 h-5" /> Tìm kiếm
            </Link>
          </div>
        </div>
      )}
    </header>
  );
}
function Footer() {
  return (
    <footer className="bg-[#0F0705] border-t border-stone-900 relative overflow-hidden">
      <div className="absolute -right-32 top-0 w-96 h-96 bg-red-600/5 rounded-full blur-3xl pointer-events-none" />
      <div className="absolute -left-20 bottom-0 w-80 h-80 bg-amber-600/5 rounded-full blur-3xl pointer-events-none" />
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-10 md:py-14 relative">
        <div className="grid grid-cols-1 md:grid-cols-4 gap-8 md:gap-12">
          <div className="md:col-span-2">
            <img src={LOGO} alt="V Drama" className="h-10 md:h-12 w-auto mb-4 object-contain" />
            <p className="text-stone-400 text-sm leading-relaxed max-w-md">
              Nền tảng xem phim Việt Nam trực tuyến hàng đầu. Khám phá hàng nghìn bộ phim đặc sắc, từ kinh điển đến hiện đại, đậm chất văn hóa Á Đông.
            </p>
            <div className="flex items-center gap-3 mt-4 md:hidden text-stone-500 text-sm">
              <Mail className="w-4 h-4" /> hello@vdrama.vn
            </div>
          </div>
          <div className="hidden md:block">
            <h4 className="font-serif text-white font-bold mb-4 text-lg">Khám phá</h4>
            <ul className="space-y-2 text-sm">
              <li><Link to="/Movies" className="text-stone-400 hover:text-red-500 transition-colors">Tất cả phim</Link></li>
              <li><Link to="/Genres" className="text-stone-400 hover:text-red-500 transition-colors">Thể loại</Link></li>
              <li><Link to="/Actors" className="text-stone-400 hover:text-red-500 transition-colors">Diễn viên</Link></li>
              <li><Link to="/Favorites" className="text-stone-400 hover:text-red-500 transition-colors">Yêu thích</Link></li>
              <li><Link to="/Search" className="text-stone-400 hover:text-red-500 transition-colors">Tìm kiếm</Link></li>
            </ul>
          </div>
          <div className="hidden md:block">
            <h4 className="font-serif text-white font-bold mb-4 text-lg">Liên hệ</h4>
            <ul className="space-y-3 text-sm text-stone-400">
              <li className="flex items-center gap-2"><Mail className="w-4 h-4 text-red-500" /> hello@vdrama.vn</li>
              <li className="flex items-center gap-2"><MapPin className="w-4 h-4 text-red-500" /> Hà Nội, Việt Nam</li>
              <li className="flex items-center gap-2"><Film className="w-4 h-4 text-red-500" /> Phim Việt Nam</li>
            </ul>
          </div>
        </div>
        <div className="border-t border-stone-900 mt-8 md:mt-12 pt-6 flex flex-col md:flex-row items-center justify-between gap-3 text-sm text-stone-500">
          <p>© 2026 V Drama. All rights reserved.</p>
          <p className="text-xs italic">"Điện ảnh Việt - Tâm hồn Việt"</p>
        </div>
      </div>
    </footer>
  );
}
export default function Layout({ currentPageName }) {
  return (
    <div className="min-h-screen flex flex-col bg-stone-950 text-white overflow-x-hidden">
      <style>{`
        body { font-family: 'Inter', sans-serif; background: #0a0605; color: #fafaf9; }
        .font-serif { font-family: 'Playfair Display', serif; }
        ::-webkit-scrollbar { width: 10px; height: 10px; }
        ::-webkit-scrollbar-track { background: #1a0f0a; }
        ::-webkit-scrollbar-thumb { background: linear-gradient(180deg, #7c2d2d 0%, #4a1a14 100%); border-radius: 5px; }
        ::-webkit-scrollbar-thumb:hover { background: #DC2626; }
        .scrollbar-hide::-webkit-scrollbar { display: none; }
        .scrollbar-hide { -ms-overflow-style: none; scrollbar-width: none; }
        select { background-image: url("data:image/svg+xml,%3csvg xmlns='http://www.w3.org/2000/svg' fill='none' viewBox='0 0 20 20'%3e%3cpath stroke='%23999' stroke-linecap='round' stroke-linejoin='round' stroke-width='1.5' d='M6 8l4 4 4-4'/%3e%3c/svg%3e"); background-repeat: no-repeat; background-position: right 0.75rem center; background-size: 1.25em; padding-right: 2.5rem; appearance: none; -webkit-appearance: none; }
      `}</style>
      <Navbar />
      <main className="flex-1">
        <Outlet />
      </main>
      <Footer />
    </div>
  );
}