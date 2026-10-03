# Async media callback lifetime regression

Run on macOS with Xcode command line tools and Python 3:

```sh
python3 Tests/AsyncMediaLifetime/run.py
```

The runner extracts the four production media callback bodies without rewriting
them and compiles them with the real `VLCEventsHandler` and
`VLCEventsLegacyConfiguration`, ARC, and Address Sanitizer. Checked media doubles
model the descriptor's refcount and unretained wrapper backlink. Their lookup
function rejects every descriptor lookup outside the originating callback, even
when an unrelated retain could hide the bug from ASan.

The 3,200 cases cover metadata (first), media replacement, subitems, attachments,
existing and newly materialized wrappers, null media, and dropped events after
the weak player target disappears. Each case releases the caller's descriptor,
wrapper, player and handler before draining the main queue. Checks prove delayed
main-thread delivery, wrapper retention until delivery, attachment copying, and
zero surviving media/descriptor instances after delivery or rejection.

Negative control:

```sh
git show 6cbc4e7b:Sources/Playback/VLCMediaPlayer.m > /tmp/VLCMediaPlayer-before.m
python3 Tests/AsyncMediaLifetime/run.py --source /tmp/VLCMediaPlayer-before.m
```

The unpatched code must fail with `Raw descriptor looked up after callback return`.
This harness verifies the callback/dispatch ownership contract; it does not run
libVLC decoders, real wrapper initialization, or physical-device playback.
