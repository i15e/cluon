# Cluon

## What

A tiny get-your-public-IPv4 [redbean](https://redbean.dev/) web service. Even
its largest response should fit in a single packet.

MIT licensed.

## Why

A fun weekend hack to both learn `redbean` and get the sort of ultra-simple and
fast public-IP web service that I wanted to have online.

## How

Have Docker installed and `make run`.

| URL Component | Explanation |
| ------------- | ----------- |
| `/` | First content negotiates based on the agent's `Accept` header. If no matching content type is found (e.g., if it's set to `*/*`), then CLI agent strings are searched for - if one is found the output will be set to the plain-text (`/txt`) mode. |
| `/html`, `/json`, `/txt`, `/lua`, `/env` | The five output content modes. |
| `?k=[key name]` | Add the `k` `GET` argument to change the default `ip`/`IP` key in the `json`, `lua`, and `env` output types to the one specified. |

A note on the HTML content: yes, it's valid HTML5 markup and passes the W3C validator!

## Cluon?

In networking circles a bogon is an IP address that is non-routable on the
public internet and should never be seen entering your WAN interfaces. In more
general terms the opposite of a bogon is a cluon. As an internet-facing service
this should only be serving up cluons.
