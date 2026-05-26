import { Outlet } from 'react-router-dom';
import Navbar from './components/Navbar';
import Footer from './components/Footer';
export default function Layout({ currentPageName }) {
  return (
    <div className="min-h-screen flex flex-col overflow-x-hidden bg-zinc-950">
      <Navbar currentPage={currentPageName} />
      <main className="flex-1">
        <Outlet />
      </main>
      <Footer />
    </div>
  );
}