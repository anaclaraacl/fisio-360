import { randomBytes } from 'node:crypto';
import { mkdir, writeFile, copyFile } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import forge from 'node-forge';
import { dataDir, tlsCertPath, tlsKeyPath } from './config.js';

const keys = forge.pki.rsa.generateKeyPair(3072);
const cert = forge.pki.createCertificate();
cert.publicKey = keys.publicKey;
cert.serialNumber = randomBytes(16).toString('hex');
cert.validity.notBefore = new Date();
cert.validity.notAfter = new Date(Date.now() + 365 * 24 * 60 * 60 * 1000);
const attrs = [{ name: 'commonName', value: 'Fisio 360 local' }];
cert.setSubject(attrs);
cert.setIssuer(attrs);
cert.setExtensions([
  { name: 'basicConstraints', cA: false, critical: true },
  { name: 'keyUsage', digitalSignature: true, keyEncipherment: true, critical: true },
  { name: 'extKeyUsage', serverAuth: true },
  { name: 'subjectAltName', altNames: [
    { type: 2, value: 'localhost' },
    { type: 7, ip: '10.0.2.2' },
    { type: 7, ip: '127.0.0.1' },
  ] },
]);
cert.sign(keys.privateKey, forge.md.sha256.create());
await mkdir(dataDir, { recursive: true, mode: 0o700 });
await writeFile(tlsKeyPath, forge.pki.privateKeyToPem(keys.privateKey), { mode: 0o600, flag: 'wx' });
await writeFile(tlsCertPath, forge.pki.certificateToPem(cert), { mode: 0o600, flag: 'wx' });
const publicCertPath = resolve('../assets/certs/local-api.pem');
await mkdir(dirname(publicCertPath), { recursive: true });
await copyFile(tlsCertPath, publicCertPath);
process.stdout.write(`Certificado público: ${publicCertPath}\nChave privada: ${dataDir} (não compartilhar)\n`);
