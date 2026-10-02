# FirmwareDroid Wiki

This repository contains the public website and usage documentation for
[FirmwareDroid (FMD)](https://github.com/FirmwareDroid/FirmwareDroid), a research framework for extracting and
analyzing pre-installed Android applications from firmware images.

The site combines an ICSE Tool Demo-oriented overview with detailed guides for installing, operating, querying,
extending, and maintaining FMD. It is built with Jekyll and deployed to
[firmwaredroid.github.io](https://firmwaredroid.github.io/) through GitHub Pages.

## Local development

Install the Ruby dependencies and start Jekyll:

```bash
bundle install
bundle exec jekyll serve
```

The local site is then available at `http://127.0.0.1:4000/`.

Run a production build before submitting changes:

```bash
JEKYLL_ENV=production bundle exec jekyll build
```

Documentation articles live in `_posts`. The showcase homepage is `index.html`, and the documentation catalog is
`documentation.md`. Shared styling and behavior are located in `assets/css/fmd.css` and `assets/js/fmd.js`.

## Adding documentation posts

Documentation guides are managed dynamically by adding Markdown files to the `_posts/` directory (e.g. `_posts/YYYY-MM-DD-title.md`). The display position and group placement in the documentation catalog ([documentation.md](file:///Users/tom/Documents/02_INIT/02_PhD/02_Research/02_FirmwareDroid/firmwaredroid.github.io/documentation.md)) and homepage are driven by front-matter metadata:

```yaml
---
title: Guide Title
description: Brief summary of the article.
order: 5              # Display position in the documentation catalog (or 'position: 5')
group: extend         # Catalog group: 'start', 'understand', or 'extend'
icon: fas fa-book     # FontAwesome icon class (e.g. 'fas fa-rocket', 'fas fa-code')
label: Tutorial       # Badge label (defaults to post category or 'Guide')
featured: false       # Optional boolean to highlight the card
---
```

When a new post is added with front matter, it is automatically cataloged in the specified group at the given order without modifying `documentation.md`.

## Contributing

Corrections and improvements are welcome through pull requests or issues. When changing a page, preserve existing
post permalinks because published documentation links may depend on them.

## License

The website source is distributed under the repository's [MIT License](LICENSE). FirmwareDroid itself is licensed
under [GNU GPL v3.0](https://github.com/FirmwareDroid/FirmwareDroid/blob/main/LICENSE.md).
