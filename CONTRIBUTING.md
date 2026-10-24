# Contributing

For a bug report, include macOS version, Apple Silicon or Intel, build version, concise reproduction steps, expected behavior and observed behavior. Remove personal letters, save files, account details and desktop content from attachments.

For changes, keep patches focused and run `zsh scripts/check-core.sh`. Changes to native behavior, artwork composition, storage or window lifecycle also require the full `zsh scripts/verify.sh` suite in a logged-in desktop session. Report skips and scene failures accurately. Do not relax visual or interaction assertions merely to obtain a passing result.

Keep the default desktop behavior calm: automatic speech and automatic grooming stay disabled, always-on-top is opt-in, and the cat remains on the current Space. Preserve user edits during storage migration. Avoid introducing network services, telemetry or recurring workers without a separate design discussion.

Code contributions are submitted under MIT. Artwork contributions require clear provenance and authority to use the documented artwork license. AI-assisted contributions are welcome when reviewed, tested and disclosed where relevant; do not include third-party confidential material or private prompts.
