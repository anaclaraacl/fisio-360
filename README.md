# Fisio 360 — documentação do projeto

## 1. Identificação

- **Aplicativo:** Fisio 360
- **Squad:** Fisio 360
- **Contato do squad:** anaclaracamargoslima@gmail.com
- **Curso/atividade:** Desenvolvimento para Ambientes Móveis — Flutter, entrega final da A3.

| Integrante | Matrícula | Responsabilidade registrada no projeto |
|---|---|---|
| Ana Clara Camargos Lima | 72501006 | Login e cadastro de acesso |
| Pedro Cunha Silva | 72501243 | Home e detalhe do paciente |
| Felipe Frade | 71801391 | Cadastro/edição de paciente e atendimento |

> Não publique senhas nem dados de pacientes neste documento.

## 2. Sobre o projeto

O Fisio 360 é um aplicativo Android para profissionais de fisioterapia organizarem pacientes e atendimentos. O público previsto é um profissional que usa o app em um computador Windows com um emulador Android. A pessoa entra com uma conta ou cria um acesso local. Na Home, consulta a lista de pacientes e os atendimentos. Pode abrir o detalhe de um paciente, cadastrar outro ou editar um cadastro existente. Também pode criar e editar atendimentos, escolhendo paciente, data, horário, observações e situação. O app envia os dados para uma API própria, que os grava em um banco PostgreSQL no mesmo computador. Esta versão funciona localmente e não sincroniza dados pela internet.

## 3. Requisitos atendidos

| Requisito do guia | Como é atendido | Onde conferir |
|---|---|---|
| Pelo menos quatro telas e navegação com `Navigator.push`/`pop` | Login, criar acesso, Home, detalhe do paciente, formulário de paciente e formulário de atendimento. | `lib/screens/` |
| API REST com `http` e operações assíncronas; dados não fixos | O app faz pedidos `GET`, `POST` e `PATCH` à API local. Pacientes e atendimentos vêm do PostgreSQL. | `lib/services/api_service.dart`, `backend/src/server.ts` |
| Carregamento e erros visíveis | A Home e o detalhe mostram carregamento e erros de conexão ou resposta. Os formulários mostram mensagens quando o envio falha. | `lib/screens/home_screen.dart`, `lib/screens/patient_detail_screen.dart` |
| Formulários com `Form` e `validator` | Login, criação de conta, paciente e atendimento validam os campos antes do envio; a API também valida os dados recebidos. | `lib/screens/login_screen.dart`, `register_screen.dart`, `patient_form_screen.dart`, `appointment_form_screen.dart` |
| Lista dinâmica com `ListView.builder` | A Home desenha a lista a partir dos pacientes recebidos da API. | `lib/screens/home_screen.dart` |
| `SharedPreferences` mantém dados ao reabrir | Guarda o último e-mail e o identificador do último paciente selecionado. Os dados clínicos persistem no PostgreSQL, não nas preferências. | `lib/state/app_state.dart` |
| Provider separa telas, API e preferências | As telas observam o estado compartilhado; `AppState` coordena os dados e `ApiService` concentra as chamadas da API. | `lib/main.dart`, `lib/state/app_state.dart`, `lib/services/api_service.dart` |
| App abre e percorre o fluxo sem crash | O grupo já confirmou o uso no emulador. Antes da apresentação, repetir o fluxo abaixo com a API disponível. | Login → Home → paciente/detalhe → atendimento; fechar e reabrir para demonstrar persistência |

## 4. API e dados

Esta entrega usa uma **API própria e local**. Não depende de API pública, não usa chave de API e não inclui uma conta de demonstração pré-criada. Crie uma conta pela opção **Não tenho conta · Criar acesso**. Para demonstrações e avaliações, use dados fictícios.

| Onde o app roda | Endereço base |
|---|---|
| Computador Windows | `https://localhost:8443` |
| Emulador Android | `https://10.0.2.2:8443` |

O endereço do emulador `10.0.2.2` aponta para o computador que hospeda o servidor. A API aceita HTTPS e usa o certificado local incluído no app. O servidor escuta apenas no próprio computador.

| Método e rota | Função |
|---|---|
| `POST /v1/auth/register` | Criar uma conta local |
| `POST /v1/auth/login` | Entrar |
| `POST /v1/auth/refresh` | Renovar uma sessão válida |
| `POST /v1/auth/logout` | Encerrar uma sessão |
| `GET /v1/me` | Consultar a conta conectada |
| `GET /v1/patients` | Listar até 100 pacientes da conta; aceita busca pelo nome |
| `POST /v1/patients` | Cadastrar paciente |
| `GET /v1/patients/{id}` | Consultar um paciente da conta |
| `PATCH /v1/patients/{id}` | Editar paciente |
| `GET /v1/appointments` | Listar até 100 atendimentos da conta |
| `POST /v1/appointments` | Cadastrar atendimento |
| `PATCH /v1/appointments/{id}` | Editar data, situação ou observações |

O cadastro exige uma senha de 12 a 128 caracteres. A API guarda uma versão protegida da senha, limita tentativas e verifica que cada conta acesse apenas seus próprios registros. A validação do endereço de e-mail é sintática; não há envio de mensagem para confirmar que a pessoa é dona do endereço.

## 5. Como executar

### Ambiente previsto

- Windows 10/11.
- Flutter **3.44.0 ou posterior** e Dart **3.12.0 ou posterior**, conforme os requisitos das dependências Android resolvidas neste projeto.
- Android SDK, ferramentas de plataforma e um emulador Android. O emulador configurado neste computador chama-se `Fisio360_API36` (Android API 36).
- Java/JDK 17.
- Node.js 24 e PostgreSQL local.
- Para o atalho atual do VS Code, os executáveis precisam estar nos caminhos descritos na seção 6, ou os scripts precisam ser ajustados.

O alvo desta entrega é **Android**. A versão atual não oferece suporte ao Chrome. Não foi preparado nem validado um serviço para uso em iPhone.

### Preparação inicial em um computador novo

Os scripts desta versão foram configurados para o ambiente Windows deste projeto. Antes de executá-los, instale os pré-requisitos e confira os caminhos fixos da seção 6.

1. Na raiz do projeto, abra o PowerShell e inicialize o banco local uma única vez:

   ```powershell
   .\backend\scripts\setup-local.ps1
   ```

2. Instale as dependências da API e crie um certificado local para esse computador:

   ```powershell
   Set-Location .\backend
   npm.cmd ci
   npm.cmd run setup-tls
   npm.cmd run build
   npm.cmd run migrate
   ```

   A geração do certificado altera `assets/certs/local-api.pem` para corresponder à chave privada desse computador. Reconstrua o app depois dessa etapa. Não compartilhe a chave privada nem credenciais.

3. Em um terminal na pasta `backend`, inicie a API:

   ```powershell
   npm.cmd start
   ```

   Mantenha esse terminal aberto. A API usa a porta `8443`.

4. Em outro terminal, na raiz do projeto, prepare e execute o app no emulador:

   ```powershell
   flutter pub get
   flutter run
   ```

   O comando `flutter run` compila e instala o app no emulador selecionado. A API e o banco precisam estar funcionando.

### Iniciar novamente neste computador

Depois da preparação inicial, pressione **Ctrl+Shift+B** no VS Code e escolha **Fisio 360: iniciar app**. Essa tarefa inicia o banco e a API locais e abre o app que já está instalado no emulador deste computador. Em uma instalação nova, use primeiro a preparação acima; a tarefa não configura o banco nem instala o app.

Para encerrar, pressione **Ctrl+C** no terminal da API e, na raiz do projeto, execute:

```powershell
.\backend\scripts\stop-local.ps1
```

## 6. Backend local

O backend tem três partes: um servidor Node.js/Fastify que recebe os pedidos do app, uma API HTTPS que valida e autoriza cada operação e um banco PostgreSQL local. O app comunica-se com o servidor; somente o servidor comunica-se com o PostgreSQL.

- **Caminhos esperados pelos iniciadores deste computador:** Flutter `C:\src\flutter`, Android SDK `C:\src\android-sdk`, PostgreSQL `C:\src\postgresql\pgsql` e Node.js `C:\Program Files\nodejs\node.exe`. A tarefa do VS Code também espera o emulador `Fisio360_API36`. Se os programas estiverem em outros locais, ajuste `.vscode/tasks.json` e `backend/scripts/start-vscode.mjs`.
- **Banco:** PostgreSQL; tabelas definidas em `backend/sql/001_initial.sql`.
- **Servidor e rotas:** `backend/src/server.ts`.
- **Conexão com o banco:** `backend/src/db.ts`.
- **Configuração privada:** `backend.env`, `postgres-admin.env`, chave privada TLS e dados do banco ficam fora do repositório, no diretório local do Fisio 360. Não envie esses arquivos ao GitHub.
- **Porta:** `8443` para a API e `5433` para o PostgreSQL deste ambiente.
- **Inicialização do banco:** `backend/scripts/setup-local.ps1` (somente na primeira configuração) e `backend/scripts/start-local.ps1` (inicializações seguintes).
- **Encerramento do banco:** `backend/scripts/stop-local.ps1`.

O app registra e autentica profissionais localmente. As rotas de paciente e atendimento exigem uma sessão válida e filtram os registros pela conta conectada. A migração do banco é executada com `npm.cmd run migrate` na pasta `backend`.

O backup criptografado é manual. Na pasta `backend`, execute `npm.cmd run backup -- create CAMINHO_DO_ARQUIVO`; para conferir a restauração em um banco temporário, execute `npm.cmd run backup -- verify CAMINHO_DO_ARQUIVO`. O programa solicita uma frase de proteção de pelo menos 16 caracteres. Guarde a frase separada do arquivo de backup.

## 7. Estrutura do código

```text
lib/
  main.dart                 entrada do app, tema e Provider
  screens/                  login, Home, pacientes e atendimentos
  services/api_service.dart comunicação HTTPS com a API
  state/app_state.dart      estado compartilhado e preferências locais
  models/                   formatos de paciente e atendimento
backend/
  src/server.ts             rotas, validações, autenticação e regras
  src/db.ts                 conexão PostgreSQL
  src/backup.ts             backup protegido e conferência de restauração
  sql/                      criação e evolução das tabelas
  scripts/                  inicialização e manutenção locais
docs/                       instruções do backend e do emulador
assets/certs/               certificado público usado pelo app
apresentacao/               slides e capturas de tela
```

## 8. Observações e limitações

- A API só atende este computador e o emulador conectado a ele. Não há publicação na internet, sincronização em nuvem nem acesso de vários dispositivos.
- Não há confirmação de e-mail, recuperação de senha, exclusão de paciente/atendimento nem backup automático.
- O backup é manual. A conferência de restauração registrada no projeto foi feita com o banco vazio; uma restauração de dados importantes ainda precisa ser testada.
- O registro de configuração disponível indica que a criptografia da unidade C: estava desligada. O projeto, por si só, não ativa a criptografia do Windows nem protege cópias feitas pelo emulador.
- Esta versão é uma entrega acadêmica local; suas proteções de software não equivalem a uma avaliação completa de segurança ou preparação para uso clínico com dados reais. Use dados fictícios na avaliação e não coloque registros, senhas, tokens ou chaves no repositório.
- Funcionalidades adicionais presentes: cadastro de conta, mostrar/ocultar senha no login, edição de pacientes e atendimentos, cores por situação e saudação pelo primeiro nome do e-mail.
- O repositório GitHub é privado. Dê acesso ao professor antes de enviar o link; se isso não for possível, entregue um ZIP pelo canal indicado. Não inclua `build/`, `.dart_tool/`, APKs, banco local ou arquivos de credenciais.

Documentação complementar: [iniciar o emulador](docs/INICIAR_EMULADOR.md) e [detalhes do backend](docs/BACKEND.md).
