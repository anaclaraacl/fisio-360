# Fisio 360

Aplicativo Flutter para um profissional gerenciar pacientes e atendimentos, com API HTTPS e PostgreSQL locais. **Ainda não cadastre pacientes reais:** confirme as condições de segurança em docs/BACKEND.md antes do primeiro registro.

Para abrir banco, API, emulador e app pelo VS Code, abra esta pasta e pressione **Ctrl+Shift+B**. A tarefa **Fisio 360: iniciar app** verifica os serviços e abre o app instalado. Veja [docs/INICIAR_EMULADOR.md](docs/INICIAR_EMULADOR.md).

## O que está implementado

- Login e cadastro de profissional na API local, sessão com token de acesso curto e renovação em armazenamento seguro do Android.
- Lista, detalhe, cadastro e edição de pacientes persistidos no PostgreSQL.
- Agenda, cadastro e edição de atendimentos persistidos no PostgreSQL.
- Formulários validados, navegação, carregamento e mensagens de erro.
- HTTPS com certificado local incluído no app, sem liberar HTTP.
- API com controle de acesso por profissional, limite de tentativas de login, validação de entradas e auditoria.

## Pré-requisitos deste computador

- Flutter em C:\src\flutter, Android SDK em C:\src\android-sdk e JDK 17.
- Node.js 24 e PostgreSQL portátil em C:\src\postgresql\pgsql.
- Nesta instalação, os arquivos privados estão fisicamente em `%USERPROFILE%\AppData\Local\Packages\OpenAI.Codex_2p2nqsd0c76g0\LocalCache\Local\Fisio360`, devido à virtualização de AppData do pacote Windows. O guia mostra como abrir essa pasta. Preserve e migre esses dados antes de remover o Codex.
- Certificado público em assets\certs\local-api.pem; chave privada, credenciais e `postgres-data` ficam no diretório privado acima. O backend aceita FISIO_DATA_DIR explícito e também procura a instalação convencional em `%USERPROFILE%\AppData\Local\Fisio360`. **Não compartilhe esses arquivos privados.**

## Iniciar o sistema

No PowerShell, na pasta do projeto:

    .\backend\scripts\start-local.ps1
    cd backend
    npm.cmd start

O primeiro comando inicia o banco. Se ele já estiver ativo, não o execute de novo. Deixe npm.cmd start aberto. Na tela de login do app, use **Não tenho conta · Criar acesso** para cadastrar um profissional. Cada conta vê apenas os próprios pacientes e atendimentos. Também é possível criar uma conta pelo comando administrativo local `npm.cmd run create-admin`, na pasta backend; a senha precisa ter pelo menos 12 caracteres e é digitada sem aparecer na tela. No PowerShell, use npm.cmd para evitar o bloqueio do arquivo npm.ps1 pela política de execução; não é necessário alterar a política do Windows.

No terminal da raiz do projeto, com o emulador Android aberto:

    flutter pub get
    flutter run

A API escuta em 127.0.0.1:8443; o emulador a alcança por https://10.0.2.2:8443. O app no Chrome não é suportado nesta versão. Para parar o banco, encerre a API e rode .\backend\scripts\stop-local.ps1.

## Desenvolvimento e distribuição

Na pasta backend:

    npm.cmd run build
    npm.cmd run migrate

Na raiz:

    flutter build apk --debug

O APK de depuração fica em build\app\outputs\flutter-apk\app-debug.apk. **Não distribua esse APK para uso com pacientes reais.** Neste computador, use `.\backend\scripts\build-release.ps1 -BuildType debug` para compilar a versão de teste em um caminho temporário sem acentos; o resultado será copiado para `dist\Fisio360-debug.apk`. Para gerar o APK assinado, execute `.\backend\scripts\build-release.ps1`; o resultado será copiado para `dist\Fisio360-release.apk`. As versões de teste e assinada usam assinaturas diferentes e não se atualizam mutuamente no mesmo emulador.

Para criar um backup criptografado, na pasta backend execute npm.cmd run backup -- create CAMINHO_DO_ARQUIVO. Para conferir a restauração em um banco temporário execute npm.cmd run backup -- verify CAMINHO_DO_ARQUIVO. A frase de proteção é solicitada no terminal e não é salva. Guarde o arquivo em outro dispositivo e preserve a frase em local separado. Um backup do banco vazio foi restaurado e conferido; dados reais exigem conferência adicional.

## Telas e responsáveis

- lib/screens/login_screen.dart — Ana Clara Camargos Lima
- lib/screens/register_screen.dart — Ana Clara Camargos Lima
- lib/screens/home_screen.dart e lib/screens/patient_detail_screen.dart — Pedro Cunha Silva
- lib/screens/patient_form_screen.dart e lib/screens/appointment_form_screen.dart — Felipe Frade
