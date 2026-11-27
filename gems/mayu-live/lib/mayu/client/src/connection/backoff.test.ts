import { describe, expect, it } from "vitest";

import Backoff from "./backoff";

describe("Backoff", () => {
  it("starts at the first attempt", () => {
    expect(new Backoff().attempt).toBe(1);
  });

  it("waits a second longer after each failure in a row, up to ten", () => {
    const backoff = new Backoff();
    const delays = [];

    for (let i = 0; i < 12; i++) {
      backoff.failed();
      delays.push(backoff.delay);
    }

    expect(delays).toEqual([
      1000, 2000, 3000, 4000, 5000, 6000, 7000, 8000, 9000, 10_000, 10_000,
      10_000,
    ]);
    expect(backoff.attempt).toBe(13);
  });

  it("starts over once a stream has delivered a batch", () => {
    const backoff = new Backoff();
    backoff.failed();
    backoff.failed();

    backoff.streamWorked();
    expect(backoff.attempt).toBe(1);

    backoff.failed();
    expect(backoff.delay).toBe(1000);
  });

  it("reconnects at once after the first clean ending, then backs off", () => {
    const backoff = new Backoff();

    expect(backoff.ended()).toBe(0);
    expect(backoff.attempt).toBe(1);
    expect(backoff.ended()).toBe(1000);
    expect(backoff.attempt).toBe(2);
    expect(backoff.ended()).toBe(2000);
    expect(backoff.attempt).toBe(3);
  });

  it("keeps backing off a server that delivers a batch and then closes", () => {
    const backoff = new Backoff();

    backoff.streamWorked();
    expect(backoff.ended()).toBe(0);
    backoff.streamWorked();
    expect(backoff.ended()).toBe(1000);
    backoff.streamWorked();
    expect(backoff.ended()).toBe(2000);
  });

  it("forgets clean endings after a failure", () => {
    const backoff = new Backoff();
    backoff.ended();
    backoff.ended();

    backoff.failed();
    expect(backoff.delay).toBe(1000);
    expect(backoff.attempt).toBe(2);
    expect(backoff.ended()).toBe(0);
  });

  it("connects to a new session without counting earlier failures", () => {
    const backoff = new Backoff();
    backoff.failed();
    backoff.failed();

    backoff.sessionReset();
    expect(backoff.attempt).toBe(1);
  });
});
