import Layout from './Layout.jsx';
import Home from './pages/Home.jsx';
import Movies from './pages/Movies.jsx';
import Genres from './pages/Genres.jsx';
import Search from './pages/Search.jsx';
import Actors from './pages/Actors.jsx';
import Favorites from './pages/Favorites.jsx';
import MovieDetail from './pages/MovieDetail.jsx';
import GenreDetail from './pages/GenreDetail.jsx';
import ActorDetail from './pages/ActorDetail.jsx';
import Watch from './pages/Watch.jsx';
export const PAGES = {
  Home,
  Movies,
  Genres,
  Search,
  Actors,
  Favorites,
  "movies/:slug": MovieDetail,
  "genres/:slug": GenreDetail,
  "actors/:slug": ActorDetail,
  "watch/:slug": Watch,
};
export const ADMINS = {};
export const PRIVATE_PAGES = {};
export const pagesConfig = {
  privatePages: PRIVATE_PAGES,
  mainPage: "Home",
  Pages: PAGES,
  Layout: Layout,
  Admins: ADMINS,
  adminMainPage: "",
  AdminLayout: null,
};