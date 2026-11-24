// A MessagePack codec for exactly what the protocol uses, which is a
// fraction of the size of a general-purpose library. msgpack.test.ts checks
// it against @msgpack/msgpack and against bytes packed by Ruby.
//
// Decoding handles every MessagePack type but the extensions. Maps become
// plain objects, binary strings become a Uint8Array, and extension type 1
// becomes a Blob holding a transferred session; any other extension throws. Encoding handles null, booleans, numbers, strings,
// arrays, plain objects and byte arrays, which is what an event can hold.

import { SESSION_MIME_TYPE } from "./constants";

const BLOB_EXTENSION = 1;
// How deep an event may nest. An event is a few levels deep, so anything
// beyond this is a value that contains itself.
const MAX_ENCODE_DEPTH = 100;

const textDecoder = new TextDecoder();
const textEncoder = new TextEncoder();

export function decode(bytes: Uint8Array): unknown {
  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  let offset = 0;

  // Returns the offset of the next `size` bytes and steps past them.
  function take(size: number) {
    const start = offset;
    offset += size;
    if (offset > bytes.length) throw new Error("MessagePack: truncated");
    return start;
  }

  function readLength(size: number) {
    const start = take(size);
    if (size === 1) return view.getUint8(start);
    if (size === 2) return view.getUint16(start);
    return view.getUint32(start);
  }

  function readString(length: number) {
    const start = take(length);
    return textDecoder.decode(bytes.subarray(start, start + length));
  }

  function readBinary(length: number) {
    const start = take(length);
    return bytes.slice(start, start + length);
  }

  function readArray(length: number) {
    const array = new Array<unknown>(length);
    for (let i = 0; i < length; i++) array[i] = read();
    return array;
  }

  function readMap(length: number) {
    const map: Record<string, unknown> = {};
    for (let i = 0; i < length; i++) {
      const key = read();
      if (typeof key !== "string" && typeof key !== "number") {
        throw new Error("MessagePack: unsupported map key");
      }
      if (key === "__proto__") {
        throw new Error("MessagePack: __proto__ is not allowed as a key");
      }
      map[key] = read();
    }
    return map;
  }

  function readExtension(length: number) {
    const type = view.getInt8(take(1));
    const data = readBinary(length);
    if (type !== BLOB_EXTENSION) {
      throw new Error(`MessagePack: unknown extension type ${type}`);
    }
    return new Blob([data], { type: SESSION_MIME_TYPE });
  }

  function read(): unknown {
    const byte = view.getUint8(take(1));

    if (byte < 0x80) return byte;
    if (byte < 0x90) return readMap(byte & 0x0f);
    if (byte < 0xa0) return readArray(byte & 0x0f);
    if (byte < 0xc0) return readString(byte & 0x1f);
    if (byte >= 0xe0) return byte - 0x100;

    switch (byte) {
      case 0xc0:
        return null;
      case 0xc2:
        return false;
      case 0xc3:
        return true;
      case 0xc4:
      case 0xc5:
      case 0xc6:
        return readBinary(readLength(1 << (byte - 0xc4)));
      case 0xc7:
      case 0xc8:
      case 0xc9:
        return readExtension(readLength(1 << (byte - 0xc7)));
      case 0xca:
        return view.getFloat32(take(4));
      case 0xcb:
        return view.getFloat64(take(8));
      case 0xcc:
        return view.getUint8(take(1));
      case 0xcd:
        return view.getUint16(take(2));
      case 0xce:
        return view.getUint32(take(4));
      case 0xcf:
        return Number(view.getBigUint64(take(8)));
      case 0xd0:
        return view.getInt8(take(1));
      case 0xd1:
        return view.getInt16(take(2));
      case 0xd2:
        return view.getInt32(take(4));
      case 0xd3:
        return Number(view.getBigInt64(take(8)));
      case 0xd4:
      case 0xd5:
      case 0xd6:
      case 0xd7:
      case 0xd8:
        return readExtension(1 << (byte - 0xd4));
      case 0xd9:
      case 0xda:
      case 0xdb:
        return readString(readLength(1 << (byte - 0xd9)));
      case 0xdc:
        return readArray(readLength(2));
      case 0xdd:
        return readArray(readLength(4));
      case 0xde:
        return readMap(readLength(2));
      case 0xdf:
        return readMap(readLength(4));
      default:
        throw new Error(`MessagePack: unknown type 0x${byte.toString(16)}`);
    }
  }

  const value = read();
  if (offset !== bytes.length) throw new Error("MessagePack: trailing bytes");
  return value;
}

export function encode(value: unknown): Uint8Array<ArrayBuffer> {
  let bytes = new Uint8Array(256);
  let view = new DataView(bytes.buffer);
  let offset = 0;

  // Makes room for `size` more bytes and returns where they start.
  function reserve(size: number) {
    const start = offset;
    offset += size;

    if (offset > bytes.length) {
      const grown = new Uint8Array(Math.max(offset, bytes.length * 2));
      grown.set(bytes);
      bytes = grown;
      view = new DataView(bytes.buffer);
    }

    return start;
  }

  // Each writer reserves first: growing replaces `bytes` and `view`, so they
  // must not be read until the room is there.
  function writeByte(byte: number) {
    const at = reserve(1);
    bytes[at] = byte;
  }

  function writeUint16(value: number) {
    const at = reserve(2);
    view.setUint16(at, value);
  }

  function writeUint32(value: number) {
    const at = reserve(4);
    view.setUint32(at, value);
  }

  function writeBytes(data: Uint8Array) {
    const at = reserve(data.length);
    bytes.set(data, at);
  }

  // Writes a length with the smallest of the type bytes that fits it. Strings
  // and binary have forms with one, two and four bytes of length, starting
  // at `type`. Arrays and maps only have the last two.
  function writeLength(type: number, length: number, hasByteForm: boolean) {
    if (hasByteForm && length < 0x100) {
      writeByte(type);
      writeByte(length);
    } else if (length < 0x10000) {
      writeByte(hasByteForm ? type + 1 : type);
      writeUint16(length);
    } else {
      writeByte(hasByteForm ? type + 2 : type + 1);
      writeUint32(length);
    }
  }

  function writeNumber(number: number) {
    if (!Number.isSafeInteger(number)) {
      writeByte(0xcb);
      const at = reserve(8);
      view.setFloat64(at, number);
    } else if (number >= 0) {
      if (number < 0x80) {
        writeByte(number);
      } else if (number < 0x100) {
        writeByte(0xcc);
        writeByte(number);
      } else if (number < 0x10000) {
        writeByte(0xcd);
        writeUint16(number);
      } else if (number < 0x100000000) {
        writeByte(0xce);
        writeUint32(number);
      } else {
        writeByte(0xcf);
        const at = reserve(8);
        view.setBigUint64(at, BigInt(number));
      }
    } else if (number >= -0x20) {
      writeByte(0x100 + number);
    } else if (number >= -0x80) {
      writeByte(0xd0);
      writeByte(0x100 + number);
    } else if (number >= -0x8000) {
      writeByte(0xd1);
      writeUint16(0x10000 + number);
    } else if (number >= -0x80000000) {
      writeByte(0xd2);
      writeUint32(0x100000000 + number);
    } else {
      writeByte(0xd3);
      const at = reserve(8);
      view.setBigInt64(at, BigInt(number));
    }
  }
  function write(value: unknown, depth: number) {
    if (depth > MAX_ENCODE_DEPTH)
      throw new Error("MessagePack: nested too deep");

    if (value === null || value === undefined) {
      writeByte(0xc0);
    } else if (typeof value === "boolean") {
      writeByte(value ? 0xc3 : 0xc2);
    } else if (typeof value === "number") {
      writeNumber(value);
    } else if (typeof value === "bigint") {
      writeNumber(Number(value));
    } else if (typeof value === "string") {
      const data = textEncoder.encode(value);
      if (data.length < 0x20) writeByte(0xa0 | data.length);
      else writeLength(0xd9, data.length, true);
      writeBytes(data);
    } else if (Array.isArray(value)) {
      if (value.length < 0x10) writeByte(0x90 | value.length);
      else writeLength(0xdc, value.length, false);
      for (const item of value) write(item, depth + 1);
    } else if (ArrayBuffer.isView(value)) {
      const data = new Uint8Array(
        value.buffer,
        value.byteOffset,
        value.byteLength,
      );
      writeLength(0xc4, data.length, true);
      writeBytes(data);
    } else if (typeof value === "object") {
      const keys = Object.keys(value);
      if (keys.length < 0x10) writeByte(0x80 | keys.length);
      else writeLength(0xde, keys.length, false);
      for (const key of keys) {
        write(key, depth + 1);
        write((value as Record<string, unknown>)[key], depth + 1);
      }
    } else {
      throw new Error(`MessagePack: can't encode a ${typeof value}`);
    }
  }

  write(value, 0);
  return bytes.slice(0, offset);
}
