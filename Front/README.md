# Front - GenApp

App Flutter com as telas estilizadas do GenApp.

## Requisitos

- Flutter 3.24+
- Dart 3.5+

## Rodando

```bash
flutter pub get
flutter run
```

## Paleta e fragmentação visual

| Camada | Cor | Uso principal |
| ------ | --- | ------------- |
| Fundo base | `#080B1A` | plano de fundo global e modais |
| Cartões | `#11162B` / `#1A1F36` | blocos de conteúdo, listas e formulários |
| Primária | `#1D6FFF` | botões cheios, gráficos principais e indicadores positivos |
| Secundária | `#8B5CF6` | destaques de missões e badges |
| Acento | `#22D3EE` | gráficos auxiliares e detalhes interativos |
| Alerta | `#FF6B6B` e `#FBBF24` | avisos e limites |

Elementos seguem bordas arredondadas (24–28 px), gradientes azul/roxo nos destaques e contraste alto nos textos para manter a leitura em modo escuro.

## Fluxo de telas

1. **Login / Cadastro** – telas escuras com campos preenchidos, botão principal em azul e navegação rápida entre telas.
2. **Home** – cards com saldo, resumo de categorias, série temporal e blocos de missões ativas e sugeridas.
3. **Transações** – lista filtrável, criação rápida via bottom sheet e exclusão com toque.
4. **Missões** – missões em andamento com progresso editável e sugestões alinhadas ao TPS/RDR.
5. **Progresso** – metas financeiras do usuário, barra de XP e gestão de objetivos com valores e prazos.
6. **Perfil** – bloco gradiente com dados do usuário, ajuste das metas de TPS/RDR e botão de logout.

Um bottom navigation fixo com ícones arredondados conduz pelas seções e mantém o app aderente ao layout das imagens de referência.

## Principais pacotes

- `dio`: cliente HTTP pra falar com a API Django.
- `flutter_secure_storage`: guarda tokens JWT no cofre do aparelho.
- `fl_chart`: gráficos pro dashboard financeiro.
- `intl`: formata valores e datas no padrão brasileiro.
- `google_fonts`: aplica a tipografia Manrope no tema escuro.
