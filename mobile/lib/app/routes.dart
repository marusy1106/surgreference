/// Пути экранов (go_router).
abstract final class Routes {
  static const splash = '/splash';
  static const welcome = '/welcome';
  static const login = '/login';
  static const register = '/register';
  static const forgot = '/forgot';
  static const verify = '/verify';

  static const home = '/home';
  static const catalog = '/catalog';
  static const practice = '/practice';
  static const leaderboard = '/leaderboard';
  static const profile = '/profile';

  static const progress = '/progress';
  static const sessions = '/settings/sessions';
  static const password = '/settings/password';
  static const deleteAccount = '/settings/delete';
  static const education = '/settings/education';
  static const universitySearch = '/settings/education/university';

  static String discipline(String id) => '/catalog/$id';
  static String lesson(String id) => '/lesson/$id';
  static String quiz(String quizId) => '/quiz/$quizId';
  static String training(String slug) => '/training/$slug';
  static String mistakes(String slug) => '/mistakes/$slug';
  static String clinicalCase(String id) => '/case/$id';

  /// Доступны без входа.
  static const public = {welcome, login, register, forgot};
}
