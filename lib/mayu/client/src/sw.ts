const SESSION_IDS = new Map<string, string>();

type RecentlyClosedInfo = {
  sessionId: string,
  clientId: string,
  time: number,
}

let RECENTLY_CLOSED: RecentlyClosedInfo | null = null

addEventListener("activate", (event: any) => {
  console.log("ACTIVATGE ASSSDASDASD");
  event.waitUntil(
    (async function () {
      if (self.registration.navigationPreload) {
        await self.registration.navigationPreload.enable();
      }
    })()
  );
});

addEventListener("install", (e) => {
  console.log("[Service Worker] Install");
});

addEventListener("fetch", (event) => {
  const request = event.request as Request;

  if ((request.mode as any) !== "navigate") return;

  // TODO: Fix the resume endpoint before enabling this...
  // also maybe make sure it doesn't behave weird...
  // could get he active clients from the request and check
  // that the id is not there or something...
  // There should be a better way to get the id of the closing client.
  // There would have been if this was supported:
  // https://developer.mozilla.org/en-US/docs/Web/API/FetchEvent/replacesClientId
  // const sessionId = RECENTLY_CLOSED_SESSION_ID;

  const recentlyClosed = RECENTLY_CLOSED;

  if (!recentlyClosed) return

  event.respondWith(tryToReuseSessionId(event, recentlyClosed))
});

async function tryToReuseSessionId(event: FetchEvent, recentlyClosed: RecentlyClosedInfo) {
  const request = event.request
  const clientIds = Array.from(await clients.matchAll({type: 'window'}), (client: WindowClient) => client.id)

  if (clientIds.includes(recentlyClosed.clientId)) {
    return request
  }

  const url = new URL(request.url)

  if (url.pathname.startsWith('/__mayu/')) {
    return request
  }

  const location = `/__mayu/resume/${recentlyClosed.sessionId}/?path=${encodeURIComponent(request.url)}`

  return fetch(location, { headers: request.headers })
  /*Request
  return new Response(new Blob(), {
    status: 302,
    statusText: 'Resuming session',
    headers: { location },
  });
  */
}

addEventListener("message", (event) => {
  const data = event.data

  switch (data.type) {
    case 'sessionId': {
      const sourceId = (event.source as any).id
      const sessionId = event.data.sessionId;
      console.log('Assigning source id', sourceId, 'to session id', sessionId)
      SESSION_IDS.set(sourceId, sessionId)
      break;
    }
    case 'closeWindow': {
      RECENTLY_CLOSED = {
        sessionId: event.data.sessionId,
        clientId: (event.source as any).id,
        time: new Date().getTime(),
      }
      break;
    }
    default: {
      console.error(`Unhandled event`, data.type)
    }
  }
});
