import { randomUUID } from 'node:crypto';
import { createInterface } from 'node:readline/promises';
import { StringDecoder } from 'node:string_decoder';
import argon2 from 'argon2';
import { pool } from './db.js';

function hiddenPassword(prompt: string): Promise<string> {
  return new Promise((resolve, reject) => {
    const input = process.stdin;
    if (!input.isTTY || !input.setRawMode) {
      reject(new Error('Execute este comando em um terminal interativo.'));
      return;
    }
    let password = '';
    const decoder = new StringDecoder('utf8');
    process.stdout.write(prompt);
    input.setRawMode(true);
    input.resume();
    const onData = (chunk: Buffer) => {
      for (const character of decoder.write(chunk)) {
        const code = character.charCodeAt(0);
        if (code === 3) {
          cleanup();
          reject(new Error('Cancelado.'));
          return;
        }
        if (code === 13 || code === 10) {
          cleanup();
          process.stdout.write('\n');
          resolve(password);
          return;
        }
        if (code === 8 || code === 127) {
          password = Array.from(password).slice(0, -1).join('');
        } else if (code >= 32) {
          password += character;
        }
      }
    };
    const cleanup = () => {
      input.off('data', onData);
      input.setRawMode(false);
      input.pause();
    };
    input.on('data', onData);
  });
}

const rl = createInterface({ input: process.stdin, output: process.stdout });
// APRESENTAÇÃO: alternativa local para criar a primeira conta sem abrir uma rota administrativa.
const email = (await rl.question('E-mail do profissional: ')).trim().toLowerCase();
rl.close();
if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) throw new Error('E-mail inválido.');
const password = await hiddenPassword('Senha (mínimo 12 caracteres, entrada oculta): ');
if (password.length < 12) throw new Error('A senha precisa ter pelo menos 12 caracteres.');
try {
  const hash = await argon2.hash(password, { type: argon2.argon2id });
  await pool.query(
    'INSERT INTO users(id, email, password_hash) VALUES ($1, $2, $3)',
    [randomUUID(), email, hash],
  );
  process.stdout.write('Conta criada.\n');
} finally {
  await pool.end();
}
