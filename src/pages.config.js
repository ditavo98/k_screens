import Layout from './Layout.jsx';
import Home from './pages/Home.jsx';
import Movies from './pages/Movies.jsx';
import MovieDetail from './pages/MovieDetail.jsx';
export const PAGES = {
  Home,
  movies: Movies,
  "movies/:slug": MovieDetail,
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