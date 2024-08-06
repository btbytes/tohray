import db_connector/db_sqlite
import karax / [karaxdsl, vdom]
import logging
import markdown
import parseutils
import prologue
import prologue/middlewares/csrf
import prologue/security/hasher
import strformat
import strutils
import tables
import times
import unicode
import uri

import ./consts

var logger = newConsoleLogger(fmtStr = "[$datetime] - $levelname: ")
addHandler(logger)

proc filterSpecialChars*(input: string): string =
  result = ""
  for c in input.runes:
    if c.isAlpha or c == '_'.Rune:
      result.add(c)

proc isValidYearMonth*(s: string): bool =
  if s.len != 7 or s[4] != '-':
    return false

  var year, month: int
  if parseint(s[0..3], year) != 4 or
      parseint(s[5..6], month) != 2:
    return false

  if year < 1979 or year > 3024:
    return false

  if month < 1 or month > 12:
    return false

  return true

proc baseLayout(ctx: Context, title: string, content: VNode) {.async.} =
  let fullname = ctx.session.getOrDefault("userFullname", "")
  let vnode = buildHtml(html):
    head:
      link(href = "/static/terminal.min.css", rel = "stylesheet")
      link(href = "/static/style.css", rel = "stylesheet")
      link(href = "/static/favicon.ico", type = "image/x-icon", rel = "icon")
      title: text title
    body(class = "terminal"):
      tdiv(class = "container"):
        tdiv(class = "terminal-nav"):
          header(class = "terminal-logo"):
            tdiv(class = "logo"):
              a(href = "/", class = "no-style"):
                text ctx.getSettings("siteName").getStr()
          nav(class = "terminal-menu"):
            ul(vocab = "https://schema.org/", typeof = "BreadcrumbList"):
              li(property = "itemListElement", typeof = "ListItem"):
                form(`method` = "GET", action = "/"):
                  input(type = "text", id = "searchtext", name = "query",
                      placeholder = "search")
                meta(property = "position", content = "1")
          nav(class = "terminal-menu"):
            ul(vocab = "https://schema.org/", typeof = "BreadcrumbList"):
              if fullname.len > 0:
                li(property = "itemListElement", typeof = "ListItem"):
                  span(): text fullname
                  meta(property = "position", content = "1")
                li(property = "itemListElement", typeof = "ListItem"):
                  a(href = urlFor(ctx, "write"), property = "item",
                      typeof = "WebPage", class = "menu-item"):
                    span(property = "name"): text "Write"
                  meta(property = "position", content = "2")
                li(property = "itemListElement", typeof = "ListItem"):
                  a(href = "/logout", property = "item", typeof = "WebPage",
                      class = "menu-item"):
                    span(property = "name"): text "Logout"
                  meta(property = "position", content = "3")
              else:
                li(property = "itemListElement", typeof = "ListItem"):
                  a(href = "/about", property = "item", typeof = "WebPage",
                      class = "menu-item"):
                    span(property = "name"): text "About"
                  meta(property = "position", content = "1")
                li(property = "itemListElement", typeof = "ListItem"):
                  a(href = "/login", property = "item", typeof = "WebPage",
                      class = "menu-item"):
                    span(property = "name"): text "Login"
                  meta(property = "position", content = "2")

      tdiv(class = "container"):
        h1: text ctx.getSettings("siteTitle").getStr()
        content
  resp "<!DOCTYPE html>\n" & $vnode

proc loginPage(ctx: Context, error: string = ""): VNode =
  let csrfToken = ctx.generateToken()
  result = buildHtml(main(class = "content")):
    if error.len > 0:
      tdiv(class = "terminal-alert terminal-alert-error"):
        text error
    form(`method` = "post"):
      fieldset():
        input(type = "hidden", name = "CSRFToken", value = csrfToken)
        legend(): text "Login"
        tdiv(class = "form-group"):
          label(`for` = "username"): text "Username"
          input(type = "text", name = "username", id = "username",
              required = "required")
        tdiv(class = "form-group"):
          label(`for` = "password"): text "Password"
          input(`type` = "password", name = "password", id = "password",
                  required = "required")
        tdiv(class = "form-group"):
          button(class = "btn btn-default", type = "submit", role = "button",
              name = "submit", id = "submit"): text "Login"

proc login*(ctx: Context) {.async.} =
  let db = open(consts.dbPath, "", "", "")
  defer: db.close()
  if ctx.request.reqMethod == HttpPost:
    var
      error: string
      id: string
      fullname: string
      encoded: string
    let
      username = ctx.getPostParams("username")
      password = SecretKey(ctx.getPostParams("password"))
      row = db.getRow(sql"SELECT * FROM users WHERE username = ?", username)
    if row.len == 0:
      error = "Incorrect username"
    elif row.len < 3:
      error = "Incorrect username"
    else:
      id = row[0]
      fullname = row[1]
      encoded = row[3]

      if not pbkdf2_sha256verify(password, encoded):
        error = "Incorrect password"

    if error.len == 0:
      ctx.session.clear()
      ctx.session["userId"] = id
      ctx.session["userFullname"] = fullname
      resp redirect(urlFor(ctx, "index"), Http302)
    else:
      result = baseLayout(ctx, "Login", loginPage(ctx, error))
  else:
    result = baseLayout(ctx, "Login", loginPage(ctx))


proc registerPage(ctx: Context, error: string = ""): VNode =
  let csrfToken = ctx.generateToken()
  result = buildHtml(main(class = "content")):
    h3: text "Register"
    if error.len > 0:
      tdiv(class = "terminal-alert terminal-alert-error"):
        text error
    form(`method` = "post"):
      fieldset():
        legend(): text "You need to have an invite code to register"
        input(type = "hidden", name = "CSRFToken", value = csrfToken)
        tdiv(class = "form-group"):
          label(`for` = "fullname"): text "Full name"
          input(type = "text", name = "fullname", id = "fullname",
              required = "required")
        tdiv(class = "form-group"):
          label(`for` = "username"): text "Username"
          input(type = "text", name = "username", id = "username",
              required = "required")
        tdiv(class = "form-group"):
          label(`for` = "password"): text "Password"
          input(`type` = "password", name = "password", id = "password",
              required = "required")
        tdiv(class = "form-group"):
          label(`for` = "invitecode"): text "Invite Code"
          input(type = "text", name = "invitecode", id = "invitecode",
              required = "required")
        tdiv(class = "form-group"):
          button(class = "btn btn-default", type = "submit", role = "button",
              name = "submit", id = "submit"): text "Register"

proc register*(ctx: Context) {.async.} =
  let db = open(consts.dbPath, "", "", "")
  defer: db.close()
  if ctx.request.reqMethod == HttpPost:
    var error: string
    let
      username = ctx.getPostParams("username")
      password = pbkdf2_sha256encode(SecretKey(ctx.getPostParams(
              "password")), "Prologue")
      invitecode = ctx.getPostParams("invitecode")
    var fullname = ctx.getPostParams("fullname")
    let expic = ctx.getSettings("inviteCode").getStr()
    if invitecode != expic:
      error = "incorrect invite code"
    if username.len == 0:
      error = "username required"
    elif password.len == 0:
      error = "password required"
    elif db.getValue(sql"SELECT id FROM users WHERE username = ?",
            username).len != 0:
      error = fmt"Username {username} registered already"

    if error.len == 0:
      if fullname.len == 0:
        fullname = username
      db.exec(sql"INSERT INTO users (fullname, username, password) VALUES (?, ?, ?)",
        fullname, username, password)
      resp redirect(urlFor(ctx, "login"), Http301)
    else:
      result = baseLayout(ctx, "Register", registerPage(ctx, error))
  else:
    result = baseLayout(ctx, "Register", registerPage(ctx))


proc logout*(ctx: Context) {.async.} =
  ctx.session.clear()
  resp redirect(urlFor(ctx, "index"), Http302)


proc renderEntry(slug: string, timestamp: string, content: string): VNode =
  let month = timestamp[0 ..< 7]
  let time = timestamp[^8 .. ^1]
  let vnode = buildHtml(tdiv(class = "grid-container entry")):
    tdiv(class = "grid-item"):
      a(href = fmt"/?month={month}"): text timestamp[0 ..< 10]
      span(): text " "
      a(class = "timestamp", href = fmt"/{slug}"): text time
    tdiv(class = "grid-item"):
      verbatim(markdown(content))
  return vnode

proc getPage(page: string): int =
  var res = 1
  if page != "":
    try:
      res = parseInt(page)
      if res < 1:
        res = 1
    except ValueError:
      # If parseInt fails, we keep the default value of 1
      discard
  result = res

proc getPosts(page: int, month: string = ""): seq[Row] =
  let
    offset = (page - 1) * 10
    db = open(consts.dbPath, "", "", "")
  defer: db.close()
  let monthQ = if isValidYearMonth(month): "WHERE strftime('%Y-%m', created) = ?" else: ""
  let query = fmt """
    SELECT slug, created, content
    FROM post
    {monthQ}
    ORDER BY id DESC
    LIMIT 10 OFFSET ?;
  """
  if isValidYearMonth(month):
    result = db.getAllRows(sql(query), month, offset)
  else:
    result = db.getAllRows(sql(query), offset)

proc getQueryPosts(query: string, pageNumber: int): seq[Row] =
  let
    offset = (pageNumber - 1) * 10
    db = open(consts.dbPath, "", "", "")
    query = filterSpecialChars(query)
  let q = """SELECT p.slug, p.created, p.content, bm25(post_fts) AS rank
    FROM post_fts
    JOIN post p ON post_fts.rowid = p.id
    WHERE post_fts.content MATCH ?
    ORDER BY rank
    LIMIT 10 OFFSET ?;"""
  defer: db.close()

  result = db.getAllRows(sql(q), query, $offset)

proc constructPageUrl(month: string, page: int, query: string): string =
  var params: seq[(string, string)] = @[]
  params.add(("page", $page))
  if query != "":
    params.add(("query", query))
  if isValidYearMonth(month):
    params.add(("month", month))
  result = "?" & encodeQuery(params)

proc pageNav(month: string, page: int, query: string): VNode =
  var pageurl: string
  pageurl = constructPageUrl(month, page+1, query)
  let vnode = buildHtml():
    a(href = fmt"{pageurl}"): text "➡️"
    # ERROR: 'VNode' and has to be used (or discarded)
    # if page > 1:
    #  pageurl = constructPageUrl(page-1, query)
    #  a(href=fmt"{pageurl}"): text "⬅️"
  return vnode

proc homepage*(ctx: Context) {.async gcsafe.} =
  let
    pageParam = ctx.getQueryParams("page", "1")
    query = ctx.getQueryParams("query", "")
    month = ctx.getQueryparams("month", "")
    page = getPage(pageParam)
  var rows: seq[Row]

  if query == "":
    rows = getPosts(page, month)
  else:
    rows = getQueryPosts(query, page)
  let vnode = buildHtml(tdiv()):
    for row in rows:
      renderEntry(row[0], row[1], row[2])
    tdiv(id = "pagenav"):
      pageNav(month, page, query)
  result = baseLayout(ctx, "Stream", vnode)


proc showPost*(ctx: Context) {.async.} =
  let
    slug = ctx.getPathParams("slug", "")
    format = ctx.getQueryParams("format", "html")
    db = open(consts.dbPath, "", "", "")
    rows = db.getAllRows(sql"SELECT slug, created, content FROM post where slug = ?", slug)
  db.close()
  if rows.len == 0:
    resp "The requested resource was not found", Http404
  else:
    if format == "html":
      let vnode = buildHtml():
        renderEntry($rows[0][0], $rows[0][1], $rows[0][2])
      result = baseLayout(ctx, "Homepage", vnode)
    elif format == "md":
      ctx.response.addHeader("Content-Type", "text/plain")
      resp "slug = " & slug & "\n\n" & $rows[0][2]


proc newpostPage(ctx: Context, error: string = ""): VNode =
  let csrfToken = ctx.generateToken()
  let vnode = buildHtml(tdiv(id = "postform")):
    if error.len > 0:
      tdiv(class = "terminal-alert terminal-alert-error"):
        text error
    form(`method` = "POST", name = "write", id = "write"):
      fieldset():
        legend(): text "Create a new Post"
        input(type = "hidden", name = "CSRFToken", value = csrfToken)
        tdiv(class = "form-group"):
          label(`for` = "content"): text "Content"
          textarea(name = "content", id = "content", rows = "10", cols = "80")
        tdiv(class = "form-group"):
          label(`for` = "slug"): text "Post Slug"
          input(type = "text", name = "slug", id = "slug", value = $epochTime().int)
        tdiv(class = "form-group"):
          button(class = "btn btn-default", type = "submit", role = "button",
              name = "submit"): text "Create Post"
  return vnode


proc createPost*(ctx: Context) {.async.} =
  if ctx.session.getOrDefault("userId", "").len != 0:
    if ctx.request.reqMethod == HttpPost:
      let
        db = open(consts.dbPath, "", "", "")
        slug = ctx.getPostParams("slug")
        content = ctx.getPostParams("content")
      try:
        db.exec(sql"INSERT INTO post (author_id, slug, content) VALUES (?, ?, ?)",
        ctx.session["userId"], slug, content)
        resp redirect(urlFor(ctx, "index"), Http302)
      except DbError as e:
        resp fmt"Database error occurred: {e.msg}", Http500
      except Exception as e:
        resp fmt"An unexpected error occurred: {e.msg}", Http500
    else:
      result = baseLayout(ctx, "New Post", newpostPage(ctx))
  else:
    resp redirect(urlFor(ctx, "login"), Http302)

proc deletePage(ctx: Context, error: string = ""): VNode =
  let csrfToken = ctx.generateToken()
  let vnode = buildHtml(tdiv(id = "postform")):
    if error.len > 0:
      tdiv(class = "terminal-alert terminal-alert-error"):
        text error
    form(name = "delete", id = "deleteform", `method` = "POST", action = urlFor(
        ctx, "delete")):
      fieldset():
        legend(): text "Delete a Post"
        input(type = "hidden", name = "CSRFToken", value = csrfToken)
        tdiv(class = "form-group"):
          label(`for` = "slug"): text "Post Slug"
          input(type = "text", name = "slug", id = "slug")
        tdiv(class = "form-group"):
          button(class = "btn btn-default", type = "submit", role = "button",
              name = "submit"): text "Delete Post"
  return vnode

proc deletePost*(ctx: Context) {.async.} =
  if ctx.session.getOrDefault("userId", "").len != 0:
    if ctx.request.reqMethod == HttpPost:
      let
        db = open(consts.dbPath, "", "", "")
        slug = ctx.getPostParams("slug")
      try:
        db.exec(sql"DELETE FROM post where slug=?", slug)
        resp redirect(urlFor(ctx, "index"), Http302)
      except DbError as e:
        resp fmt"Database error occurred: {e.msg}", Http500
      except Exception as e:
        resp fmt"An unexpected error occurred: {e.msg}", Http500
    else:
      result = baseLayout(ctx, "Delete Post", deletePage(ctx))
  else:
    resp redirect(urlFor(ctx, "login"), Http302)

proc exportAll*(ctx: Context) {.async.} =
  let
    format = ctx.getQueryParams("format", "json")
    db = open(consts.dbPath, "", "", "")
    rows = db.getAllRows(sql"SELECT slug, created, content FROM post ORDER BY created DESC")
  defer: db.close()
  if format == "json":
    ctx.response.addHeader("Content-Type", "application/json")
    var jsonArray = newJArray()
    for row in rows:
      var jsonObject = %*{
        "slug": row[0],
        "created": row[1],
        "content": row[2]
      }
      jsonArray.add(jsonObject)
    resp jsonResponse(%*{"posts": jsonArray})
  elif format == "md":
    ctx.response.addHeader("Content-Type", "text/plain")
    ctx.response.addHeader("Content-Disposition: inline", "filename=\"stream.txt\"")
    var res: string
    for row in rows:
      res = res & "\n" & row[0] & "\n" & row[1] & "\n\n" & $row[2] & "\n\n" &
          chr(28) # ascii file separator
    resp res

proc getAllPostCounts(): Table[int, array[12, int]] =
  let db = open(consts.dbPath, "", "", "")
  let query = sql"""
      SELECT strftime('%Y', created) as year,
             strftime('%m', created) as month,
             COUNT(*) as count
      FROM post
      GROUP BY year, month
      ORDER BY year, month
    """
  result = initTable[int, array[12, int]]()
  for row in db.getAllRows(query):
    let year = parseInt(row[0])
    let month = parseInt(row[1]) - 1 # 0-based index for months
    let count = parseInt(row[2])
    if year notin result:
      result[year] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    result[year][month] = count

proc calendarView*(ctx: Context) {.async.} =
  let postCounts = getAllPostCounts()

  let vnode = buildHtml(table(id = "calendar")):
    for year, counts in postCounts.pairs:
      tr:
        td: text $year
        for month in Month:
          let count = counts[month.ord-1]
          td:
            if count > 0:
              a(href = fmt"/?month={year}-{align($(month.ord), 2, '0')}"): text (
                  $month)[0..2] & " (" & $count & ")"
            else:
              text ($month)[0..2]
  result = baseLayout(ctx, "Calendar", vnode)
