import pg from 'pg';
import { databaseUrl } from './config.js';

export const pool = new pg.Pool({
  connectionString: databaseUrl(),
  max: 10,
  connectionTimeoutMillis: 5000,
  idleTimeoutMillis: 30000,
});
