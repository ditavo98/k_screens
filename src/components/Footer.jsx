import { Link } from 'react-router-dom';
import { Facebook, Instagram, Youtube, Twitter, Mail } from 'lucide-react';
export default function Footer() {
  return (
    <footer className="relative bg-zinc-950 border-t border-zinc-900 overflow-hidden">
      <div className="absolute inset-0 projector-glow opacity-30 pointer-events-none" />
      <div className="relative max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12 md:py-16">
        <div className="grid grid-cols-1 md:grid-cols-4 gap-8 md:gap-12">
          <div className="md:col-span-2">
            <Link to="/" className="inline-block mb-4">
              <img
                src="https://dev-cdn.vibe-x.app/apps/1039ac5e1549db6ef94787c1/assets/original/logo-0-b45a96d5-1988-48ce-b103-eb3e8f1e0c23.png"
                alt="K Screens"
                className="h-12 w-auto object-contain"
                style={ { filter: 'brightness(100) invert(30%)' } }
              />
            </Link>
            <p className="text-zinc-400 text-sm md:text-base max-w-md leading-relaxed">
              Khám phá thế giới điện ảnh qua những trailer phim đỉnh cao. Mỗi bộ phim là một hành trình - hãy bước vào ánh đèn chiếu cùng chúng tôi.
            </p>
            <div className="flex items-center gap-3 mt-6">
              {[Facebook, Instagram, Youtube, Twitter].map((Icon, i) => (
                <a
                  key={i}
                  href="#"
                  className="w-10 h-10 rounded-full bg-zinc-900 border border-zinc-800 flex items-center justify-center text-zinc-400 hover:text-amber-500 hover:border-amber-500/40 transition-all"
                  aria-label="Social link"
                >
                  <Icon className="w-4 h-4" />
                </a>
              ))}
            </div>
          </div>
          <div className="hidden md:block">
            <h4 className="font-display text-amber-500 font-bold text-lg mb-4">Khám phá</h4>
            <ul className="space-y-3">
              <li><Link to="/" className="text-zinc-400 hover:text-amber-500 text-sm transition-colors">Trang chủ</Link></li>
              <li><Link to="/movies" className="text-zinc-400 hover:text-amber-500 text-sm transition-colors">Tất cả phim</Link></li>
              <li><Link to="/movies?filter=trending" className="text-zinc-400 hover:text-amber-500 text-sm transition-colors">Thịnh hành</Link></li>
              <li><Link to="/movies?filter=coming-soon" className="text-zinc-400 hover:text-amber-500 text-sm transition-colors">Sắp ra mắt</Link></li>
            </ul>
          </div>
          <div className="hidden md:block">
            <h4 className="font-display text-amber-500 font-bold text-lg mb-4">Liên hệ</h4>
            <ul className="space-y-3 text-sm text-zinc-400">
              <li className="flex items-center gap-2">
                <Mail className="w-4 h-4 text-amber-500/60" />
                hello@kscreens.vn
              </li>
              <li>Hà Nội, Việt Nam</li>
            </ul>
          </div>
        </div>
        <div className="border-t border-zinc-900 mt-10 md:mt-12 pt-6 flex flex-col md:flex-row items-center justify-between gap-3">
          <p className="text-xs md:text-sm text-zinc-500">
            © 2026 K Screens. Mọi quyền được bảo lưu.
          </p>
          <p className="text-xs text-zinc-600">
            Trailer được nhúng từ YouTube. Bản quyền thuộc về nhà sản xuất phim.
          </p>
        </div>
      </div>
    </footer>
  );
}