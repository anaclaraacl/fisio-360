// Executado diretamente pelo Node em uma tarefa do VS Code, sem comandos de shell.
// Mantém credenciais no diretório privado; este iniciador só verifica sua existência.
import { existsSync, readFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { homedir } from 'node:os';
import { execFile, spawn } from 'node:child_process';
import { promisify } from 'node:util';
import https from 'node:https';

const exec = promisify(execFile);
const root = resolve(dirname(fileURLToPath(import.meta.url)), '..', '..');
const backend = join(root, 'backend');
const pgBin = 'C:\\src\\postgresql\\pgsql\\bin';
const adb = 'C:\\src\\android-sdk\\platform-tools\\adb.exe';
const emulator = 'C:\\src\\android-sdk\\emulator\\emulator.exe';
const avdName = 'Fisio360_API36';
const ca = readFileSync(join(root, 'assets', 'certs', 'local-api.pem'));
const candidates = [...new Set([
  process.env.FISIO_DATA_DIR,
  process.env.USERPROFILE && join(process.env.USERPROFILE, 'AppData', 'Local', 'Fisio360'),
  join(homedir(), 'AppData', 'Local', 'Fisio360'),
  join(process.env.USERPROFILE ?? homedir(), 'AppData', 'Local', 'Packages',
    'OpenAI.Codex_2p2nqsd0c76g0', 'LocalCache', 'Local', 'Fisio360'),
  process.env.LOCALAPPDATA && join(process.env.LOCALAPPDATA, 'Fisio360'),
].filter(Boolean))];
const dataDir = process.env.FISIO_DATA_DIR
  ? (existsSync(join(process.env.FISIO_DATA_DIR, 'backend.env')) ? process.env.FISIO_DATA_DIR : undefined)
  : candidates.find((p) => existsSync(join(p, 'backend.env')));
const sleep = (ms) => new Promise((done) => setTimeout(done, ms));
let apiProcess;

function apiReady() {
  return new Promise((done) => {
    const request = https.get({ hostname: 'localhost', port: 8443, path: '/health', ca,
      timeout: 2000 }, (response) => {
      let body = '';
      response.on('data', (chunk) => { body += chunk; });
      response.on('end', () => {
        try { done(response.statusCode === 200 && JSON.parse(body).ok === true); }
        catch { done(false); }
      });
      response.on('error', () => done(false));
    });
    request.on('error', () => done(false));
    request.on('timeout', () => request.destroy());
  });
}

async function run(file, args, timeout = 15000) {
  return exec(file, args, { cwd: root, windowsHide: true, timeout, maxBuffer: 1024 * 1024 });
}

async function ensureServices() {
  if (await apiReady()) {
    console.log('Banco e API já estão disponíveis.');
    return;
  }
  if (!dataDir) {
    console.error('Este processo não encontra backend.env. Caminhos verificados:');
    for (const p of candidates) console.error(`  ${join(p, 'backend.env')}`);
    throw new Error('Configuração local indisponível. Não execute setup-local novamente.');
  }
  const cluster = join(dataDir, 'postgres-data');
  for (const file of [join(cluster, 'PG_VERSION'), join(dataDir, 'server.key.pem'),
    join(dataDir, 'server.cert.pem'), join(backend, 'dist', 'server.js')]) {
    if (!existsSync(file)) throw new Error(`Arquivo necessário indisponível: ${file}`);
  }
  try {
    await run(join(pgBin, 'pg_isready.exe'), ['-h', '127.0.0.1', '-p', '5433']);
    console.log('Banco já está ativo.');
  } catch {
    console.log('Iniciando banco de dados...');
    await run(join(pgBin, 'pg_ctl.exe'), ['-D', cluster, '-l', join(dataDir, 'postgres.log'),
      '-o', '-h 127.0.0.1 -p 5433', '-w', 'start'], 70000);
  }
  console.log('Iniciando API no terminal do VS Code...');
  apiProcess = spawn(process.execPath, [join(backend, 'dist', 'server.js')], {
    cwd: backend, env: { ...process.env, FISIO_DATA_DIR: dataDir }, stdio: 'inherit',
  });
  apiProcess.on('error', () => console.error('Não foi possível iniciar o Node da API.'));
  for (let i = 0; i < 30; i++) {
    if (await apiReady()) { console.log('API pronta.'); return; }
    if (apiProcess.exitCode !== null) throw new Error('A API encerrou; veja a mensagem acima.');
    await sleep(1000);
  }
  throw new Error('A API não respondeu na porta 8443. Veja a mensagem acima.');
}

async function connectedEmulator() {
  const { stdout } = await run(adb, ['devices']);
  const devices = stdout.split('\n').map((line) => line.trim().match(/^(emulator-\d+)\s+device$/)?.[1]).filter(Boolean);
  for (const serial of devices) {
    try {
      const name = await run(adb, ['-s', serial, 'emu', 'avd', 'name']);
      if (name.stdout.split('\n').map((line) => line.trim()).includes(avdName)) return serial;
    } catch { /* Android ainda carregando; tentar novamente. */ }
  }
  return undefined;
}

async function ensureEmulator() {
  let serial = await connectedEmulator();
  if (!serial) {
    const devices = await run(adb, ['devices']);
    if (!/emulator-\d+\s+offline/.test(devices.stdout)) {
      console.log('Abrindo emulador Android...');
      const child = spawn(emulator, ['-avd', avdName, '-no-snapshot'], {
        detached: true, stdio: 'ignore', windowsHide: true,
      });
      child.on('error', () => console.error('Falha ao abrir o emulador Android.'));
      child.unref();
    }
    console.log('Aguardando o Android carregar (pode levar alguns minutos)...');
  }
  for (let i = 0; i < 90; i++) {
    serial ??= await connectedEmulator();
    if (serial) {
      try {
        const boot = await run(adb, ['-s', serial, 'shell', 'getprop', 'sys.boot_completed']);
        if (boot.stdout.trim() === '1') {
          const opened = await run(adb, ['-s', serial, 'shell', 'am', 'start', '-n',
            'com.example.fisio_360/.MainActivity']);
          if (/Error type|Error:/.test(opened.stdout + opened.stderr)) {
            throw new Error('Fisio 360 não está instalado neste emulador.');
          }
          console.log('Fisio 360 aberto no emulador. Use Alt+Tab para localizar a janela.');
          return;
        }
      } catch (error) {
        if (error.message.includes('não está instalado')) throw error;
      }
    }
    await sleep(2000);
  }
  throw new Error('O Android ainda não terminou de iniciar. Aguarde a janela e tente de novo.');
}

try {
  if (process.argv.includes('--check')) {
    console.log(`Node: ${process.version}`);
    console.log(`Configuração visível: ${dataDir ? 'SIM' : 'NÃO'}`);
    if (dataDir) console.log(`Pasta da configuração: ${dataDir}`);
    console.log(`API disponível: ${await apiReady() ? 'SIM' : 'NÃO'}`);
    for (const p of candidates) console.log(`Pasta verificada: ${p}`);
  } else {
    await ensureServices();
    await ensureEmulator();
    if (apiProcess) console.log('Mantenha este terminal aberto. Ctrl+C encerra a API iniciada aqui.');
  }
} catch (error) {
  console.error(`\nNão foi possível concluir: ${error.message}`);
  if (apiProcess && apiProcess.exitCode === null) apiProcess.kill();
  process.exitCode = 1;
}

process.on('SIGINT', () => {
  if (apiProcess && apiProcess.exitCode === null) apiProcess.kill();
  process.exit(0);
});
