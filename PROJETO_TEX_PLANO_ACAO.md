# Plano de Ação para Atualização do `projeto.tex` (GenApp)

Este plano assegura que as futuras alterações no documento LaTeX mantenham consistência estilística, estrutural e lógica com o conteúdo já existente, enquanto incorpora os componentes técnicos reais do sistema.

---

## 1. Escopo

Objetivo: Atualizar o relatório técnico (`projeto.tex`) para refletir fielmente a implementação do GenApp sem descaracterizar a estrutura acadêmica já elaborada.

Abrange:

- Correções conceituais (MVC → MTV; hash de senhas; funcionalidades não implementadas)
- Inclusão de novas seções técnicas (IA Gemini, Celery/Redis, Snapshots, Cache de Indicadores, Vinculação de Transações)
- Ajuste de fórmulas dos índices TPS, RDR, ILI
- Consolidação da seção de Segurança
- Formalização de limitações e trabalhos futuros

Fora do escopo neste ciclo:

- Revisão textual geral de capítulos teóricos já adequados (Introdução, Fundamentação)
- Reformulação de objetivos ou cronograma

---

## 2. Mapeamento de Pontos de Inserção

| Bloco Agrupado | Localização Proposta | Conteúdos Enxutos | Forma |
|----------------|----------------------|------------------|-------|
| Arquitetura e Processamento | Capítulo Tecnologias/Arquitetura | MTV do backend (correção de MVC), Celery/Redis, Snapshots, Cache | Seção única com 3-4 parágrafos + 1 tabela de tasks |
| IA e Gamificação | Capítulo Tecnologias (após Arquitetura) | Gemini para missões, cenários/tiers, controle de custos | Seção única; mover prompt detalhado para Apêndice |
| Indicadores e Vinculação de Transações | Capítulo de Métricas/Resultados | Fórmulas TPS/RDR/ILI revisadas; "pagamentos de despesas"; diagrama Receita→Link→Despesa | Seção única com 1 equação, 1 diagrama e 1 nota metodológica |
| Segurança e Deploy | Capítulo Implementação/Considerações | Hash padrão Django, JWT, armazenamento seguro no app, nota Railway (validação) | Seção única de 4-6 bullets |
| Testes e Trabalhos Futuros | Após Resultados ou antes de Conclusão | Sumário de testes existentes e planejar próximos; limitações | Seção única + tabela breve |

---

## 3. Padrões de Escrita e Estilo

- Tom: Técnico-acadêmico, objetivo, evitar marketing.
- Terminologia: "aplicativo" (não "app"), "usuário", "indicadores", "missões".
- Estrutura de seções segue hierarquia: `\chapter` > `\section` > `\subsection` > `\subsubsection`.
- Fórmulas em ambiente `equation` ou inline matemático quando simples.
- Figuras com: `\begin{figure}[H]` + `\caption{}` + `\label{}`.
- Tabelas: `tabularx` ou `tabular` com legenda e label.
- Citações: manter estilo IEEE (`\cite{}`) onde ampliar justificativas (ex: métricas financeiras).
- Evitar primeira pessoa; usar construções impessoais.
- Glossário técnico já criado: manter coerência de termos.

---

## 3.1. Estratégia de Agrupamento e Resumo

- Combinar tópicos correlatos para reduzir páginas e repetição.
- Usar tabelas, bullets e diagramas para comunicar conteúdo denso.
- Limitar cada seção nova a 1–2 páginas; mover detalhes extensos (ex.: prompts de IA, listagens de tarefas) para Apêndices.
- Evitar trechos de código longos; preferir pseudoestrutura e referências a arquivos.

---

## 4. Estrutura Técnica de Cada Inclusão

### 4.1. Arquitetura e Processamento

Conteúdo (bem sucinto): MTV do backend (correção de MVC), camada de serviços, Celery/Redis, snapshots e cache de indicadores.

```latex
\section{Arquitetura e Processamento}\label{sec:arquitetura-processamento}
\subsection{Padrão MTV e Camada de Serviços}\label{subsec:mtv-servicos}
O backend do GenApp segue o padrão \textit{Model-Template-View} (MTV) do Django, adaptado ao contexto de API REST, onde os templates são substituídos por serializadores e validações. A inclusão de uma camada de serviços especializa regras de negócio e cálculos financeiros, promovendo separação de responsabilidades e facilitando testes unitários.
\subsection{Processamento Assíncrono (Celery/Redis)}\label{subsec:celery-redis}
O uso de Celery com Redis viabiliza execução assíncrona de tarefas periódicas e desacopladas do ciclo de requisições HTTP, reduzindo latência percebida pelo usuário e garantindo atualização de dados em intervalos regulares.
\begin{table}[H]
	\centering
	\caption{Principais tarefas assíncronas}
	\label{tab:tasks-assincronas}
	\begin{tabular}{p{4cm}p{3cm}p{6cm}}
		\hline
			extbf{Tarefa} & \textbf{Periodicidade} & \textbf{Objetivo} \\
		\hline
		Snapshot diário de usuários & Diário & Congelar métricas para evolução temporal \\
		Snapshot diário de missões & Diário & Registrar estado e progresso de gamificação \\
		Snapshot mensal & Mensal & Consolidar indicadores para análises macro \\
		Limpeza/expiração de cache & Diário & Garantir consistência dos indicadores \\
		\hline
	\end{tabular}
\end{table}
\subsection{Snapshots e Cache de Indicadores}\label{subsec:snapshots-cache}
Snapshots diários e mensais preservam o histórico de métricas, permitindo análises longitudinais sem reprocessamento custoso. O cache de indicadores reduz leituras repetitivas e cálculos agregados sobre transações. Estratégias de invalidação são acionadas em eventos de escrita relevantes (novas transações ou alterações estruturais), equilibrando desempenho e precisão.
```

### 4.2. IA e Gamificação

Conteúdo: Geração de missões via Gemini, cenários e tiers, estratégia de contenção de custos. Detalhes do prompt em Apêndice.

```latex
\section{Inteligência Artificial e Gamificação}\label{sec:ia-gamificacao}
\subsection{Geração de Missões com Gemini}\label{subsec:missoes-gemini}
Missões são geradas por meio de modelo generativo (Gemini), com prompts estruturados que combinam perfil financeiro, indicadores consolidados e restrições de escopo. A lógica garante variedade e relevância sem produzir objetivos inviáveis.
\subsection{Cenários e Tiers}\label{subsec:cenarios-tiers}
Os cenários categorizam contextos de uso (ex.: controle de gastos essenciais) e os \textit{tiers} graduam dificuldade e impacto esperado. Essa composição permite progressão gradual e feedback motivador.
\subsection{Custos e Salvaguardas}\label{subsec:custos-salvaguardas}
Mecanismos de salvaguarda limitam frequência e volume de chamadas à API generativa, preservando orçamento e evitando degradação de desempenho. Conteúdo extenso do prompt é movido ao Apêndice (ver \ref{apendice:prompt-missoes}).
```

### 4.3. Indicadores e Vinculação de Transações

Atualizar terminologia para "pagamentos de despesas". Incluir uma nota metodológica sobre `TransactionLink` e um diagrama Receita→Link→Despesa.

```latex
\section{Indicadores e Vinculação de Transações}\label{sec:indicadores-vinculacao}
\subsection{Fórmulas}\label{subsec:indicadores-formulas}
Os indicadores sintetizam saúde financeira e eficiência de alocação de recursos.
\begin{equation}\label{eq:tps}
TPS = \frac{Receitas - Despesas - Pagamentos\;de\;Despesas\;Vinculados}{Receitas} \times 100
\end{equation}
\begin{equation}\label{eq:rdr}
RDR = \frac{Pagamentos\;de\;Despesas\;Vinculados}{Receitas} \times 100
\end{equation}
\begin{equation}\label{eq:ili}
ILI = \frac{Despesas\;Essenciais\;Médias\;90d}{Receitas\;Médias\;90d} \times 100
\end{equation}
\subsection{Vinculação de Transações}\label{subsec:vinculacao-transacoes}
Receitas podem ser vinculadas a despesas específicas por meio de registros de ligação, evitando dupla contagem e permitindo atribuição explícita de saídas a entradas.
\begin{figure}[H]
	\centering
	% Placeholder para diagrama
	\caption{Fluxo conceitual de vinculação receita→despesa}
	\label{fig:fluxo-vinculacao}
\end{figure}
\subsection{Nota Metodológica}\label{subsec:nota-metodologica}
A terminologia "pagamentos de despesas" padroniza a visão do usuário e reduz ambiguidade. As ligações afetam TPS e RDR ao desagregar despesas já liquidadas, refletindo liquidez real.
```

### 4.4. Segurança e Deploy

Conteúdo: hash padrão do Django, JWT, armazenamento seguro no app Flutter, comunicação segura, minimização de dados, e nota sobre uso do Railway apenas para validação/testes.

```latex
\section{Segurança e Deploy}\label{sec:seguranca-deploy}
\subsection{Segurança Aplicada}\label{subsec:seguranca-aplicada}
Medidas incluem hash de senhas fornecido pelo framework (PBKDF2), autenticação via JWT, minimização de dados sensíveis e uso de armazenamento seguro de tokens no aplicativo cliente.
\subsection{Ambiente de Validação (Railway)}\label{subsec:railway}
O ambiente Railway é empregado exclusivamente para validação e testes controlados, não constituindo a infraestrutura de produção definitiva.
```

### 4.5. Testes e Trabalhos Futuros

Conteúdo: Tabela breve com testes existentes e planejados; limitações e próximos passos.

```latex
\section{Testes e Trabalhos Futuros}\label{sec:testes-futuros}
\subsection{Testes}\label{subsec:testes}
Incluem testes unitários de serviços e verificação básica de serializers. Expansão futura abarcará testes de integração e widget tests no aplicativo.
\begin{table}[H]
	\centering
	\caption{Resumo de testes}
	\label{tab:testes}
	\begin{tabular}{p{5cm}p{3cm}p{5cm}}
		\hline
			extbf{Componente} & \textbf{Tipo} & \textbf{Objetivo} \\
		\hline
		Serviços financeiros & Unitário & Validar cálculos de indicadores \\
		Serializers principais & Unitário & Garantir estrutura e validação de dados \\
		Tarefas assíncronas & Planejado & Verificar execução e agendamento \\
		Interface (Flutter) & Planejado & Assegurar fluxo de autenticação \\
		\hline
	\end{tabular}
\end{table}
\subsection{Limitações e Próximos Passos}\label{subsec:limitacoes-futuros}
Limitações incluem ausência de confirmação de e-mail e automações externas (ex.: importação bancária). Trabalhos futuros envolvem expansão de testes, enriquecimento de gamificação e análise comportamental avançada.
```

---

## 5. Critérios de Aceitação

| Critério | Descrição | Verificação |
|----------|-----------|-------------|
| Consistência Conceitual | Termos coerentes (MTV, indicadores) | Revisão textual pós-inclusão |
| Correção Técnica | Fórmulas e descrição refletem código | Conferir com `services.py`, `ai_services.py` |
| Coesão Estrutural | Seções novas encaixam sem ruptura | Índice recompilado sem erros |
| Compilação LaTeX | Documento compila sem warnings críticos | Rodar `pdflatex` 2x |
| Referências | Labels únicos, sem conflitos | `grep` por duplicação de `\label{}` |
| Neutralidade Acadêmica | Sem tom promocional | Leitura crítica final |
| Concisão | Cada seção nova limitada a 1–2 páginas | Contagem de páginas por seção |
| Detalhes em Apêndice | Conteúdo extenso movido para Apêndice | Verificar presença e referências |

---

## 6. Checklist de Execução

1. Inserir correções (MVC → MTV, hash, remover allauth)
2. Atualizar fórmulas TPS/RDR/ILI com terminologia "pagamentos de despesas" + nota explicativa
3. Incluir seções agrupadas (Arquitetura e Processamento; IA e Gamificação; Indicadores e Vinculação; Segurança e Deploy; Testes e Futuros)
4. Garantir concisão (1–2 páginas/ seção) e mover detalhes aos Apêndices
5. Recompilar e validar índice
6. Passar checklist de aceitação

---

## 7. Plano de Versionamento

- Criar branch: `doc/atualizacao-tecnica`
- Commits atômicos por seção
- Mensagens: `docs(tex): add seção processamento assíncrono`
- Revisão final antes do merge em `main`

---

## 8. Riscos e Mitigações

| Risco | Impacto | Mitigação |
|-------|---------|-----------|
| Excesso de conteúdo técnico prolongando leitura | Cansaço da banca | Síntese com tabelas e diagramas |
| Erro de compilação após inclusão de ambientes | Atraso | Inserir incrementalmente e compilar cada bloco |
| Inconsistência terminológica | Perda de credibilidade | Glossário final e revisão cruzada |
| Duplicação de labels | Referências quebradas | Padronizar prefixos: `fig:`, `tab:`, `eq:` |

---

## 9. Estimativa de Esforço

| Tarefa | Tempo (estimado) |
|--------|------------------|
| Correções conceituais | 30 min |
| Fórmulas e nota metodológica | 40 min |
| Seção Celery/Redis | 45 min |
| Seção IA Missões | 60 min |
| Snapshots + Cache | 40 min |
| Vinculação de Transações | 35 min |
| Segurança consolidada | 30 min |
| Testes + Deploy | 30 min |
| Limitações e Futuros | 25 min |
| Revisão + Compilação final | 45 min |
| Total | ~6h 20min |

---

## 10. Próximo Passo

Aguardar confirmação do plano para iniciar execução das inclusões seguindo a ordem da checklist.

---
Documento preparado em 09/11/2025.
