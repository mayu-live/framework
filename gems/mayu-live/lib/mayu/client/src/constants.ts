export const STREAM_MIME_TYPE = "application/vnd.mayu.event-stream";
export const STREAM_CONTENT_ENCODING = "deflate-raw";

export const SESSION_MIME_TYPE = "application/vnd.mayu.session";
export const SESSION_PATH = "/.mayu/session";

export const PING_INTERVAL = 4_000;

// Continuous events like scroll and pointermove are sent at most this often
// per listener.
export const CONTINUOUS_EVENT_INTERVAL_MS = 1_000 / 30;

// Avoid flashing the navigation progress bar for routes that finish quickly.
export const NAVIGATION_PROGRESS_DELAY = 120;
