import { createHash, randomBytes, randomUUID } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import Fastify, { type FastifyReply, type FastifyRequest } from 'fastify';
import rateLimit from '@fastify/rate-limit';
import argon2 from 'argon2';
import { pool } from './db.js';
import { tlsCertPath, tlsKeyPath } from './config.js';

declare module 'fastify' {
  interface FastifyRequest { userId: string | null }
}

type PatientRow = {
  id: string; full_name: string; phone: string; treatment_goal: string;
  birth_date: string; age: number;
};
type AppointmentRow = {
  id: string; patient_id: string; patient_name: string;
  starts_at: Date; status: string; notes: string;
};

// APRESENTAÇÃO: o banco guarda o hash dos tokens, nunca o token de sessão puro.
const tokenHash = (token: string) => createHash('sha256').update(token).digest('hex');
const newToken = () => randomBytes(32).toString('base64url');
const patientSelect = `id, full_name, phone, treatment_goal,
  to_char(birth_date, 'YYYY-MM-DD') AS birth_date,
  date_part('year', age(birth_date))::int AS age`;
const patientJson = (row: PatientRow) => ({
  id: row.id, name: row.full_name, phone: row.phone,
  condition: row.treatment_goal, birthDate: row.birth_date, age: row.age,
});
const appointmentJson = (row: AppointmentRow) => ({
  id: row.id, patientId: row.patient_id, patientName: row.patient_name,
  startsAt: row.starts_at.toISOString(), status: row.status, notes: row.notes,
});
const validDate = (value: string) => /^\d{4}-\d{2}-\d{2}$/.test(value) &&
  !Number.isNaN(Date.parse(`${value}T12:00:00Z`)) &&
  new Date(`${value}T12:00:00Z`).toISOString().startsWith(value) &&
  value <= new Date().toISOString().slice(0, 10);
const validDateTime = (value: string) => !Number.isNaN(Date.parse(value));

async function audit(userId: string, action: string, entityType: string, entityId: string | null) {
  // APRESENTAÇÃO: registra quem fez a operação sem copiar dados clínicos para o log.
  await pool.query(
    'INSERT INTO audit_events(id, actor_user_id, action, entity_type, entity_id) VALUES ($1,$2,$3,$4,$5)',
    [randomUUID(), userId, action, entityType, entityId],
  );
}

async function authenticate(request: FastifyRequest, reply: FastifyReply) {
  // APRESENTAÇÃO: cada rota protegida confere token, validade e conta ativa.
  const match = /^Bearer ([A-Za-z0-9_-]+)$/.exec(request.headers.authorization ?? '');
  if (!match) return reply.code(401).send({ error: 'Sessão inválida.' });
  const result = await pool.query<{ user_id: string }>(`
    SELECT s.user_id FROM sessions s JOIN users u ON u.id = s.user_id
    WHERE s.access_token_hash = $1 AND s.access_expires_at > now()
      AND s.refresh_expires_at > now() AND s.revoked_at IS NULL AND u.disabled_at IS NULL`,
    [tokenHash(match[1]!)],
  );
  if (!result.rows[0]) return reply.code(401).send({ error: 'Sessão expirada.' });
  request.userId = result.rows[0].user_id;
}

const credentialsSchema = {
  type: 'object', additionalProperties: false, required: ['email', 'password'],
  properties: {
    email: { type: 'string', minLength: 3, maxLength: 254 },
    password: { type: 'string', minLength: 1, maxLength: 1024 },
  },
} as const;
const registrationSchema = {
  type: 'object', additionalProperties: false, required: ['email', 'password'],
  properties: {
    email: { type: 'string', minLength: 3, maxLength: 254 },
    password: { type: 'string', minLength: 12, maxLength: 128 },
  },
} as const;
const tokenSchema = {
  type: 'object', additionalProperties: false, required: ['refreshToken'],
  properties: { refreshToken: { type: 'string', minLength: 20, maxLength: 256 } },
} as const;
const patientProperties = {
  name: { type: 'string', minLength: 2, maxLength: 160 },
  birthDate: { type: 'string', pattern: '^\\d{4}-\\d{2}-\\d{2}$' },
  phone: { type: 'string', minLength: 8, maxLength: 40 },
  condition: { type: 'string', minLength: 2, maxLength: 2000 },
} as const;
const appointmentProperties = {
  patientId: { type: 'string', format: 'uuid' },
  startsAt: { type: 'string', minLength: 20, maxLength: 40 },
  status: { type: 'string', enum: ['scheduled', 'completed', 'cancelled'] },
  notes: { type: 'string', maxLength: 2000 },
} as const;

// APRESENTAÇÃO: a API aceita apenas HTTPS; a chave privada fica fora do projeto.
const app = Fastify({
  logger: false,
  https: {
    key: await readFile(tlsKeyPath),
    cert: await readFile(tlsCertPath),
    minVersion: 'TLSv1.2',
  },
  bodyLimit: 16 * 1024,
});
app.decorateRequest('userId', null);
await app.register(rateLimit, { global: false });
app.setErrorHandler((error, _request, reply) => {
  const details = error as { validation?: unknown; statusCode?: number; name?: string };
  if (details.validation) return reply.code(400).send({ error: 'Dados inválidos.' });
  if (details.statusCode === 429) return reply.code(429).send({ error: 'Muitas tentativas. Aguarde.' });
  process.stderr.write(`Erro interno: ${details.name ?? 'desconhecido'}\n`);
  return reply.code(500).send({ error: 'Erro interno. Tente novamente.' });
});

const dummyHash = await argon2.hash(randomBytes(32), { type: argon2.argon2id });

async function issueSession(userId: string) {
  const accessToken = newToken();
  const refreshToken = newToken();
  await pool.query(`INSERT INTO sessions
    (id,user_id,access_token_hash,refresh_token_hash,access_expires_at,refresh_expires_at)
    VALUES ($1,$2,$3,$4,now()+interval '15 minutes',now()+interval '30 days')`,
    [randomUUID(), userId, tokenHash(accessToken), tokenHash(refreshToken)],
  );
  return { accessToken, refreshToken, expiresInSeconds: 900 };
}

app.get('/health', async () => ({ ok: true }));
app.post<{ Body: { email: string; password: string } }>(
  '/v1/auth/register',
  // APRESENTAÇÃO: novas contas locais usam senha com hash Argon2id.
  // O servidor ainda não verifica a posse do e-mail, por isso não é publicado na internet.
  { schema: { body: registrationSchema }, config: { rateLimit: { max: 3, timeWindow: '1 hour' } } },
  async (request, reply) => {
    const email = request.body.email.trim().toLowerCase();
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      return reply.code(400).send({ error: 'Informe um e-mail válido.' });
    }
    const id = randomUUID();
    const hash = await argon2.hash(request.body.password, { type: argon2.argon2id });
    try {
      await pool.query(
        'INSERT INTO users(id, email, password_hash) VALUES ($1, $2, $3)',
        [id, email, hash],
      );
    } catch (error) {
      if ((error as { code?: string }).code === '23505') {
        return reply.code(409).send({ error: 'Este e-mail já está cadastrado.' });
      }
      throw error;
    }
    const session = await issueSession(id);
    await audit(id, 'register', 'user', id);
    return reply.code(201).send(session);
  },
);
app.post<{ Body: { email: string; password: string } }>(
  '/v1/auth/login',
  // APRESENTAÇÃO: o login valida a senha e emite tokens de curta duração.
  { schema: { body: credentialsSchema }, config: { rateLimit: { max: 5, timeWindow: '1 minute' } } },
  async (request, reply) => {
    const email = request.body.email.trim().toLowerCase();
    const result = await pool.query<{ id: string; password_hash: string }>(
      'SELECT id, password_hash FROM users WHERE email = $1 AND disabled_at IS NULL', [email],
    );
    const user = result.rows[0];
    const valid = await argon2.verify(user?.password_hash ?? dummyHash, request.body.password);
    if (!user || !valid) return reply.code(401).send({ error: 'E-mail ou senha inválidos.' });
    const session = await issueSession(user.id);
    await audit(user.id, 'login', 'session', null);
    return session;
  },
);

app.post<{ Body: { refreshToken: string } }>(
  '/v1/auth/refresh', { schema: { body: tokenSchema } },
  async (request, reply) => {
    const accessToken = newToken();
    const refreshToken = newToken();
    const result = await pool.query(`UPDATE sessions s SET
      access_token_hash=$1, refresh_token_hash=$2,
      access_expires_at=now()+interval '15 minutes',
      refresh_expires_at=now()+interval '30 days'
      FROM users u WHERE s.user_id=u.id AND u.disabled_at IS NULL
      AND s.refresh_token_hash=$3 AND s.refresh_expires_at>now() AND s.revoked_at IS NULL
      RETURNING s.user_id`,
      [tokenHash(accessToken), tokenHash(refreshToken), tokenHash(request.body.refreshToken)],
    );
    if (!result.rows[0]) return reply.code(401).send({ error: 'Sessão expirada.' });
    return { accessToken, refreshToken, expiresInSeconds: 900 };
  },
);

app.post<{ Body: { refreshToken: string } }>(
  '/v1/auth/logout', { schema: { body: tokenSchema } },
  async (request) => {
    await pool.query('UPDATE sessions SET revoked_at=now() WHERE refresh_token_hash=$1',
      [tokenHash(request.body.refreshToken)]);
    return { ok: true };
  },
);

await app.register(async (secured) => {
  // APRESENTAÇÃO: pacientes e atendimentos exigem autenticação; as consultas
  // filtram owner_user_id para cada conta ver apenas os próprios registros.
  secured.addHook('preHandler', authenticate);
  secured.get('/v1/me', async (request) => {
    const result = await pool.query('SELECT id,email FROM users WHERE id=$1', [request.userId]);
    return result.rows[0];
  });

  secured.get<{ Querystring: { q?: string } }>('/v1/patients', {
    schema: { querystring: { type: 'object', additionalProperties: false,
      properties: { q: { type: 'string', maxLength: 100 } } } },
  }, async (request) => {
    const q = (request.query.q ?? '').trim().slice(0, 100);
    const result = await pool.query<PatientRow>(`
      SELECT ${patientSelect} FROM patients
      WHERE owner_user_id=$1 AND full_name ILIKE $2
      ORDER BY full_name LIMIT 100`, [request.userId, `%${q}%`]);
    await audit(request.userId!, 'list', 'patient', null);
    return result.rows.map(patientJson);
  });
  secured.post<{ Body: { name: string; birthDate: string; phone: string; condition: string } }>(
    '/v1/patients',
    { schema: { body: { type: 'object', additionalProperties: false,
      required: ['name','birthDate','phone','condition'], properties: patientProperties } } },
    async (request, reply) => {
      const body = request.body;
      if (!validDate(body.birthDate)) return reply.code(400).send({ error: 'Data de nascimento inválida.' });
      if (!body.name.trim() || !body.phone.trim() || !body.condition.trim())
        return reply.code(400).send({ error: 'Preencha todos os campos.' });
      const id = randomUUID();
      const result = await pool.query<PatientRow>(`
        INSERT INTO patients(id,owner_user_id,full_name,birth_date,phone,treatment_goal)
        VALUES ($1,$2,$3,$4,$5,$6) RETURNING ${patientSelect}`,
        [id, request.userId, body.name.trim(), body.birthDate, body.phone.trim(), body.condition.trim()]);
      await audit(request.userId!, 'create', 'patient', id);
      return reply.code(201).send(patientJson(result.rows[0]!));
    },
  );
  secured.get<{ Params: { id: string } }>(
    '/v1/patients/:id',
    { schema: { params: { type:'object', required:['id'], properties:{id:{type:'string',format:'uuid'}} } } },
    async (request, reply) => {
      const result = await pool.query<PatientRow>(`
        SELECT ${patientSelect} FROM patients WHERE id=$1 AND owner_user_id=$2`,
        [request.params.id, request.userId]);
      if (!result.rows[0]) return reply.code(404).send({ error: 'Paciente não encontrado.' });
      await audit(request.userId!, 'read', 'patient', request.params.id);
      return patientJson(result.rows[0]);
    },
  );
  secured.patch<{ Params:{id:string}; Body:{name?:string;birthDate?:string;phone?:string;condition?:string} }>(
    '/v1/patients/:id',
    { schema: {
      params: { type:'object', required:['id'], properties:{id:{type:'string',format:'uuid'}} },
      body: {type:'object',additionalProperties:false,minProperties:1,properties:patientProperties},
    } },
    async (request, reply) => {
      const b = request.body;
      if (b.birthDate && !validDate(b.birthDate)) return reply.code(400).send({ error: 'Data inválida.' });
      if ([b.name, b.phone, b.condition].some((value) => value !== undefined && !value.trim()))
        return reply.code(400).send({ error: 'Campos não podem ficar vazios.' });
      const result = await pool.query<PatientRow>(`
        UPDATE patients SET full_name=coalesce($3,full_name), birth_date=coalesce($4,birth_date),
        phone=coalesce($5,phone), treatment_goal=coalesce($6,treatment_goal), updated_at=now()
        WHERE id=$1 AND owner_user_id=$2 RETURNING ${patientSelect}`,
        [request.params.id,request.userId,b.name?.trim(),b.birthDate,b.phone?.trim(),b.condition?.trim()]);
      if (!result.rows[0]) return reply.code(404).send({ error: 'Paciente não encontrado.' });
      await audit(request.userId!, 'update', 'patient', request.params.id);
      return patientJson(result.rows[0]);
    },
  );

  secured.get('/v1/appointments', async (request) => {
    const result = await pool.query<AppointmentRow>(`
      SELECT a.id,a.patient_id,p.full_name AS patient_name,a.starts_at,a.status,a.notes
      FROM appointments a JOIN patients p ON p.id=a.patient_id
      WHERE a.owner_user_id=$1 ORDER BY a.starts_at DESC LIMIT 100`, [request.userId]);
    await audit(request.userId!, 'list', 'appointment', null);
    return result.rows.map(appointmentJson);
  });
  secured.post<{ Body:{patientId:string;startsAt:string;notes?:string} }>(
    '/v1/appointments',
    { schema: { body: {type:'object',additionalProperties:false,required:['patientId','startsAt'],
      properties:appointmentProperties} } },
    async (request, reply) => {
      const b = request.body;
      if (!validDateTime(b.startsAt)) return reply.code(400).send({ error: 'Data inválida.' });
      const result = await pool.query(`SELECT id FROM patients WHERE id=$1 AND owner_user_id=$2`,
        [b.patientId,request.userId]);
      if (!result.rows[0]) return reply.code(404).send({ error: 'Paciente não encontrado.' });
      const id = randomUUID();
      await pool.query(`INSERT INTO appointments(id,owner_user_id,patient_id,starts_at,notes)
        VALUES ($1,$2,$3,$4,$5)`, [id,request.userId,b.patientId,b.startsAt,b.notes??'']);
      await audit(request.userId!, 'create', 'appointment', id);
      return reply.code(201).send({ id });
    },
  );
  secured.patch<{ Params:{id:string}; Body:{startsAt?:string;status?:string;notes?:string} }>(
    '/v1/appointments/:id',
    { schema: {
      params: { type:'object', required:['id'], properties:{id:{type:'string',format:'uuid'}} },
      body:{type:'object',additionalProperties:false,minProperties:1,
        properties:{startsAt:appointmentProperties.startsAt,status:appointmentProperties.status,
          notes:appointmentProperties.notes}},
    } },
    async (request, reply) => {
      const b = request.body;
      if (b.startsAt && !validDateTime(b.startsAt)) return reply.code(400).send({ error: 'Data inválida.' });
      const result = await pool.query(`UPDATE appointments SET
        starts_at=coalesce($3,starts_at),status=coalesce($4,status),notes=coalesce($5,notes),updated_at=now()
        WHERE id=$1 AND owner_user_id=$2 RETURNING id`,
        [request.params.id,request.userId,b.startsAt,b.status,b.notes]);
      if (!result.rows[0]) return reply.code(404).send({ error: 'Atendimento não encontrado.' });
      await audit(request.userId!, 'update', 'appointment', request.params.id);
      return { id: request.params.id };
    },
  );
});

await pool.query('SELECT 1');
const port = Number(process.env.PORT ?? 8443);
await app.listen({ host: '127.0.0.1', port });
process.stdout.write(`Fisio 360 API HTTPS ativa na porta ${port}.\n`);
for (const signal of ['SIGINT','SIGTERM'] as const) {
  process.on(signal, async () => { await app.close(); await pool.end(); process.exit(0); });
}
