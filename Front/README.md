# Front - GenApp

App Flutter com as telas estilizadas do GenApp.

## Requisitos

- Flutter 3.24+
- Dart 3.5+

## Rodando

```bash
cp .env.local.example .env.local   # ajuste a URL da API, se necessário
flutter pub get
flutter run --dart-define-from-file=.env.local
```

Para execução web ou builds de produção, atualize `API_BASE_URL` dentro do arquivo `.env.local` (ou gere outro arquivo `.env` específico) apontando para o host público da API.

## Paleta e fragmentação visual

| Camada / Papel | Cor | Uso principal |
| -------------- | --- | ------------- |
| Azul institucional | `#034EA2` | navegação, botões primários, links ativos |
| Amarelo vibrante | `#FDB913` | botões secundários, badges, hovers |
| Verde institucional | `#007932` | confirmações, indicadores positivos |
| Vermelho energético | `#EF4123` | alertas, mensagens de erro |
| Fundo base | `#F5F5F5` | planos de fundo neutros |
| Superfícies | `#FFFFFF` / `#E8EFF8` | cartões, formulários, destaques |
| Texto principal | `#231F20` | títulos e conteúdos |
| Texto secundário | `#666666` | descrições, legendas |
| Bordas | `#CCCCCC` | divisórias discretas |

- Tipografia Montserrat (Google Fonts) nas variações 300–800.
- Grid baseado em múltiplos de 8/16 px, com cartões usando padding interno de 16/32 px.
- Botões têm raio de 14 px e variação de cor (~20%) para estados hover/active.

## Fluxo de telas

1. **Login / Cadastro** – gradiente azul institucional, validação com vermelho energético.
2. **Home** – cards com saldo, categorias, série temporal e missões em destaque.
3. **Transações** – lista filtrável, criação via bottom sheet e exclusão rápida.
4. **Missões** – progresso em tempo real e recomendações alinhadas ao TPS/RDR.
5. **Progresso** – metas financeiras, barra de XP e objetivos com valores/prazos.
6. **Perfil** – ajuste de metas TPS/RDR, dados pessoais e logout seguro.

Bottom navigation com ícones arredondados mantém a navegação consistente com o guia visual.

## Principais pacotes

- `dio`: cliente HTTP com interceptors para renovação dos JWTs.
- `flutter_secure_storage`: armazena tokens no cofre nativo (Keychain/Keystore).
- `fl_chart`: gráficos do dashboard financeiro.
- `intl`: formatação de valores e datas PT-BR.
- `google_fonts`: aplica Montserrat ao tema claro/escuro.
