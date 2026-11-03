# Roteiro de fala — Fisio 360

Tempo previsto: **10 minutos**, incluindo a demonstração. Os trechos entre aspas são sugestões de fala. Use os prints dos slides e registros fictícios no app.

## 1. Abertura — 30 segundos

“O Fisio 360 é um aplicativo Android em Flutter para organizar pacientes e atendimentos de fisioterapia. Nesta versão, construímos uma API própria e usamos um banco PostgreSQL local. Vamos mostrar o fluxo do aplicativo e explicar como essas partes se conectam.”

Apresente Ana Clara Camargos Lima, Pedro Cunha Silva e Felipe Frade. Descreva a contribuição real de cada integrante; esta versão foi desenvolvida com auxílio do Codex.

## 2. Problema e proposta — 30 segundos

“O profissional precisa consultar os dados do paciente e organizar os atendimentos. O Fisio 360 reúne essas atividades no mesmo fluxo. Pela Home, ele acompanha o resumo da rotina, encontra os pacientes e abre as opções de cadastro e edição.”

## 3. Home e cadastro de paciente — 40 segundos

“Depois do login, o usuário chega à Home. A saudação usa a primeira parte do e-mail. O resumo mostra as quantidades de pacientes e atendimentos. O cadastro de paciente recebe nome, nascimento, telefone e queixa ou objetivo do tratamento. Os formulários verificam os campos antes do envio.”

Aponte nos prints a lista e o formulário. As capturas foram feitas com uma cópia separada do app e dados fictícios, fornecidos por uma API temporária em memória. O app principal usa a API própria e o PostgreSQL descritos neste roteiro.

## 4. Login e cadastro de profissional — 1 minuto

“O cadastro de profissional recebe e-mail, senha e confirmação da senha. A senha precisa ter pelo menos 12 caracteres. O aplicativo envia a solicitação à nossa API, que valida o e-mail e registra a conta.”

“No login, a API consulta a conta e confere a senha. Se os dados estiverem corretos, ela devolve os tokens da sessão. O ícone de olho permite conferir a senha digitada. Ao sair, o app apaga a sessão local e solicita sua revogação ao servidor.”

Para localizar o código: `lib/screens/login_screen.dart`, `lib/screens/register_screen.dart` e `lib/services/api_service.dart`.

## 5. Consulta e edição de pacientes — 45 segundos

“Ao tocar em um paciente, o app consulta a API e mostra o detalhe atualizado. O botão Editar paciente abre o formulário com os valores existentes. Depois de salvar, a API atualiza o PostgreSQL e o aplicativo recarrega as informações.”

“O cadastro fica associado à conta do profissional. A API usa essa associação para limitar quais registros a conta pode consultar e alterar.”

Para localizar o código: `lib/screens/patient_detail_screen.dart` e `lib/screens/patient_form_screen.dart`.

## 6. Atendimentos — 45 segundos

“Cada atendimento fica vinculado a um paciente e recebe data, horário e observações. Na edição, podemos atualizar esses campos e a situação. O vínculo com o paciente permanece fixo.”

“Na listagem, concluído aparece em verde claro e cancelado em vermelho claro. Agendado mantém o visual anterior. A situação também fica escrita no item, para que sua identificação não dependa só da cor.”

Para localizar o código: `lib/screens/appointment_form_screen.dart` e `lib/screens/home_screen.dart`.

## 7. Integrações e arquitetura — 1 minuto e 40 segundos

“Construímos nossa própria API com Node.js, TypeScript e Fastify. O Node executa o servidor, o TypeScript organiza o código com tipos, e o Fastify define as rotas, valida as solicitações e envia as respostas.”

“No Flutter, o pacote http envia e recebe dados em JSON. Usamos GET para consultar, POST para cadastrar e entrar, e PATCH para editar. O aplicativo também mostra carregamento e mensagens quando uma solicitação falha.”

“A API usa o pacote pg para se conectar ao PostgreSQL. O banco guarda profissionais, sessões, pacientes, atendimentos e eventos de auditoria. Como esses registros ficam no banco, continuam disponíveis depois de fechar e reabrir o app. O Flutter acessa esses dados por meio da API.”

“Dentro do aplicativo, Provider e ChangeNotifier compartilham o AppState e atualizam as telas quando os dados mudam. SharedPreferences guarda preferências simples, como o último e-mail e o identificador do último paciente selecionado.”

“Tudo roda localmente: o emulador alcança a API pelo endereço 10.0.2.2, e o PostgreSQL fica no computador. A tarefa do VS Code inicia os serviços e abre o app.”

Para localizar o código: `backend/src/server.ts`, `backend/src/db.ts`, `backend/sql/001_initial.sql`, `lib/services/api_service.dart` e `lib/state/app_state.dart`.

## 8. Proteção dos dados — 1 minuto e 40 segundos

“A comunicação entre aplicativo e API usa HTTPS com um certificado local que o app reconhece. Isso protege o tráfego dessa conexão.”

“As senhas são armazenadas como hashes Argon2id. No login, a biblioteca confere a senha informada com o hash cadastrado.”

“A sessão tem dois tokens aleatórios: um de acesso, válido por 15 minutos, e um de renovação, com prazo de 30 dias. O app mantém o token de acesso na memória e guarda o de renovação no armazenamento seguro do Android, usando flutter_secure_storage. O servidor armazena hashes dos tokens e verifica sua validade.”

“As consultas conferem a conta dona de cada paciente ou atendimento. Também registramos eventos de auditoria, como login, consultas, cadastros e edições, com o usuário, a ação e o registro envolvido.”

“Há uma ferramenta manual de backup: ela exporta o banco com pg_dump e criptografa o arquivo com AES-256-GCM. A frase de proteção é digitada no terminal. A conferência restaura o arquivo em um banco temporário. Esse teste foi realizado anteriormente com uma base vazia; o backup é executado por comando, sem agendamento automático.”

Para localizar o código: `backend/src/server.ts`, `lib/services/api_service.dart` e `backend/src/backup.ts`.

## 9. Demonstração e encerramento — 2 minutos e 30 segundos

1. Abra a pasta Fisio 360 no VS Code e pressione **Ctrl+Shift+B**. Escolha **Fisio 360: iniciar app**, se aparecer uma lista.
2. Entre com uma conta de demonstração sem projetar a senha.
3. Mostre a Home e as situações dos atendimentos.
4. Abra um paciente fictício, edite um campo e salve.
5. Abra um atendimento fictício, altere a situação e salve. Volte à Home para mostrar a cor correspondente.

Encerre com:

“Nesta versão, o Fisio 360 já conecta a interface Flutter à nossa API e ao PostgreSQL. O fluxo permite criar uma conta, entrar, consultar pacientes e cadastrar ou editar pacientes e atendimentos. As integrações sustentam a persistência, a atualização das telas e o controle de acesso que acabamos de demonstrar.”

Se a demonstração ao vivo falhar, percorra os prints dos slides. O guia de consulta está em `docs/INICIAR_EMULADOR.md`.

## Consulta rápida das integrações

Esta tabela serve para estudar e responder perguntas; não é necessário lê-la inteira durante a apresentação.

| Integração ou recurso | O que usamos de fato | Onde conferir |
| --- | --- | --- |
| API própria | Node.js executa o backend; TypeScript fornece os tipos; Fastify define rotas e valida entradas. | `backend/src/server.ts` |
| Pacote http | Chamadas GET, POST e PATCH em JSON para login, cadastro, consulta e edição. | `lib/services/api_service.dart` |
| PostgreSQL e pacote pg | Persistência das contas, sessões, pacientes, atendimentos e auditoria; conexão por um pool local. | `backend/src/db.ts` e `backend/sql/001_initial.sql` |
| Provider e ChangeNotifier | AppState compartilhado; notifyListeners informa às telas quando o estado muda. | `lib/main.dart` e `lib/state/app_state.dart` |
| SharedPreferences | Último e-mail e identificador do último paciente selecionado. Os cadastros clínicos ficam no PostgreSQL. | `lib/state/app_state.dart` |
| flutter_secure_storage | Guarda o token de renovação no armazenamento seguro do Android. O token de acesso fica em memória. | `lib/services/api_service.dart` |
| HTTPS local | Certificado público incluído no app; chave privada no diretório de configuração. Protege o tráfego app–API. | `lib/services/api_service.dart` e `backend/src/server.ts` |
| Argon2id | Hash das senhas no cadastro e verificação no login. | `backend/src/server.ts` e `backend/src/create-admin.ts` |
| Tokens de sessão | Valores aleatórios; acesso de 15 minutos; renovação de 30 dias; hashes SHA-256 dos tokens no banco. A renovação troca os tokens. | `backend/src/server.ts` |
| Acesso por profissional | Token identifica a conta; filtros owner_user_id limitam leitura e alteração aos registros dessa conta. | `backend/src/server.ts` |
| Validação e limite de tentativas | Validação de campos no Flutter e de solicitações na API; login limitado a cinco tentativas por minuto e cadastro a três por hora. | Telas de formulário e `backend/src/server.ts` |
| Auditoria | Eventos de login, registro de conta, consultas, cadastros e edições são gravados em audit_events. A função registra identificadores e ação, sem copiar o conteúdo clínico para o evento. | `backend/src/server.ts` |
| Backup criptografado | Ferramenta manual: pg_dump, AES-256-GCM e chave derivada da frase com scrypt. A criptografia se aplica ao arquivo exportado. A restauração de uma base vazia foi conferida em banco temporário. | `backend/src/backup.ts` |
| Inicialização no VS Code | Tarefa chama Node diretamente, verifica banco/API, usa ADB para aguardar o Android e abrir o app instalado. | `.vscode/tasks.json` e `backend/scripts/start-vscode.mjs` |

Procure **APRESENTAÇÃO:** no VS Code para encontrar os comentários explicativos nos arquivos.
