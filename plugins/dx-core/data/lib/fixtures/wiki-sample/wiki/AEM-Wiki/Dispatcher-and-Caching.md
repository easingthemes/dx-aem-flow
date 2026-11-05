# Dispatcher and Caching

## Flush rules

Activating a page triggers a flush agent on each publish instance. The dispatcher drops the cached HTML for that path and its parent so navigation updates too.

## Stale content

If an author reports old content after activation, check the flush agent queue first, then the CDN TTL. Do not purge the whole CDN; request a path-based purge.
