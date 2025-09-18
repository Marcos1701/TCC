# Front - GenApp

App Flutter que entrega o visual neon escuro planejado, dashboards financeiros, missões gamificadas e fluxo seguro de autenticação.

## Requisitos
- Flutter 3.24+
- Dart 3.5+

## Rodando
```bash
flutter pub get
flutter run
```

## O que o app cobre
- **Dashboard inicial** com saldo, distribuição por categoria, série temporal de TPS/RDR e diagnósticos rápidos.
- **Transações** com filtros, criação via bottom sheet e suporte a receitas, despesas e dívidas.
- **Missões** personalizadas seguindo o algoritmo do documento (redução de RDR, aumento de TPS, educação financeira).
- **Progresso** exibindo metas financeiras, barra de XP, evolução mensal e badges desbloqueadas.
- **Perfil** para ajuste das metas de TPS/RDR, revisão dos dados pessoais e logout.

## Paleta e fragmentação visual
| Camada | Cor | Uso principal |
| ------ | --- | ------------- |
| Fundo base | `#080B1A` | plano de fundo global e modais |
| Cartões | `#11162B` / `#1A1F36` | blocos de conteúdo, listas e formulários |
| Primária | `#1D6FFF` | CTAs principais, destaque de metas e gráficos positivos |
| Secundária | `#8B5CF6` | missões, badges e elementos lúdicos |
| Acento | `#22D3EE` | detalhes interativos, tooltips e tabs |
| Sucesso | `#34D399` | conquistas de TPS/missões |
| Alerta | `#FF6B6B` e `#FBBF24` | diagnósticos críticos e avisos |

Bordas arredondadas (24–28 px), gradientes azul/roxo e tipografia Manrope garantem contraste alto no modo escuro.

## Navegação principal
1. **Onboarding/Autenticação** – telas escuras com chamadas diretas, alinhadas ao foco em autonomia e segurança.
2. **Home** – cartões de saldo, resumo de categorias, gráfico mensal, insights TPS/RDR e lista de missões ativas.
3. **Transações** – extrato filtrável, botões rápidos e visual em cartões conforme referência.
4. **Missões** – progresso editável, metas de curto/médio prazo e instruções educativas.
5. **Progresso** – evolução mensal, metas atingidas e badges conquistadas.
6. **Perfil** – ajustes de metas financeiras, dados básicos e botão de saída.

A navegação inferior fixa com ícones arredondados mantém a jornada fluida e coerente com o protótipo Figma.

## Principais pacotes
- `dio`: cliente HTTP com interceptador para refresh de token.
- `flutter_secure_storage`: guarda tokens JWT conforme requisitos de segurança.
- `fl_chart`: gráficos para série temporal e comparativos.
- `intl`: formatação de moedas e datas no padrão brasileiro.
- `google_fonts`: aplica a família Manrope em todo o tema.
