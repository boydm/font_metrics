# FontMetrics

[![Build Status](https://travis-ci.org/boydm/font_metrics.svg?branch=master)](https://travis-ci.org/boydm/font_metrics)
[![Codecov](https://codecov.io/gh/boydm/font_metrics/branch/master/graph/badge.svg)](https://codecov.io/gh/boydm/font_metrics)


## Update
Version 0.5 has several major chagnes, including wrapping at word boudaries and, frankly,
fixes a bug when calculating the widths.

It also removes serialization and now just returns the struct. This library shouldn't
have an opinion on how you want to serialize it's data. I suggest you use something
like :erlang.term_to_binary to get it done. Scenic no longer needs this functionality
and that really pointed out how it shouldn't be here.


## Overview
This library works with pre-generated font metrics data to explore and calculate various
measurements of text in a given font and size.

For example, if you want to know how wide or tall a string of text will be when
it is rendered in a given font at a given size, then this can help you out.

This library is intended to be used with the [Scenic](https://hex.pm/packages/scenic)
framework, but doesn't depend on it, so it is usable elsewhere.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `font_metrics` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:font_metrics, "~> 0.5"}
  ]
end
```

## Generating Metrics

You will need to use another package to compile the font metrics data from a font.

This can be done with the truetype_metrics package. Look for it on hex... In the meantime, metrics data for both Roboto and RobotoMono can be found in the Scenic project.
