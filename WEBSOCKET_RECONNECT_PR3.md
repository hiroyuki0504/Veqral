# WebSocket Reconnect PR3

## Summary

- Remote run streams now reconnect with exponential backoff instead of stopping after two fixed retries.
- Before each reconnect, the client fetches the run snapshot and replayed logs, deduplicates already-seen log events, and only calls the existing resume API for non-terminal remote states.
- The connection strip now shows active stream states: connecting, streaming, reconnecting, or disconnected.

## Acceptance Notes

- Temporary WebSocket loss should recover without losing run logs because the Host already replays stored events on subscription and the client deduplicates them.
- Completed, failed, and cancelled remote runs are treated as terminal before calling resume, so reconnect cannot accidentally restart a completed run.
- Manual device smoke still needed: start a long remote run, interrupt network briefly, then confirm the log strip moves through reconnecting and the run log resumes.
