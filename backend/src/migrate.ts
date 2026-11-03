import { readdir, readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { join } from 'node:path';
import { pool } from './db.js';

const sqlDir = fileURLToPath(new URL('../sql/', import.meta.url));
// APRESENTAÇÃO: as migrações criam as tabelas e rodam em transação.
// O registro de cada arquivo impede que a mesma migração seja aplicada duas vezes.
const client = await pool.connect();
try {
  await client.query(`CREATE TABLE IF NOT EXISTS schema_migrations (
    filename text PRIMARY KEY,
    applied_at timestamptz NOT NULL DEFAULT now()
  )`);
  for (const filename of (await readdir(sqlDir)).filter((name) => name.endsWith('.sql')).sort()) {
    const done = await client.query('SELECT 1 FROM schema_migrations WHERE filename = $1', [filename]);
    if (done.rowCount) continue;
    const sql = await readFile(join(sqlDir, filename), 'utf8');
    await client.query('BEGIN');
    try {
      await client.query(sql);
      await client.query('INSERT INTO schema_migrations(filename) VALUES ($1)', [filename]);
      await client.query('COMMIT');
      process.stdout.write(`Migração aplicada: ${filename}\n`);
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    }
  }
} finally {
  client.release();
  await pool.end();
}
