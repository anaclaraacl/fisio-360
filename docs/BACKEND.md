# Backend do Fisio 360

## Decisões desta versão

**Localização confirmada nesta instalação:** os dados foram gravados sob `%USERPROFILE%\AppData\Local\Packages\OpenAI.Codex_2p2nqsd0c76g0\LocalCache\Local\Fisio360`, devido à virtualização de AppData do aplicativo Codex no Windows. O caminho lógico `AppData\Local\Fisio360` não aparece no Explorador normal. O backend e os iniciadores procuram ambos os caminhos. Antes de remover o Codex ou adotar essa instalação com dados reais, preserve e migre o armazenamento para uma pasta própria com recuperação conferida. A correção de caminhos não moveu os registros.

- Um profissional usará o sistema inicialmente; outras contas locais ficam isoladas por usuário.
- O servidor e o banco ficarão no computador da profissional.
- O app no emulador Android acessará esse servidor local.
- O sistema deverá receber dados reais de pacientes somente depois de concluídas e conferidas as proteções abaixo.
- Não haverá acesso pela internet nem por outros celulares nesta primeira versão.

## Arquitetura

| Camada | Escolha | Responsabilidade |
| --- | --- | --- |
| App | Flutter existente | Login, pacientes, detalhes e agenda |
| API | Node.js LTS, TypeScript e Fastify | Validação, autenticação, autorização e regras |
| Banco | PostgreSQL local | Armazenamento persistente e transacional |
| Rede | HTTPS local | Tráfego entre emulador e computador |

O servidor escuta apenas na interface local do computador. O emulador alcança o loopback do computador pelo endereço `10.0.2.2`. Um certificado local terá `localhost` e `10.0.2.2` como nomes válidos. O app confiará somente no certificado previsto para esta instalação. Nunca usaremos uma aceitação irrestrita de certificados inválidos.

O app não se conectará diretamente ao PostgreSQL. A API verificará a identidade e a permissão antes de cada leitura ou alteração. A JSONPlaceholder será removida do fluxo antes da entrada de dados reais.

## Modelo de dados inicial

| Tabela | Campos principais |
| --- | --- |
| `users` | `id`, `email`, `password_hash`, `created_at`, `disabled_at` |
| `sessions` | `id`, `user_id`, hashes dos tokens, prazos de expiração, `revoked_at` |
| `patients` | `id`, `owner_user_id`, `full_name`, `birth_date`, `phone`, `treatment_goal`, `created_at`, `updated_at` |
| `appointments` | `id`, `owner_user_id`, `patient_id`, `starts_at`, `status`, `notes`, `created_at`, `updated_at` |
| `audit_events` | `id`, `actor_user_id`, `action`, `entity_type`, `entity_id`, `occurred_at` |

IDs serão UUIDs. Datas de atendimento serão armazenadas com fuso horário. O histórico de auditoria registrará quem fez cada operação, sem copiar informações clínicas para os logs. Campos adicionais só serão coletados quando houver necessidade definida.

## Contrato inicial da API

| Método e rota | Função |
| --- | --- |
| `POST /v1/auth/login` | Confere e-mail e senha e cria sessão |
| `POST /v1/auth/register` | Cria conta de profissional somente no servidor local e inicia sessão |
| `POST /v1/auth/refresh` | Renova sessão válida |
| `POST /v1/auth/logout` | Revoga a sessão |
| `GET /v1/me` | Retorna o profissional autenticado |
| `GET /v1/patients` | Lista até 100 pacientes do profissional, com busca pelo nome |
| `POST /v1/patients` | Cadastra paciente |
| `GET /v1/patients/{id}` | Retorna detalhe autorizado |
| `PATCH /v1/patients/{id}` | Atualiza dados autorizados |
| `GET /v1/appointments` | Lista até 100 atendimentos do profissional |
| `POST /v1/appointments` | Agenda atendimento |
| `PATCH /v1/appointments/{id}` | Altera data, estado ou observações |

O cadastro pelo app está disponível apenas enquanto o servidor permanece restrito ao computador e ao emulador. Não há verificação de posse do e-mail nesta versão local; antes de oferecer acesso pela internet, será necessário rever o cadastro e adicionar verificação e controles adequados. A primeira conta também pode ser criada por um comando administrativo local. Toda rota de paciente e atendimento exigirá autenticação e verificará o `owner_user_id` no servidor; conhecer um ID não dá acesso ao registro.

## Autenticação no app

- Senhas terão hash com Argon2id no servidor; senha em texto não será armazenada.
- O token de acesso terá vida curta. O token de renovação será rotacionado e armazenado no banco apenas como hash.
- O Flutter guardará o token de renovação no armazenamento seguro do sistema, nunca em `SharedPreferences`.
- O login demonstrativo foi removido. Não são criados dados clínicos de exemplo no banco real.
- O servidor limitará tentativas de login e respostas de erro não revelarão se um e-mail existe.

## Condições antes de usar dados reais

1. Ativar a criptografia da unidade C: e confirmar que a proteção está ligada e a criptografia concluída. A captura de tela enviada em 29/10/2026 mostra "C: BitLocker desligado". Guardar a chave de recuperação fora do projeto e confirmar a proteção da conta Windows.
2. Confirmar que o PostgreSQL instalado escuta apenas em 127.0.0.1 e que as credenciais exclusivas da API permanecem privadas.
3. Configurar HTTPS local e validar o certificado no app. O emulador não usará `HTTP` liberado nem ignorará erros de certificado para dados reais.
4. Usar o APK de lançamento assinado, sem logs de dados clínicos. Evitar snapshots do emulador que copiem dados para arquivos não protegidos. Guardar uma cópia segura da chave Android, necessária para atualizar o app.
5. Criar backup criptografado periódico do banco e conferir uma restauração. Guardar a frase de proteção separada do arquivo e manter uma cópia em outro dispositivo. Definir por quanto tempo os dados serão retidos.
6. Definir aviso de privacidade, fundamento adequado para tratamento e processo para atender solicitações dos titulares, com orientação profissional sobre LGPD e registros clínicos.
7. Conferir autenticação, autorização por registro, validação de entrada e trilha de auditoria antes de inserir o primeiro paciente real.

## Estado da implementação

1. API, migração, banco local e certificado HTTPS foram criados; não há pacientes no banco por padrão.
2. O Flutter foi ligado à API para login, pacientes e agenda, incluindo edição de pacientes e atendimentos. A JSONPlaceholder saiu do fluxo.
3. Armazenamento seguro do token, limite de tentativas e auditoria estão implementados. O APK de depuração compila.
4. A chave privada de assinatura Android foi criada fora do projeto. O APK de lançamento foi compilado e a assinatura conferida. O backup criptografado e sua restauração em banco temporário foram verificados com o banco ainda vazio.
5. A conta inicial do profissional já foi criada. Ainda faltam a conferência da criptografia do computador e uma rotina periódica de backup para uso continuado. A recuperação deve ser testada novamente depois de haver dados relevantes.
6. O app agora oferece cadastro de novas contas locais com confirmação de senha; cada conta recebe registros próprios.
7. Só cadastre pacientes reais depois de conferir todas as condições da seção anterior.

## Fontes técnicas

- [ANPD: guia de segurança para agentes de pequeno porte](https://www.gov.br/anpd/pt-br/centrais-de-conteudo/materiais-educativos-e-publicacoes/guia-vf.pdf)
- [OWASP: riscos de segurança em APIs](https://api-security.owasp.org/editions/2023/en/0x11-t10/)
- [Android: endereço do computador visto pelo emulador](https://developer.android.com/studio/run/emulator-networking-address)
