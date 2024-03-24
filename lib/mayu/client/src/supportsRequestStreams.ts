function supportsRequestStreams() {
  // https://developer.chrome.com/articles/fetch-streaming-requests/#feature-detection
  let duplexAccessed = false;

  const hasContentType = new Request("", {
    body: new ReadableStream(),
    method: "POST",
    get duplex() {
      duplexAccessed = true;
      return "half";
    },
  } as any).headers.has("Content-Type");

  return duplexAccessed && !hasContentType;
}

export default supportsRequestStreams();
