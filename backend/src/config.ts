import { join } from 'node:path';
import { existsSync, readFileSync } from 'node:fs';
import { homedir } from 'node:os';

// Alguns processos recebem LOCALAPPDATA redirecionado. Primeiro procura a
// instalação da conta real, sem mover arquivos nem mudar suas permissões.
const profileDataDir = join(process.env.USERPROFILE ?? homedir(), 'AppData', 'Local', 'Fisio360');
const codexDataDir = join(process.env.USERPROFILE ?? homedir(), 'AppData', 'Local',
  'Packages', 'OpenAI.Codex_2p2nqsd0c76g0', 'LocalCache', 'Local', 'Fisio360');
const localDataDir = process.env.LOCALAPPDATA && join(process.env.LOCALAPPDATA, 'Fisio360');
// Compatibilidade com a instalação existente: o Codex/MSIX virtualizou AppData.
// Fora dele, só o endereço físico do LocalCache enxerga os mesmos arquivos.
const existingDataDir = [profileDataDir, codexDataDir, localDataDir]
  .find((path) => path && existsSync(join(path, 'backend.env')));
export const dataDir = process.env.FISIO_DATA_DIR ?? existingDataDir ?? profileDataDir;

export function databaseUrl(): string {
  const value = process.env.DATABASE_URL ??
    readFileSync(join(dataDir, 'backend.env'), 'utf8').trim();
  if (!value) throw new Error('DATABASE_URL não configurada.');
  return value;
}

export const tlsKeyPath = join(dataDir, 'server.key.pem');
export const tlsCertPath = join(dataDir, 'server.cert.pem');
