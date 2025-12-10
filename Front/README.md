# GenApp Mobile - Frontend

Este repositório contém o código-fonte do aplicativo móvel **GenApp**, desenvolvido em **Flutter**. O projeto compõe a parte da interface do usuário do Trabalho de Conclusão de Curso (TCC) para o curso de Tecnologia em Análise e Desenvolvimento de Sistemas do IFPI.

O aplicativo oferece uma interface gamificada para gerenciamento financeiro pessoal, integrando controle de transações, gráficos de análise e um sistema de missões.

## Tecnologias Utilizadas

- **Framework:** Flutter 3.24+
- **Linguagem:** Dart 3.5+
- **Gerenciamento de Estado:** Nativo (ChangeNotifier/InheritedWidget) e Provider pattern
- **Comunicação HTTP:** Dio
- **Armazenamento Seguro:** Flutter Secure Storage

## Configuração do Ambiente

### 1. Pré-requisitos
- Flutter SDK instalado e configurado no PATH.
- Android Studio ou VS Code configurados com plugins do Flutter/Dart.
- Dispositivo físico ou emulador (Android/iOS).

### 2. Instalação das Dependências

Na raiz do projeto `Front`, execute:

```bash
flutter pub get
```

### 3. Configuração da API

Crie um arquivo `.env.local` na raiz (se necessário) para definir o endereço da API. Por padrão, o app pode apontar para `localhost` ou para um servidor de desenvolvimento.

```ini
API_BASE_URL=http://10.0.2.2:8000  # Para emulador Android acessando localhost do PC
# ou
API_BASE_URL=http://localhost:8000 # Para web/desktop
```

### 4. Execução

Para rodar o aplicativo em modo de depuração:

```bash
flutter run --dart-define-from-file=.env.local
```

## Estrutura Visual

O projeto segue um guia de estilos definido para garantir consistência e usabilidade:

- **Cores**: Azul Institucional (Navegação), Amarelo (Destaques), Verde (Sucesso), Vermelho (Erros).
- **Tipografia**: Família Montserrat (Google Fonts).

## Funcionalidades Principais

- **Login e Cadastro:** Autenticação segura via JWT.
- **Home:** Visão geral de saldo e missão ativa.
- **Transações:** Registro e listagem de receitas e despesas.
- **Análises:** Gráficos e indicadores financeiros (TPS, RDR, ILI).
- **Missões:** Interface gamificada para acompanhamento de desafios.
