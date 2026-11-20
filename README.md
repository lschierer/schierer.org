# schierer.org

Static family home pages for schierer.org, served by nginx in a container.

- `content/archives/<user>.tar.gz`: archived home directories, served at `/~<user>/`.
  The build strips PHP and other server-side files; nothing here is executed.
- `content/ann/poems/`: Ann's poems, served at `/~ann/`. The index pages are
  generated at build time from `templates/ann-index.html`.
- `site/`: hand-written root pages.
- `container/`: the Containerfile and nginx config. `/~luke/*` redirects to
  `https://luke.schierer.org/*`. Google Analytics is injected by nginx.

## Usage

```
mise run serve    # build the image and serve it on http://127.0.0.1:8088
mise run build    # just assemble ./dist without a container
```

The whole build happens inside the container's build stage, so the only local
requirement is podman (or docker).
