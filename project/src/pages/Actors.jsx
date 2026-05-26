import React, { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { Actor } from '@/api/entities';
import { motion } from 'framer-motion';
import { Users } from 'lucide-react';
export default function Actors() {
  const [actors, setActors] = useState([]);
  const [loading, setLoading] = useState(true);
  useEffect(() => {
    Actor.paging({ page: 1, limit: 50 }).then(res => {
      setActors(res.data?.data || []);
      setLoading(false);
    }).catch(() => setLoading(false));
  }, []);
  return (
    <div className="bg-stone-950 min-h-screen pt-24 relative overflow-hidden">
      <div className="absolute -right-32 top-1/4 w-96 h-96 bg-red-600/10 rounded-full blur-3xl pointer-events-none" />
      <div className="absolute -left-32 bottom-1/4 w-96 h-96 bg-amber-600/10 rounded-full blur-3xl pointer-events-none" />
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8 pb-20 relative">
        <div className="text-center mb-12">
          <p className="text-amber-400 text-sm font-semibold tracking-[0.3em] uppercase mb-3">🏮 Nghệ Sĩ</p>
          <h1 className="font-serif text-4xl md:text-5xl lg:text-6xl font-bold text-white mb-4">Diễn Viên Việt Nam</h1>
          <div className="w-24 h-1 bg-gradient-to-r from-red-600 to-amber-500 mx-auto rounded-full" />
          <p className="text-stone-400 mt-6 max-w-2xl mx-auto">Gặp gỡ những gương mặt làm nên thành công của điện ảnh Việt Nam đương đại.</p>
        </div>
        {loading ? (
          <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 gap-6 md:gap-8">
            {Array.from({ length: 8 }).map((_, i) => (
              <div key={i} className="text-center">
                <div className="w-32 h-32 md:w-40 md:h-40 mx-auto rounded-full bg-stone-800 animate-pulse mb-3" />
                <div className="h-4 bg-stone-800 rounded animate-pulse mx-auto w-24" />
              </div>
            ))}
          </div>
        ) : actors.length === 0 ? (
          <div className="text-center py-16">
            <Users className="w-16 h-16 text-stone-700 mx-auto mb-4" />
            <p className="text-stone-400">Chưa có dữ liệu diễn viên</p>
          </div>
        ) : (
          <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 gap-6 md:gap-10">
            {actors.map((a, i) => (
              <motion.div
                key={a.id}
                initial={{ opacity: 0, scale: 0.85 }}
                animate={{ opacity: 1, scale: 1 }}
                transition={{ delay: i * 0.05, duration: 0.4 }}
              >
                <Link to={`/actors/${a.slug}`} className="group block text-center">
                  <div className="relative w-32 h-32 md:w-40 md:h-40 mx-auto mb-4 rounded-full overflow-hidden ring-4 ring-red-900/50 group-hover:ring-red-600 transition-all duration-500 group-hover:scale-105 shadow-xl shadow-red-900/30 group-hover:shadow-red-700/50">
                    <div className="w-full h-full bg-gradient-to-br from-red-900 via-red-800 to-amber-900 flex items-center justify-center">
                      <span className="font-serif text-5xl md:text-6xl font-bold text-white drop-shadow-lg">{a.name.split(' ').pop().charAt(0)}</span>
                    </div>
                  </div>
                  <h3 className="text-white font-bold text-base md:text-lg mb-1">{a.name}</h3>
                  <p className="text-stone-400 text-xs md:text-sm line-clamp-1">{a.knownFor}</p>
                  {a.birthYear && <p className="text-amber-400/70 text-xs mt-1">Sinh {a.birthYear}</p>}
                </Link>
              </motion.div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}