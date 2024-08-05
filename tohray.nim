import prologue
import prologue/middlewares/staticfile
import prologue/middlewares/csrf
import prologue/middlewares/sessions/memorysession
import prologue/middlewares/utils
import net
import system
import ./urls
import ./initdb
import ./consts

# Initialize the database
initDb()
# Load the environment
let env = loadPrologueEnv(".env")
let
  data = %*{
      "inviteCode": consts.inviteCode,
      "siteName": consts.siteName,
      "siteTitle": consts.siteTitle
  }

let socket = newSocket()
socket.bindAddr(Port(consts.port), "0.0.0.0")
socket.setSockOpt(OptReuseAddr, true)
socket.listen()
let
  settings = newSettings(
    appName = env.getOrDefault("appName", "Tohray"),
    debug = env.getOrDefault("debug", false),
    listener = socket,
    secretKey = consts.secretKey,
    data = data
  )

var app = newApp(settings = settings)
app.use(@[debugResponseMiddleware(),
  sessionMiddleware(settings),
  csrfMiddleware(),
  staticFileMiddleware(env.getOrDefault("staticDir", "./static"))])
app.addRoute(urls.urlPatterns, "")
app.run()
