Simple CLI for kodi writte in in bash.

Currently it supports pausing (and resuming), stopping and seeking.

# Getting started

## Dependencies

* jq
* curl

## Completion

To enable bash completion, append [completion.sh](./completion.sh) to
`~/.bash_completion`

    cat completion.sh >> ~/.bash_completion

## Configuration

The configuration file is `~/.netrc.kodi`, it is supposed to contain a username
and password that can access the JsonRPC APIs. The format is what is specified
by `curl --netrc-file`.

    machine HOST login USERNAME password PASSWORD

# Examples

```
$ kodi pause
Paused
$ kodi pause
Playing
$ kodi backward
Skipped to 14:09
$ kodi forward
Skipped to 14:39
```
