import prologue
import ./views

const urlPatterns* = @[
  pattern("/", homepage, HttpGet, name = "index"),
  pattern("/login", login, @[HttpGet, HttpPost], name = "login"),
  pattern("/logout", logout, HttpGet, name = "logout"),
  pattern("/register", register, @[HttpGet, HttpPost], name = "register"),
  pattern("/write", createPost, @[HttpGet, HttpPost], name = "write"),
  pattern("/edit/{slug}", editPost, @[HttpGet, HttpPost], name = "edit"),
  pattern("/delete/{slug}", deletePost, @[HttpGet, HttpPost], name = "delete"),
  pattern("/export", exportAll, HttpGet, name = "export"),
  pattern("/calendar", calendarView, HttpGet, name = "calendar"),
  pattern("/rss", rssView, HttpGet, name="rss"),
  pattern("/{slug}", showPost, name = "post"),
]
