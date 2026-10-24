# Privacy

The native app has no account, analytics SDK, telemetry endpoint or application network client. Building requires locally installed tools; the build scripts do not install packages or upload artifacts.

Preferences are stored by macOS under the public application's bundle identifier `local.catcompanion.opensource`. Copy and growth records are local files beneath that identifier's Application Support directory. The included `src/letter.txt` is a neutral example, embedded into builds as plain text. A custom letter must not be committed unless you intend it to be public.

The desktop app listens for interaction needed for hover and petting. It does not record or upload keystrokes, microphone, camera or browsing history. The browser prototype can use localStorage for prototype settings and is separate from the native app.

User-generated text, real save files, preferences, private reports, reference images, build products, credentials, development logs and earlier Git history are excluded from the initial public snapshot. `scripts/audit-public.py` checks the files eligible for distribution for common secret and personal-path patterns. Pattern checks cannot prove that arbitrary text or images contain no private information; review new content before committing it.
