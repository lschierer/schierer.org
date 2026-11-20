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

## Deployment (AWS Lightsail)

The site runs on a Lightsail container service (`schierer-org`, nano power,
one node, about $7/month) in us-east-2 with the `personal` AWS profile.
Lightsail handles TLS, health checks, and restarting the container.

Requires `lightsailctl` for image pushes: `brew install aws/tap/lightsailctl`.

```
mise run aws-setup     # once: container service + certificate (+ Route 53 validation CNAMEs)
mise run deploy        # every change: build, push, deploy, wait, smoke test
mise run dns-test      # once: static.schierer.org -> Lightsail, for testing
mise run dns-cutover   # once: schierer.org and www.schierer.org -> Lightsail
```

A failed deployment leaves the previous one serving.
