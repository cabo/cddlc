# CDDL conversion utilities

This little set of tools provides a number of command line utilities
for converting to and from [cddl][RFC8610].

[![0.0.1](https://badge.fury.io/rb/cddlc.svg)](http://badge.fury.io/rb/cddlc)

## Installation

`gem install cddlc`

## Formats

cddlc knows the following formats:

* .cddl: CDDL as defined in [RFC8610][]
* .cddlj: JSON form of CDDL (the YIN to the YANG)
* .cddly: The same JSON form, but serialized in YAML.

[RFC8610]: http://tools.ietf.org/html/rfc8610

These targets are identified by `-t cddl`, `-t json` (with `-t neat` invoking
a different prettyprinter), `-t yaml`.  These can be abbreviated (but
don't do that in scripts).

The current version only can transform from input CDDL to one of the
JSON/YAML formats of CDDL.

## Command line utilities

* `cddlc foo.cddl > foo.cddlj`
* `cddlc -tyaml foo.cddl > foo.cddly`
* `cddlc -ty foo.cddl > foo.cddly`

Output is to stdout, input from one or more files given as command line
arguments (use `-` for standard input).
