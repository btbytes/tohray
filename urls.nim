import prologue
import ./views

const urlPatterns* = @[
  pattern("/", homepage, HttpGet, name = "index"),
  pattern("/login", login, @[HttpGet, HttpPost], name = "login"),
  pattern("/logout", logout, HttpGet),
  pattern("/register", register, @[HttpGet, HttpPost]),
  pattern("/write", createPost, @[HttpGet, HttpPost], name="write"),
  pattern("/delete", deletePost, @[HttpGet, HttpPost], name="delete"),
  pattern("/export", exportAll, HttpGet, name="export"),
  pattern("/calendar", calendarView, HttpGet, name="calendar"),
  pattern("/{slug}", showPost),
]
