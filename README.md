# tohray

[ತೊರೆ](https://kn.wiktionary.org/wiki/ತೊರೆ), pronounced "toh-ray" (with a dental 't' sound),
is a microblogging application to capture stream of thoughts inspired by [Linus Lee](https://thesephist.com)'s [Stream](https://stream.thesephist.com)

The word ತೊರೆ in [Kannada](https://en.wikipedia.org/wiki/Kannada) has multiple meanings, but most commonly
as rivulet, forego, divest; which are indeed appropriate description for the intent.

You can see this in action at <https://tohray.fly.dev>.

## Features

- Write new posts
- In markdown
- Edit posts
- Delete posts
- Click on the date to see posts written during that *month*.
- Supports multiple users, but I really wrote it for one user.
- You can allow users to sign up by giving them the `inviteCode`
- Export all the feeds from `/export` endpoint.
    - default format is JSON
    - append `?format=md` to export in markdown format ie., `/export?format=md`. The entries are returned with a File Seperator (ASCII 28) after each entry.
- Calendar view by month at `/calendar` to see all the posts belonging to a month.

## Non-Features

- There is no "user management".
- There is no "password reset".

## Technology Details

Linus wrote his [stream app](https://github.com/thesephist/stream) using a language he created himself - [Oaklang](https://oaklang.org).
I wanted an excuse to use Nim for something "useful", so I used Nim, and it was a great experience.

Nim is a fast, and friendly language that is statically typed, while looking like Python in Syntax.
It compiles the source code into C (or C++, or Javascript), which allows the programs written in it
to be very fast, small, and quite portable.

- Programming Language: [Nim](https://nim-lang.org)
- Framework: [Prologue](https://planety.github.io/prologue/), which in turn uses [Karax](https://github.com/karaxnim/karax).
- Database: SQLite
- CSS: [Terminal](https://terminalcss.xyz)
- Cloud: Tested on <https://fly.io>
- Editor: eh.. didn't know you cared, but it was written on [Zed](https://zed.dev) which has decent support
for editing Nim with `nimlangserver`.

## Programming Notes

- The `views.nim` file way too long, but I'm not ashamed of it. It's app I wrote for myself, and it
fits into myhead perfectly fine.
- The decision to compile secrets into the binary was made after realizing that managing secrets in
the environment, `.env` files, `consts.nim` .. multiple places is just busy work. Not how I would write
a "production" application.. but this is a "hobby" application. And, whatever makes me happy to keep
writing code will remain.

## Installation

- Clone this directory
- Have [nim](//nim-lang.org) installed on your computer
- copy `example-consts.nim` to `consts.nim` and **set the variables**
- NOTE: The config is compiled into the binary. There is no "config file"
- Compile the app with `$ nim compile toray.nim`
- Launch the program with `./tohray`, and the program will start on port `:8080` - <http://localhost:8080>
- Go to <http://localhost:8080/register> (not visible on the web page itself)
- Use the `inviteCode` you set in `consts.nim` along with your name and password
- Click on `Write` to start writing. I recomment writing a post with slug `about` so that the `about` link on the top nav actually goes to the about page.
- The data is stored in a `sqlite` databse given in the `consts.nim` file
- NOTE: if you want to see how the blog looks with some entries in it, you can run `sqlite3 tohray.db < test.sql` to see some `lorem ipsum` content.

## Installation on fly.io

I wrote this so that I can run it `fly.io`.  Study the `Dockerfile` and `fly.toml`.

Observe how I copy `fly-consts.nim` to `consts.nim` in the `Dockerfile`. This allows you to have a
local copy (on the computer) with the secrets etc, but will be compiled into the binary on deployment.

To create the volume where the database is stored (`/mnt/db` in `fly.toml`), you have to use this
command: `fly volumes create db -r atl`. Here, `atl` stands for Atlanta, where I launched the app.
The app and the volume should be in the same zone.

## Todo

- [x] Export all the posts in a JSON file (and markdown)
- [x] Add a calendar view
- [x] Edit Posts. ~~Don't hold your breath~~
- [x] Add calendar and export links
- [x] RSS Feed
- [ ] Deploy on other PaaS platforms like unicraft etc.
- [ ] Make a static build of this docker image. Currently, it is using a full sized Ubuntu Normal image. bleh.
