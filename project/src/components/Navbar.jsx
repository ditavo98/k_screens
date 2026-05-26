import { useState, useEffect } from 'react';
import { Link, useLocation } from 'react-router-dom';
import { Menu, X, Search } from 'lucide-react';
export default function Navbar() {
  const [isOpen, setIsOpen] = useState(false);
  const [scrolled, setScrolled] = useState(false);
  const location = useLocation();
  useEffect(() => {
    const handleScroll = () => setScrolled(window.scrollY > 30);
    window.addEventListener('scroll', handleScroll);
    return () => window.removeEventListener('scroll', handleScroll);
  }, []);
  useEffect(() => {
    setIsOpen(false);
  }, [location.pathname]);
  const navLinks = [
    { name: 'Trang chủ', path: '/' },
    { name: 'Phim', path: '/movies' },
    { name: 'Thể loại', path: '/movies?filter=genres' },
    { name: 'Sắp ra mắt', path: '/movies?filter=coming-soon' },
  ];
  return (
    <header
      className={`fixed top-0 left-0 right-0 z-40 transition-all duration-500 ${
        scrolled
          ? 'bg-zinc-950/90 backdrop-blur-xl border-b border-zinc-800/50'
          : 'bg-gradient-to-b from-zinc-950/80 to-transparent'
      }`}
    >
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex items-center justify-between h-16 md:h-20">
          <Link to="/" className="flex items-center gap-2 group">
            <img
              src="https://dev-cdn.vibe-x.app/apps/1039ac5e1549db6ef94787c1/assets/original/logo-0-b45a96d5-1988-48ce-b103-eb3e8f1e0c23.png"
              alt="K Screens"
              className="h-10 md:h-12 w-auto object-contain"
            />
          </Link>
          <nav className="hidden md:flex items-center gap-8">
            {navLinks.map((link) => (
              <Link
                key={link.path}
                to={link.path}
                className="text-sm font-medium text-zinc-300 hover:text-amber-500 transition-colors relative group"
              >
                {link.name}
                <span className="absolute -bottom-1 left-0 w-0 h-0.5 bg-amber-500 group-hover:w-full transition-all duration-300"></span>
              </Link>
            ))}
            <Link
              to="/movies"
              className="flex items-center gap-2 px-5 py-2 bg-amber-500 text-zinc-950 rounded-full font-semibold text-sm hover:bg-amber-400 transition-colors"
            >
              <Search className="w-4 h-4" />
              Tìm phim
            </Link>
          </nav>
          <button
            onClick={() => setIsOpen(!isOpen)}
            className="md:hidden p-2 text-zinc-200 hover:text-amber-500 transition-colors"
            aria-label="Toggle menu"
          >
            {isOpen ? <X className="w-6 h-6" /> : <Menu className="w-6 h-6" />}
          </button>
        </div>
      </div>
      {isOpen && (
        <div className="md:hidden bg-zinc-950/95 backdrop-blur-xl border-t border-zinc-800/50">
          <div className="px-4 py-4 space-y-1">
            {navLinks.map((link) => (
              <Link
                key={link.path}
                to={link.path}
                className="block px-4 py-3 text-zinc-300 hover:text-amber-500 hover:bg-zinc-900/50 rounded-lg transition-colors font-medium"
              >
                {link.name}
              </Link>
            ))}
            <Link
              to="/movies"
              className="flex items-center justify-center gap-2 mt-3 px-4 py-3 bg-amber-500 text-zinc-950 rounded-lg font-semibold"
            >
              <Search className="w-4 h-4" />
              Tìm phim
            </Link>
          </div>
        </div>
      )}
    </header>
  );
}