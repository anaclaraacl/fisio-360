# Fisio 360 — consulta rápida para a apresentação

## 1. Iniciar banco, API, emulador e app

1. No VS Code, abra a pasta do projeto:
   `C:\Users\Mainô\Documents\ChatGPT\Fisio 360`
2. Pressione **Ctrl+Shift+B**. Se aparecer uma lista, escolha **Fisio 360: iniciar app**.
3. Aguarde **Fisio 360 aberto no emulador** e use **Alt+Tab** para localizar o Android.
4. Mantenha o terminal da API aberto durante o uso.

## 2. Caminho do banco

Pasta física do PostgreSQL neste computador:

```text
C:\Users\Mainô\AppData\Local\Packages\OpenAI.Codex_2p2nqsd0c76g0\LocalCache\Local\Fisio360\postgres-data
```

Para encontrar a pasta no Explorador: **Ctrl+L**, cole o caminho acima e pressione **Enter**.

- Banco: `fisio360`
- Endereço: `127.0.0.1` · porta: `5433`
- Arquivo que define as tabelas:
  `C:\Users\Mainô\Documents\ChatGPT\Fisio 360\backend\sql\001_initial.sql`

## 3. Caminho da API

- Pasta: `C:\Users\Mainô\Documents\ChatGPT\Fisio 360\backend`
- Rotas, login e regras de acesso:
  `C:\Users\Mainô\Documents\ChatGPT\Fisio 360\backend\src\server.ts`
- Conexão com o banco:
  `C:\Users\Mainô\Documents\ChatGPT\Fisio 360\backend\src\db.ts`
- Endereço no computador: `https://localhost:8443`
- Endereço usado pelo emulador: `https://10.0.2.2:8443`

## 4. Caminho das telas

Todas ficam nesta pasta:

```text
C:\Users\Mainô\Documents\ChatGPT\Fisio 360\lib\screens
```

| Tela | Arquivo | O que mostrar |
| --- | --- | --- |
| Login | `login_screen.dart` | Validação, entrada pela API e olho da senha |
| Criar conta | `register_screen.dart` | Cadastro do profissional e confirmação da senha |
| Home | `home_screen.dart` | Saudação, resumo, pacientes e cores dos atendimentos |
| Cadastrar/editar paciente | `patient_form_screen.dart` | Campos e envio das alterações |
| Detalhe do paciente | `patient_detail_screen.dart` | Consulta dos dados e botão de edição |
| Cadastrar/editar atendimento | `appointment_form_screen.dart` | Paciente, data, horário, observações e situação |

No VS Code, pressione **Ctrl+P** e digite o nome do arquivo para abri-lo rapidamente. Procure **APRESENTAÇÃO:** no código para encontrar as explicações.

Entrada do app e tema azul:
`C:\Users\Mainô\Documents\ChatGPT\Fisio 360\lib\main.dart`

## 5. Slides e roteiro

- Apresentação com prints:
  `C:\Users\Mainô\Documents\ChatGPT\Fisio 360\apresentacao\Fisio360-apresentacao-integracoes.pptx`
- Roteiro de fala:
  `C:\Users\Mainô\Documents\ChatGPT\Fisio 360\docs\ROTEIRO_APRESENTACAO.md`

Use dados fictícios ao apresentar. Para encerrar, feche o emulador e pressione **Ctrl+C** no terminal que iniciou a API.
