import {
  createSign,
  createPrivateKey,
  randomBytes,
  generateKeyPairSync,
  createHash,
  type KeyObject,
} from 'node:crypto';
import { isoCBOR } from '@simplewebauthn/server/helpers';
import type {
  RegistrationResponseJSON,
  AuthenticationResponseJSON,
} from '@simplewebauthn/server';

/**
 * Slice P7b — minimal WebAuthn authenticator simulator for integration
 * tests. Produces spec-compliant attestation + assertion payloads that
 * `@simplewebauthn/server`'s verifiers accept without any real
 * authenticator hardware.
 *
 * Scope: ES256 (COSE -7) with attestation fmt = 'none'. That's the
 * lowest-common-denominator subset every modern platform authenticator
 * supports, and the one the service's `supportedAlgorithmIDs` default
 * includes. We don't simulate a TPM attestation path — `'none'` is what
 * Android Credential Manager produces in practice for resident keys.
 */

function b64url(buf: Buffer | Uint8Array): string {
  return Buffer.from(buf).toString('base64url');
}

function toUint8(bytes: Buffer | Uint8Array): Uint8Array {
  if (bytes instanceof Uint8Array && !(bytes instanceof Buffer)) return bytes;
  return new Uint8Array(Buffer.from(bytes));
}

function concatBytes(...parts: (Buffer | Uint8Array)[]): Buffer {
  return Buffer.concat(parts.map((p) => (p instanceof Buffer ? p : Buffer.from(p))));
}

function rpIdHash(rpId: string): Buffer {
  return createHash('sha256').update(rpId).digest();
}

/**
 * Extract the raw 32-byte x and y from a P-256 public key. Node's
 * `KeyObject.export({format:'jwk'})` gives us base64url-encoded
 * coordinates; we decode and left-pad to 32 bytes.
 */
function extractEcXY(pub: KeyObject): { x: Uint8Array; y: Uint8Array } {
  const jwk = pub.export({ format: 'jwk' }) as { x: string; y: string };
  const toCoord = (b: string): Uint8Array => {
    const raw = Buffer.from(b, 'base64url');
    if (raw.length === 32) return new Uint8Array(raw);
    const pad = Buffer.alloc(32 - raw.length);
    return new Uint8Array(Buffer.concat([pad, raw]));
  };
  return { x: toCoord(jwk.x), y: toCoord(jwk.y) };
}

/**
 * Build a COSE_Key (CBOR map) for an ES256 public key. Matches the
 * RFC 8152 EC2 encoding: kty=2 (EC2), alg=-7 (ES256), crv=1 (P-256).
 */
function buildCoseKey(pub: KeyObject): Uint8Array {
  const { x, y } = extractEcXY(pub);
  const m = new Map<number, number | Uint8Array>();
  m.set(1, 2); // kty = EC2
  m.set(3, -7); // alg = ES256
  m.set(-1, 1); // crv = P-256
  m.set(-2, x);
  m.set(-3, y);
  return isoCBOR.encode(m);
}

/**
 * Build a minimal authenticatorData buffer per WebAuthn §6.1.
 *
 *   rpIdHash(32) || flags(1) || signCount(4) [|| attestedCredentialData]
 *
 * When `credentialId` + `cosePublicKey` are present, the AT flag is
 * set and the attested-credential-data block is appended.
 */
function buildAuthData(options: {
  rpId: string;
  signCount: number;
  userPresent: boolean;
  userVerified: boolean;
  attestedCredential?: {
    aaguid: Uint8Array; // 16 bytes
    credentialId: Uint8Array;
    cosePublicKey: Uint8Array;
  };
}): Buffer {
  const { rpId, signCount, userPresent, userVerified, attestedCredential } = options;
  const hash = rpIdHash(rpId);
  let flags = 0;
  if (userPresent) flags |= 0x01; // UP
  if (userVerified) flags |= 0x04; // UV
  if (attestedCredential) flags |= 0x40; // AT

  const signCountBuf = Buffer.alloc(4);
  signCountBuf.writeUInt32BE(signCount, 0);

  if (!attestedCredential) {
    return concatBytes(hash, Buffer.from([flags]), signCountBuf);
  }

  const credIdLenBuf = Buffer.alloc(2);
  credIdLenBuf.writeUInt16BE(attestedCredential.credentialId.byteLength, 0);
  return concatBytes(
    hash,
    Buffer.from([flags]),
    signCountBuf,
    attestedCredential.aaguid,
    credIdLenBuf,
    attestedCredential.credentialId,
    attestedCredential.cosePublicKey,
  );
}

export interface TestAuthenticator {
  credentialId: Uint8Array;
  /**
   * Produce a registration response. `challenge` must be the base64url
   * challenge the server issued; `origin` must be the origin string
   * the server expects (byte-for-byte). `signCount` defaults to 0 per
   * WebAuthn §6 (initial counter).
   */
  createRegistrationResponse(args: {
    challenge: string;
    origin: string;
    rpId: string;
  }): RegistrationResponseJSON;
  /**
   * Produce an assertion for a given challenge. `signCount` increments
   * by default; override to force a regression (cloning scenario).
   */
  createAssertionResponse(args: {
    challenge: string;
    origin: string;
    rpId: string;
    /** When set, use this exact value instead of the auto-incremented counter. */
    signCountOverride?: number;
  }): AuthenticationResponseJSON;
  /** The monotonic sign-count the authenticator will use on its NEXT assertion. */
  readonly nextSignCount: number;
}

/**
 * Build a fresh ES256 authenticator with a random credential ID and
 * AAGUID. Each call yields an independent key pair — two calls represent
 * two distinct passkeys on the same user's account.
 */
export function makeTestAuthenticator(): TestAuthenticator {
  const { publicKey, privateKey } = generateKeyPairSync('ec', {
    namedCurve: 'prime256v1',
  });
  const credentialId = new Uint8Array(randomBytes(32));
  const aaguid = new Uint8Array(randomBytes(16));
  const cosePublicKey = buildCoseKey(publicKey);
  let signCount = 0; // first assertion will increment to 1

  function signAuthData(authData: Buffer, clientDataJSONBytes: Buffer): Buffer {
    const clientDataHash = createHash('sha256').update(clientDataJSONBytes).digest();
    const signingData = Buffer.concat([authData, clientDataHash]);
    const signer = createSign('SHA256');
    signer.update(signingData);
    signer.end();
    return signer.sign(createPrivateKey(privateKey.export({ format: 'pem', type: 'pkcs8' })));
  }

  return {
    credentialId,
    get nextSignCount() {
      return signCount + 1;
    },
    createRegistrationResponse({ challenge, origin, rpId }) {
      const authData = buildAuthData({
        rpId,
        signCount: 0, // initial per §6
        userPresent: true,
        userVerified: true,
        attestedCredential: { aaguid, credentialId, cosePublicKey },
      });
      // Attestation object with fmt='none' and empty attStmt — the
      // spec-defined no-attestation path.
      // `isoCBOR.encode` types require the map's values to be CBOR-able.
      // Casting here is safe — the actual values (string, empty Map,
      // Uint8Array) are all CBOR-encodable; the compiler's variance
      // rules just don't see through the `unknown` upcast.
      const attObj = new Map<string, unknown>();
      attObj.set('fmt', 'none');
      attObj.set('attStmt', new Map());
      attObj.set('authData', toUint8(authData));
      const attestationObjectBytes = isoCBOR.encode(
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        attObj as any,
      );
      const clientDataJSON = JSON.stringify({
        type: 'webauthn.create',
        challenge,
        origin,
        crossOrigin: false,
      });
      return {
        id: b64url(credentialId),
        rawId: b64url(credentialId),
        type: 'public-key',
        response: {
          attestationObject: b64url(attestationObjectBytes),
          clientDataJSON: b64url(Buffer.from(clientDataJSON, 'utf8')),
          transports: ['internal'],
          publicKeyAlgorithm: -7,
        },
        clientExtensionResults: {},
        authenticatorAttachment: 'platform',
      };
    },
    createAssertionResponse({ challenge, origin, rpId, signCountOverride }) {
      const effectiveCount = signCountOverride ?? signCount + 1;
      const authData = buildAuthData({
        rpId,
        signCount: effectiveCount,
        userPresent: true,
        userVerified: true,
      });
      const clientDataJSON = JSON.stringify({
        type: 'webauthn.get',
        challenge,
        origin,
        crossOrigin: false,
      });
      const clientDataJSONBytes = Buffer.from(clientDataJSON, 'utf8');
      const signature = signAuthData(authData, clientDataJSONBytes);
      // Update the internal counter only when NOT using an override —
      // an override represents "attacker replays with an old count",
      // which from the authenticator's internal state would have been
      // a legitimate-old assertion that somehow re-emerged.
      if (signCountOverride === undefined) signCount = effectiveCount;
      return {
        id: b64url(credentialId),
        rawId: b64url(credentialId),
        type: 'public-key',
        response: {
          authenticatorData: b64url(authData),
          clientDataJSON: b64url(clientDataJSONBytes),
          signature: b64url(signature),
        },
        clientExtensionResults: {},
        authenticatorAttachment: 'platform',
      };
    },
  };
}
