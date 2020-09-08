# KSSDiff

Swift utility to compare two texts and obtain a description of their differences

## Description

This package provides a library used to obtain a description of the differences between two texts. It 
provides both a simple `String` extension for when the default settings are sufficient, as well as a
slightly more complex API to handle the cases where the default settings are not good enough.

_Note:_ The underlying code is a Swift port of the Python3 code found at 
[google/diff-match-patch](https://github.com/google/diff-match-patch).

[API Documentation](https://www.kss.cc/apis/KSSDiff/docs/index.html)

## Module Availability

This package is currently available on _macOS_, _iOS_, and _Linux_. (Specifically it has been
tested on Ubuntu Linux.)

## What Has Changed In V2

There are no API changes in V2. All that has changed is the dependency on `KSSCore` has been
updated to the latest version, which is a non-back-compatible version. Hence this library must
also bump its version to mark that it is no longer binary back compatible.

## Originating Code

As mentioned above the underlying implementation is largely based on the python3 code of
diff-match-patch. We follow the python3 code fairly closely, but with the following changes:

1. We use `Substring` objects instead of a bunch of small `String` objects in order to reference
the changes back to the original two strings.
2. We have created a specific `Difference` struct to describe a single difference rather than 
returning unnamed tuples.
3. Since the substring approach reuses the existing memory, we do not implement the `diff_lineMode`
and its character munging optimization. This does seem to change the answers slightly for the
large speed test, but in an acceptable manner. (probably. We have logged a bug to look into
this more closely.)
4. Most of the comments found in the code are exactly cut and paste from the python code. This
was done to help navigate so that future changes made in the python code can be applied to
this code without too much difficulty.

## Efficiency

The initial port of the python3 code was far slower (orders of magnitude slower) than the python version.
This seemed to be primarily related to the fact that Swift does not allow random access into the 
characters of a string, but iterates through them taking the multi-character nature of the unicode
encodings into account. (Python also properly handles the multi-character unicode, but in a manner
that still allows random access into a string.)

A significant effort was put into optimizing this with the effect of getting it to the point where the
swift code is now slightly faster than the python code (14s to run the speed test compared to 17s for
the python version, on the same hardware). Most of the optimizations are centered around ensuring
that we don't iterate through the same portion of a string more than once. In some cases this is
done by caching positions, and in other cases, by deriving positions based on other nearby known
positions. Unfortunately these optimizations significantly reduce the readability of the code, so any 
changes made must be done with great care.
