import {
  decode as referenceDecode,
  encode as referenceEncode,
} from "@msgpack/msgpack";
import { describe, expect, it } from "vitest";

import { decode, encode } from "./msgpack";

// A batch packed by the server's own MessagePack factory, which is where the
// blob extension comes from. Regenerate it by packing the value in
// `rubyFixtureValue` with Mayu::Server::EventStream::MsgPackWrapper.
const RUBY_FIXTURE = [
  "9a92aa496e697469616c697a6583a26964a27630a46e616d65a923646f63756d656e74a86368",
  "696c6472656e9182a26964a27631a46e616d65a448544d4c93ae53657454657874436f6e7465",
  "6e74a27632b6536dc3b67267c3a573626f726420e29c9320f09f90ac92a4506f6e67cb40934a",
  "0000000000dc0015a74e756d62657273007fcc80ccffcd0100cdffffce00010000ceffffffff",
  "cf0000000100000000cf001fffffffffffffffe0d0dfd080d1ff7fd18000d2ffff7fffd28000",
  "0000d3ffffffff7fffffffd3ffe000000000000196a75363616c617273c0c3c2cb3ff8000000",
  "000000cbbfd000000000000092a642696e617279c403ff000193a44c6f6e67d9287878787878",
  "7878787878787878787878787878787878787878787878787878787878787878787878da012c",
  "7979797979797979797979797979797979797979797979797979797979797979797979797979",
  "7979797979797979797979797979797979797979797979797979797979797979797979797979",
  "7979797979797979797979797979797979797979797979797979797979797979797979797979",
  "7979797979797979797979797979797979797979797979797979797979797979797979797979",
  "7979797979797979797979797979797979797979797979797979797979797979797979797979",
  "7979797979797979797979797979797979797979797979797979797979797979797979797979",
  "7979797979797979797979797979797979797979797979797979797979797979797979797979",
  "7979797979797979797979797979797979797979797979797979797979797979797992a54172",
  "726179dc00140102030405060708090a0b0c0d0e0f101112131492a34d6170de0014a26b3101",
  "a26b3202a26b3303a26b3404a26b3505a26b3606a26b3707a26b3808a26b3909a36b31300aa3",
  "6b31310ba36b31320ca36b31330da36b31340ea36b31350fa36b313610a36b313711a36b3138",
  "12a36b313913a36b32301492a85472616e73666572c70f01656e637279707465640073746174",
  "65",
].join("");

// What a callback event with telemetry looks like when Ruby packs it.
const RUBY_EVENT =
  "96a843616c6c6261636bcb402900000000000083a76261746368657301a8636f6d6d616e6473" +
  "02ab6475726174696f6e5f6d73cb3fe0000000000000a86c697374656e657282a474797065a5" +
  "636c69636ba664657461696c9501ffc0c3a2c3a5a137";

function fromHex(hex: string) {
  return new Uint8Array(hex.match(/../g)!.map((byte) => parseInt(byte, 16)));
}

function toHex(bytes: Uint8Array) {
  return Array.from(bytes, (byte) => byte.toString(16).padStart(2, "0")).join(
    "",
  );
}

// A small deterministic generator, so a failure can be reproduced.
function random(seed: number) {
  let state = seed;
  return () => {
    state = (state * 1664525 + 1013904223) >>> 0;
    return state / 0x100000000;
  };
}

const NUMBERS = [
  0,
  1,
  127,
  128,
  255,
  256,
  65535,
  65536,
  4294967295,
  4294967296,
  Number.MAX_SAFE_INTEGER,
  -1,
  -32,
  -33,
  -128,
  -129,
  -32768,
  -32769,
  -2147483648,
  -2147483649,
  Number.MIN_SAFE_INTEGER,
  0.5,
  -0.5,
  1e300,
  1234.5678,
  Infinity,
  -Infinity,
];

const STRINGS = [
  "",
  "a",
  "listener",
  "Smörgåsbord ✓ 🐬",
  "x".repeat(31),
  "x".repeat(32),
  "x".repeat(255),
  "x".repeat(256),
  "é".repeat(200),
];

function randomValue(next: () => number, depth = 0): unknown {
  const kind = Math.floor(next() * (depth > 3 ? 5 : 7));

  switch (kind) {
    case 0:
      return null;
    case 1:
      return next() < 0.5;
    case 2:
      return NUMBERS[Math.floor(next() * NUMBERS.length)];
    case 3:
      return Math.floor((next() - 0.5) * 2 ** Math.floor(next() * 54));
    case 4:
      return STRINGS[Math.floor(next() * STRINGS.length)];
    case 5:
      return Array.from({ length: Math.floor(next() * 20) }, () =>
        randomValue(next, depth + 1),
      );
    default:
      return Object.fromEntries(
        Array.from({ length: Math.floor(next() * 20) }, (_, index) => [
          `key${index}`,
          randomValue(next, depth + 1),
        ]),
      );
  }
}

describe("msgpack", () => {
  it("decodes a batch packed by Ruby", async () => {
    const batch = decode(fromHex(RUBY_FIXTURE)) as unknown[][];
    const transfer = batch.pop()!;

    expect(batch).toEqual([
      [
        "Initialize",
        {
          id: "v0",
          name: "#document",
          children: [{ id: "v1", name: "HTML" }],
        },
      ],
      ["SetTextContent", "v2", "Smörgåsbord ✓ 🐬"],
      ["Pong", 1234.5],
      [
        "Numbers",
        0,
        127,
        128,
        255,
        256,
        65535,
        65536,
        4294967295,
        4294967296,
        9007199254740991,
        -1,
        -32,
        -33,
        -128,
        -129,
        -32768,
        -32769,
        -2147483648,
        -2147483649,
        -9007199254740991,
      ],
      ["Scalars", null, true, false, 1.5, -0.25],
      ["Binary", new Uint8Array([0xff, 0x00, 0x01])],
      ["Long", "x".repeat(40), "y".repeat(300)],
      ["Array", Array.from({ length: 20 }, (_, index) => index + 1)],
      [
        "Map",
        Object.fromEntries(
          Array.from({ length: 20 }, (_, index) => [
            `k${index + 1}`,
            index + 1,
          ]),
        ),
      ],
    ]);

    expect(transfer[0]).toBe("Transfer");
    const blob = transfer[1] as Blob;
    expect(blob).toBeInstanceOf(Blob);
    expect(blob.type).toBe("application/vnd.mayu.session");
    expect(toHex(new Uint8Array(await blob.arrayBuffer()))).toBe(
      toHex(new TextEncoder().encode("encrypted\x00state")),
    );
  });

  it("encodes an event to the bytes Ruby packs it to", () => {
    const event = [
      "Callback",
      12.5,
      { batches: 1, commands: 2, duration_ms: 0.5 },
      "listener",
      { type: "click", detail: [1, -1, null, true, "å"] },
      "7",
    ];

    expect(toHex(encode(event))).toBe(RUBY_EVENT);
    expect(decode(fromHex(RUBY_EVENT))).toEqual(event);
  });

  it("encodes to the same bytes as the reference implementation", () => {
    const next = random(1);

    for (let i = 0; i < 2_000; i++) {
      const value = randomValue(next);
      expect(toHex(encode(value))).toBe(toHex(referenceEncode(value)));
    }
  });

  it("decodes what the reference implementation encodes", () => {
    const next = random(2);

    for (let i = 0; i < 2_000; i++) {
      const value = randomValue(next);
      const bytes = referenceEncode(value);
      expect(decode(bytes)).toEqual(referenceDecode(bytes));
    }
  });

  it("round-trips strings and collections of every length form", () => {
    const values = [
      "x".repeat(70_000),
      Array.from({ length: 70_000 }, (_, index) => index),
      Object.fromEntries(
        Array.from({ length: 70_000 }, (_, index) => [`k${index}`, index]),
      ),
      new Uint8Array(70_000).fill(7),
    ];

    for (const value of values) {
      const bytes = encode(value);
      expect(toHex(bytes)).toBe(toHex(referenceEncode(value)));
      expect(decode(bytes)).toEqual(value);
    }
  });

  it("encodes undefined as nil, as the reference implementation does", () => {
    expect(toHex(encode([undefined, { a: undefined }]))).toBe(
      toHex(referenceEncode([undefined, { a: undefined }])),
    );
  });

  it("decodes from a view into a larger buffer", () => {
    const encoded = encode(["Pong", 1]);
    const padded = new Uint8Array(encoded.length + 8);
    padded.set(encoded, 4);

    expect(decode(padded.subarray(4, 4 + encoded.length))).toEqual(["Pong", 1]);
  });

  it("rejects input that is cut off, or longer than one value", () => {
    const encoded = encode(["Pong", { a: "text" }]);

    for (let length = 0; length < encoded.length; length++) {
      expect(() => decode(encoded.subarray(0, length))).toThrow(/truncated/);
    }
    expect(() => decode(new Uint8Array([...encoded, 0xc0]))).toThrow(
      /trailing/,
    );
  });

  it("rejects what it does not understand", () => {
    expect(() => decode(new Uint8Array([0xc1]))).toThrow(/unknown type/);
    // A fixext1 of type 2.
    expect(() => decode(new Uint8Array([0xd4, 0x02, 0x00]))).toThrow(
      /unknown extension/,
    );
    expect(() => decode(referenceEncode({ __proto__: 1 }))).not.toThrow();
    expect(() =>
      decode(
        new Uint8Array([
          0x81,
          0xa9,
          ...new TextEncoder().encode("__proto__"),
          0x01,
        ]),
      ),
    ).toThrow(/__proto__/);
    expect(() => encode(() => undefined)).toThrow(/can't encode/);
    expect(() => encode(Symbol("x"))).toThrow(/can't encode/);
  });

  it("refuses to encode a value that contains itself", () => {
    const cyclic: unknown[] = [];
    cyclic.push(cyclic);
    expect(() => encode(cyclic)).toThrow(/too deep/);
  });

  // Every level of the DOM is two levels of an id tree.
  it("decodes a tree as deep as a deep page", () => {
    const depth = 2_000;
    const bytes = new Uint8Array(depth + 1).fill(0x91);
    bytes[depth] = 0xc0;

    let value = decode(bytes);
    for (let i = 0; i < depth; i++) value = (value as unknown[])[0];

    expect(value).toBeNull();
  });
});
