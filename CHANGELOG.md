
## 0.5.0
  * Fixed an issue calculating the scale factor used in many of the functions. Now, correctly, uses the units_per_em instead of ascent-descent for the baseline.
  * Removed the serialization APIs. Scenic no longer needs them and how you serialize the data in not an opinion the package should have. Use MsgPack. Use :erlang.term_to_binary. Use Jason. This package shouldn't care.
  * Standardized the way options are passed in to functions. Some had option lists. Som had a kern parameter that was just a passed in boolean. This is all option lists now.
  * Add Specs for types and functions. Confirm Dialyzer passes.


##0.4.0
  * skipped. Going straight to 0.5.0 to have it align to the version of truetype_metrics that will depend on it

## 0.3.1

* Add the wrap function

## 0.3.0

* First public release