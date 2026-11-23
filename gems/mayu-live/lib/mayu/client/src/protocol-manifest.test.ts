import { describe, expect, it } from "vitest";

import manifest from "../protocol.json";
import { RESET_SESSION_ERROR_CODES } from "./connection/recovery";
import { ELEMENT_METHODS } from "./dom/element-calls";
import { CONTINUOUS_EVENTS } from "./features/callbacks";
import type { CommandName } from "./protocol/commands";
import { STREAM_MIME_TYPE } from "./protocol/constants";
import type { ClientEvent } from "./protocol/events";

// protocol.json describes the wire protocol once. This test holds the
// browser runtime to it, and lib/mayu/protocol.test.rb holds the server to
// it, so the two sides can't drift apart unnoticed.

// The compiler rejects this record unless it names every command the client
// has a type for, and the dispatcher's constructor does not compile unless
// each of them has a handler.
const COMMAND_NAMES: Record<CommandName, true> = {
  Initialize: true,
  CreateTree: true,
  ReplaceChildren: true,
  RemoveNode: true,
  SetAttribute: true,
  RemoveAttribute: true,
  AddClass: true,
  RemoveClass: true,
  SetListener: true,
  RemoveListener: true,
  SetCSSProperty: true,
  RemoveCSSProperty: true,
  SetTextContent: true,
  Transfer: true,
  TransferFailed: true,
  Pong: true,
  ReloadSucceeded: true,
  NavigationComplete: true,
  NavigationFailed: true,
  DocumentNavigation: true,
  CallbackComplete: true,
  CallbackFailed: true,
  RegisterCustomElement: true,
  BrowserAction: true,
  ElementCall: true,
  InspectResult: true,
  RenderError: true,
  ViewTransition: true,
};

// The compiler rejects this record unless it names every client event.
const EVENT_NAMES: Record<ClientEvent[0], true> = {
  Callback: true,
  Navigate: true,
  Ping: true,
  Visibility: true,
  Inspect: true,
};

// Raised by the client itself, when a TransferFailed command arrives.
const CLIENT_ERROR_CODES = ["TRANSFER_FAILED"];

describe("protocol manifest", () => {
  it("has the stream content type", () => {
    expect(STREAM_MIME_TYPE).toBe(manifest.streamContentType);
  });

  it("knows every command", () => {
    expect(Object.keys(COMMAND_NAMES).sort()).toEqual(
      Object.keys(manifest.commands).sort(),
    );
  });

  it("sends every client event", () => {
    expect(Object.keys(EVENT_NAMES).sort()).toEqual(
      [...manifest.events].sort(),
    );
  });

  it("resets the session on the error codes marked for it", () => {
    const reset = Object.entries(manifest.errorCodes)
      .filter(([, { reset }]) => reset)
      .map(([code]) => code);

    expect([...RESET_SESSION_ERROR_CODES].sort()).toEqual(
      [...reset, ...CLIENT_ERROR_CODES].sort(),
    );
  });

  it("throttles the continuous events", () => {
    expect([...CONTINUOUS_EVENTS].sort()).toEqual(
      [...manifest.continuousEvents].sort(),
    );
  });

  it("maps every element method", () => {
    expect(Object.keys(ELEMENT_METHODS).sort()).toEqual(
      [...manifest.elementMethods].sort(),
    );
  });
});
