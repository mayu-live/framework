export const STREAM_MIME_TYPE = "application/vnd.mayu.event-stream";

export const SESSION_MIME_TYPE = "application/vnd.mayu.session";
export const SESSION_PATH = "/.mayu/session";
// The version of the wire protocol this runtime speaks, sent with every
// session request. The server answers in kind. A page whose runtime and
// server disagree reloads, which gets it the runtime that server serves.
export const PROTOCOL_HEADER = "mayu-protocol";
export const PROTOCOL_VERSION = "2";
// Names the last batch a reconnecting page applied.
export const LAST_BATCH_HEADER = "mayu-last-batch";

export const PING_INTERVAL = 4_000;

// Continuous events like scroll and pointermove are sent at most this often
// per listener.
export const CONTINUOUS_EVENT_INTERVAL_MS = 1_000 / 30;

// Avoid flashing the navigation progress bar for routes that finish quickly.
export const NAVIGATION_PROGRESS_DELAY = 120;
