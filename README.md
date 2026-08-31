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

Copy on the home page — the tagline, install commands, and the "What you
get" cards — lives in `[extra]` in `config.toml`, so it can be changed
without touching templates. Layout lives in `templates/index.html`.

## Layout

```
config.toml              site config + landing-page copy
content/_index.md        home page (renders via templates/index.html)
content/blog/            blog posts, one markdown file each
templates/base.html      shared shell: head, header, footer
templates/index.html     landing page
templates/blog.html      blog index
templates/post.html      single post
templates/taxonomy_*.html  tag pages
static/style.css         all styling
static/favicon.svg
```

## Deployment

`.github/workflows/deploy.yml` builds with Zola and publishes to GitHub
Pages on every push to `main`. Pages is configured with "GitHub Actions"
as the source, so there is no `gh-pages` branch to manage.
