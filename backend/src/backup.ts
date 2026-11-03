import { createCipheriv, createDecipheriv, randomBytes, scryptSync } from 'node:crypto';
import { createReadStream, createWriteStream, readFileSync } from 'node:fs';
import { open, rm, stat } from 'node:fs/promises';
import { spawn } from 'node:child_process';
import { basename, join, resolve } from 'node:path';
import { pipeline } from 'node:stream/promises';
import { StringDecoder } from 'node:string_decoder';
import { databaseUrl, dataDir } from './config.js';

const magic = Buffer.from('FISIO360BACKUP1');
const headerSize = magic.length + 16 + 12;
const pgBin = 'C:\\src\\postgresql\\pgsql\\bin';

function promptSecret(message: string): Promise<string> {
  return new Promise((resolveSecret, reject) => {
    if (!process.stdin.isTTY || !process.stdin.setRawMode) {
      reject(new Error('Execute no terminal interativo.'));
      return;
    }
    let secret = '';
    const decoder = new StringDecoder('utf8');
    process.stdout.write(message);
    process.stdin.setRawMode(true);
    process.stdin.resume();
    const onData = (chunk: Buffer) => {
      for (const character of decoder.write(chunk)) {
        const code = character.charCodeAt(0);
        if (code === 3) { cleanup(); reject(new Error('Cancelado.')); return; }
        if (code === 13 || code === 10) {
          cleanup(); process.stdout.write('\n'); resolveSecret(secret); return;
        }
        if (code === 8 || code === 127) secret = Array.from(secret).slice(0, -1).join('');
        else if (code >= 32) secret += character;
      }
    };
    const cleanup = () => {
      process.stdin.off('data', onData);
      process.stdin.setRawMode(false);
      process.stdin.pause();
    };
    process.stdin.on('data', onData);
  });
}

function connection(admin = false) {
  const raw = admin
    ? requireAdminUrl()
    : databaseUrl();
  const url = new URL(raw);
  return {
    args: ['-h', url.hostname, '-p', url.port || '5432', '-U', decodeURIComponent(url.username)],
    env: { ...process.env, PGPASSWORD: decodeURIComponent(url.password) },
    database: url.pathname.slice(1),
  };
}

function requireAdminUrl(): string {
  return readFileSync(join(dataDir, 'postgres-admin.env'), 'utf8').trim();
}

function run(command: string, args: string[], env: NodeJS.ProcessEnv): Promise<void> {
  return new Promise((resolveRun, reject) => {
    const child = spawn(join(pgBin, command), args, { env, stdio: 'ignore' });
    child.on('error', reject);
    child.on('close', (code) => code === 0 ? resolveRun() : reject(new Error(`${command} falhou.`)));
  });
}

async function createBackup(destination: string) {
  // APRESENTAÇÃO: exporta o PostgreSQL e protege o arquivo com AES-256-GCM.
  // A frase é pedida no terminal e não é salva junto com o backup.
  const passphrase = await promptSecret('Frase de proteção do backup (mínimo 16 caracteres): ');
  if (passphrase.length < 16) throw new Error('Use pelo menos 16 caracteres.');
  const confirmation = await promptSecret('Repita a frase: ');
  if (passphrase !== confirmation) throw new Error('As frases são diferentes.');
  const salt = randomBytes(16);
  const iv = randomBytes(12);
  const key = scryptSync(passphrase, salt, 32);
  const cipher = createCipheriv('aes-256-gcm', key, iv);
  const db = connection();
  const dump = spawn(join(pgBin, 'pg_dump.exe'), [
    ...db.args, '-d', db.database, '--format=custom', '--no-owner', '--no-privileges',
  ], { env: db.env, stdio: ['ignore', 'pipe', 'ignore'] });
  const file = createWriteStream(destination, { flags: 'wx', mode: 0o600 });
  file.write(Buffer.concat([magic, salt, iv]));
  try {
    await pipeline(dump.stdout, cipher, file, { end: false });
    await new Promise<void>((ok, fail) => {
      dump.once('error', fail);
      if (dump.exitCode !== null) return dump.exitCode === 0 ? ok() : fail(new Error('pg_dump falhou.'));
      dump.once('close', (code) => code === 0 ? ok() : fail(new Error('pg_dump falhou.')));
    });
    file.end(cipher.getAuthTag());
    await new Promise<void>((ok, fail) => { file.once('finish', ok); file.once('error', fail); });
    process.stdout.write(`Backup criptografado criado: ${basename(destination)}\n`);
  } catch (error) {
    file.destroy();
    await rm(destination, { force: true });
    throw error;
  }
}

async function verifyBackup(source: string) {
  // APRESENTAÇÃO: a conferência restaura o arquivo em um banco temporário.
  const passphrase = await promptSecret('Frase de proteção do backup: ');
  const size = (await stat(source)).size;
  if (size <= headerSize + 16) throw new Error('Arquivo de backup inválido.');
  const handle = await open(source, 'r');
  const header = Buffer.alloc(headerSize);
  const tag = Buffer.alloc(16);
  try {
    await handle.read(header, 0, header.length, 0);
    await handle.read(tag, 0, tag.length, size - tag.length);
  } finally { await handle.close(); }
  if (!header.subarray(0, magic.length).equals(magic)) throw new Error('Formato inválido.');
  const salt = header.subarray(magic.length, magic.length + 16);
  const iv = header.subarray(magic.length + 16);
  const decipher = createDecipheriv('aes-256-gcm', scryptSync(passphrase, salt, 32), iv);
  decipher.setAuthTag(tag);
  const admin = connection(true);
  const verifyName = `fisio_verify_${randomBytes(6).toString('hex')}`;
  await run('createdb.exe', [...admin.args, verifyName], admin.env);
  try {
    const restore = spawn(join(pgBin, 'pg_restore.exe'), [
      ...admin.args, '-d', verifyName, '--no-owner', '--no-privileges', '--exit-on-error',
    ], { env: admin.env, stdio: ['pipe', 'ignore', 'ignore'] });
    const exit = new Promise<void>((ok, fail) => {
      restore.once('error', fail);
      restore.once('close', (code) => code === 0 ? ok() : fail(new Error('Restauração falhou.')));
    });
    await Promise.all([
      pipeline(createReadStream(source, { start: headerSize, end: size - 17 }), decipher, restore.stdin),
      exit,
    ]);
    await run('psql.exe', [...admin.args, '-d', verifyName, '-v', 'ON_ERROR_STOP=1',
      '-c', 'SELECT count(*) FROM patients', '-c', 'SELECT count(*) FROM appointments'], admin.env);
    process.stdout.write('Backup restaurado e conferido em banco temporário.\n');
  } finally {
    await run('dropdb.exe', [...admin.args, '--if-exists', '--force', verifyName], admin.env);
  }
}

const command = process.argv[2];
const backupPath = process.argv[3] ?? '';
if (!backupPath || !['create', 'verify'].includes(command ?? '')) {
  throw new Error('Uso: npm run backup -- create|verify CAMINHO_DO_ARQUIVO');
}
if (command === 'create') await createBackup(resolve(backupPath));
else await verifyBackup(resolve(backupPath));
