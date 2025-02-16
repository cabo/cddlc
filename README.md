# CDDL conversion utilities

This little set of tools provides a number of command line utilities
for converting to and from [CDDL][RFC8610].

In addition, the 0.4 releases contain a growing preview of the new
capabilities of the `cddlc` tool that will replace the classic `cddl`
tool, see below at the end of the README.

[![0.0.2](https://badge.fury.io/rb/cddlc.svg)](http://badge.fury.io/rb/cddlc)

## Installation

`gem install cddlc`

## Formats

cddlc knows the following formats:

* .cddl: CDDL as defined in [RFC8610][]
* .cddlj: JSON form of CDDL (the YIN to the YANG)
* .cddly: The same JSON form, but serialized in YAML.

[RFC8610]: http://tools.ietf.org/html/rfc8610

These targets are identified by `-t cddl`, `-t json` (or `-t neat`
naming the JSON prettyprinter), `-t yaml`.  These can be abbreviated
(but don't do that in scripts).

With `-t enum`, cddlc generates C-style enumeration type declarations
from integer keys used in a map.

Apart from creating enum declarations, the current version only can
transform from input CDDL to one of the JSON/YAML formats of CDDL.

## Command line utilities

* `cddlc foo.cddl > foo.cddlj`
* `cddlc -tyaml foo.cddl > foo.cddly`
* `cddlc -ty foo.cddl > foo.cddly`

Output is to stdout, input from one or more files given as command line
arguments (use `-` for standard input).

## Collection of CDDL from RFCs

`cddlc` comes with a curated selection of CDDL rules from published RFCs.

New in 0.4.1: rfc9597.cddl rfc9528.cddl rfc9526.cddl rfc9431.cddl
rfc9360.cddl rfc9594-sign_info_entry-with-a-gene.cddl
rfc9594-example-extended-scope-text.cddl
rfc9594-example-extended-scope-aif.cddl rfc9594-get_creds.cddl
rfc9594-error-handling.cddl rfc9594-sign_info-parameter.cddl
rfc9594-example-scope-text.cddl rfc9594-example-scope-aif.cddl

These files can be used with import/include statements in CDDL models
or directly from the command line with -i/-I arguments.

Get a full list of files included via:

```
$ gem contents cddlc | sed -n 's,.*/data/,,p'
```

...or, to get the full filenames:

```
$ gem contents cddlc | grep /data/
```

## 0.4.x previews

The 0.4.x revisions contain a growing preview of the new cddlc CDDL
full validator implementation.

    Usage: cddlc [options] [-e cddl | file.cddl... | -]
        ...
        -c, --cbor-validate=FILE   Validate CBOR file against CDDL grammar
        -j, --json-validate=FILE   Validate JSON file against CDDL grammar
        -d, --diag-validate=FILE   Validate EDN file against CDDL grammar
        -eCDDL                     CDDL model on command line

E.g.,

    $ echo '"ab"' | cddlc test/21-cat.cddl --diag-validate=-
    $ echo '"foo"' | cddlc test/21-cat.cddl -d-


(`-` stands for standard input, here in EDN CBOR diagnostic notation,
produced via `echo`, which removes one layer of quotes on the command
line).

Limitations (i.e., why this is a preview at this very moment):

* Only a small set of control operators have been ported over: `.cat`,
  `.det`, `.plus`, `.size`, `.bits`, `.default`, `.feature`,
  `.regexp`, `.abnf`, `.abnfb`.
* CDDL groups have not been ported over yet.

The new validator collects information during validation.
This collected information will be made available via a number of
mechanisms, which are also implementation TODOs at this time:

  * First the CBOR diagnostic notation pretty printer from the classic
    `cddl` tool will be ported and completed.
  * The information collection will also enable better error messages.
    The error message reporter will format them in a way that aids
    finding the reason for the lack of a match.
    (Right now the error messages are a YAML dump of the collected
    information.  Note that the format of the collected information is
    subject to change.)

A port of the `cddl` generator is next, at which point `cddlc` will be
fully subsuming the classic `cddl` tool.
