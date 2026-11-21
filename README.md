# llmmanorg.github.io

Source for <https://llmmanorg.github.io> — the website and blog for
[llmman](https://github.com/llmmanorg/llmman).

Built with [Zola](https://www.getzola.org). No Node, no lockfile: one
static binary.

## Local preview

Install Zola (`brew install zola`, `cargo install zola`, or a
[release binary](https://github.com/getzola/zola/releases)), then:

```sh
zola serve
```

That serves the site on <http://127.0.0.1:1111> and live-reloads on
change. `zola build` writes the site to `public/`.

## Writing a post

Create `content/blog/my-post.md`:

```md
+++
title = "My post"
description = "One or two sentences. Used for the post list, the feed and social previews."
date = 2026-09-01

[taxonomies]
tags = ["release"]
+++

Intro paragraph, shown as the summary on list pages.

<!-- more -->

The rest of the post.
```

Notes:

- `date` must be a bare `YYYY-MM-DD` (no quotes). Posts sort newest
  first.
- A post with a future date is not built unless you pass
  `zola build --drafts`, so it is a usable way to stage something.
- `<!-- more -->` marks the summary cut-off.
- Filename becomes the URL: `content/blog/my-post.md` →
  `/blog/my-post/`. Renaming it breaks existing links.
- Tags generate `/tags/<tag>/` index pages automatically.

## Editing the landing page

The home page (`templates/index.html`) is a single-screen hero: logo,
tagline, subtitle, hero command, install tabs and two buttons. All copy
lives in `[extra]` in `config.toml`:

- `tagline`, `subtitle`, `hero_cmd`
- `repo_url`, `repo_name`, `models_url`
- `[[extra.install]]`: `label` and `cmd` per install tab

The home page must fit with no scrollbars. `body.home` clips overflow
only when the viewport is tall enough (`min-height: 35rem`, `50rem` on
narrow phones); shorter windows scroll.

The hero logo is `static/llmman-mark.png`: the manatee from the
[org logo](https://github.com/llmmanorg), background removed so it sits
on the dark page. The wordmark underneath it was dropped, since it is
dark teal (unreadable on this background) and redundant next to the
site header.

The header (`templates/base.html`) is the same on every page: logo and
wordmark, then Models, Blog and a GitHub icon link.

## Layout

```
config.toml              site config + all landing-page copy
content/_index.md        home page (renders via templates/index.html)
content/blog/            blog posts, one markdown file each
templates/base.html      shared shell: head, header, footer, inline JS
templates/index.html     home page: single-screen hero
templates/pill.html      rounded command box with Copy button (included)
templates/blog.html      blog index
templates/post.html      single post
templates/taxonomy_*.html  tag pages
static/style.css         all styling
static/llmman-mark.png   hero logo (manatee, transparent)
static/favicon.png       also the small mark in the header
static/apple-touch-icon.png
static/install.sh        served at /install.sh (curl | sh)
static/install.ps1       served at /install.ps1 (irm | iex)
```

## Deployment

`.github/workflows/deploy.yml` builds with Zola and publishes to GitHub
Pages on every push to `main`. Pages is configured with "GitHub Actions"
as the source, so there is no `gh-pages` branch to manage.
