# 🧪 Guia de Testes - Onboarding de Transações

## Como Testar a Nova Funcionalidade

### Preparação
1. Certifique-se de que o backend está rodando
2. Execute o app Flutter: `flutter run`

---

## ✅ Cenários de Teste

### 1. Primeiro Acesso (Novo Cadastro)

**Passos**:
1. Faça logout se estiver logado
2. Crie uma nova conta (novo email)
3. Após o cadastro ser bem-sucedido

**Resultado Esperado**:
- ✅ Deve aparecer automaticamente a tela de "Configuração Inicial"
- ✅ Indicador de progresso mostrando "1 de 2"
- ✅ Página de boas-vindas com explicações
- ✅ Botão "Pular" no canto superior direito
- ✅ Botão "Começar" na parte inferior

---

### 2. Navegação no Onboarding

**Passos**:
1. Na tela de boas-vindas, clique em "Começar"

**Resultado Esperado**:
- ✅ Avança para página 2 com transações
- ✅ Indicador de progresso mostra "2 de 2"
- ✅ 8 transações aparecem (4 receitas + 4 despesas)
- ✅ Campos de valor vazios prontos para preencher
- ✅ Botões "Voltar" e "Concluir" na parte inferior

**Ações Adicionais**:
- Clique em "Voltar" → Deve voltar para página 1
- Clique novamente em "Começar" → Deve avançar para página 2

---

### 3. Validação de Mínimo de Transações

**Passos**:
1. Na página 2, preencha apenas 3 transações com valores
   - Ex: Salário: 3500
   - Ex: Alimentação: 800
   - Ex: Luz: 120
2. Clique em "Concluir"

**Resultado Esperado**:
- ❌ Deve mostrar mensagem: "Adicione pelo menos 5 transações para começar! 🎯"
- ✅ Não fecha a tela
- ✅ Permite continuar preenchendo

---

### 4. Conclusão com Sucesso

**Passos**:
1. Preencha pelo menos 5 transações:
   - Salário: 3500,00
   - Investimentos: 500
   - Poupança: 300
   - Alimentação: 800
   - Academia: 150
2. Clique em "Concluir"

**Resultado Esperado**:
- ✅ Loading aparece no botão
- ✅ Após alguns segundos, mostra mensagem de sucesso
- ✅ Exemplo: "🎉 Configuração concluída! 5 transações adicionadas."
- ✅ Fecha a tela e vai para Home
- ✅ Na Home, as transações aparecem
- ✅ Dashboard atualizado com os valores

---

### 5. Pular Onboarding

**Passos**:
1. Faça logout
2. Crie nova conta
3. Quando aparecer o onboarding, clique em "Pular"

**Resultado Esperado**:
- ✅ Fecha a tela imediatamente
- ✅ Vai para Home sem transações
- ✅ Não aparece onboarding novamente

---

### 6. Login Existente Sem Onboarding

**Passos**:
1. Faça logout
2. Faça login com a conta que JÁ completou o onboarding

**Resultado Esperado**:
- ✅ Vai direto para Home
- ✅ NÃO mostra tela de onboarding
- ✅ Transações anteriores aparecem normalmente

---

### 7. Refazer Configuração (nas Settings)

**Passos**:
1. Na Home, vá para "Perfil" (último ícone da barra inferior)
2. Toque no ícone de configurações (⚙️) no canto superior direito
3. Role para baixo até "Refazer Configuração Inicial"
4. Toque na opção

**Resultado Esperado**:
- ✅ Abre tela de onboarding novamente
- ✅ Campos vazios para adicionar mais transações
- ✅ Permite adicionar transações adicionais
- ✅ Ao concluir, cria as novas transações

---

### 8. Formatação de Valores

**Passos**:
1. No onboarding, teste diferentes formatos de valores:
   - `3500` → Deve aceitar
   - `3500,00` → Deve aceitar
   - `3500.00` → Deve aceitar
   - `3.500` → Deve aceitar e remover o ponto
   - `R$ 3500` → Campo já tem R$ prefixado
   - `-500` → Não deve aceitar (sem sinal negativo)

**Resultado Esperado**:
- ✅ Todos os formatos válidos são aceitos
- ✅ Backend recebe valor numérico correto
- ✅ Valores negativos não são criados

---

### 9. Logout e Reset

**Passos**:
1. Complete um onboarding
2. Faça logout
3. Faça login novamente (mesma conta)

**Resultado Esperado**:
- ✅ Onboarding aparece novamente (reset ao logout)
- ✅ Campos vazios
- ✅ Pode adicionar mais transações

---

### 10. Tratamento de Erros de Rede

**Passos**:
1. Desconecte a internet ou desligue o backend
2. Tente concluir o onboarding

**Resultado Esperado**:
- ✅ Mostra mensagem de erro de conexão
- ✅ Não fecha a tela
- ✅ Permite tentar novamente
- ✅ Loading para de rodar

---

## 📱 Testes de UI/UX

### Interface Visual
- [ ] Cores seguem o tema do app (preto, verde primário)
- [ ] Indicador de progresso visível e claro
- [ ] Ícones apropriados para cada transação
- [ ] Botões bem posicionados e legíveis
- [ ] Espaçamento consistente

### Animações
- [ ] Transição suave entre páginas
- [ ] Loading animado no botão "Concluir"
- [ ] Feedback visual ao preencher campos

### Responsividade
- [ ] Funciona em diferentes tamanhos de tela
- [ ] Scroll funciona quando necessário
- [ ] Teclado não sobrepõe campos importantes

---

## 🐛 Casos Extremos

### Teste com Muitas Transações
- [ ] Preencha todas as 8 transações → Deve funcionar
- [ ] Valores muito altos (ex: 999999) → Deve aceitar

### Teste com Caracteres Especiais
- [ ] Tente inserir letras → Não deve permitir
- [ ] Tente inserir símbolos → Apenas números, vírgula e ponto

### Teste de Categorias
- [ ] Verifique se categorias corretas são associadas
- [ ] Backend deve ter categorias correspondentes aos grupos

---

## ✅ Checklist Final

Antes de considerar completo, verifique:

- [ ] Novo usuário vê onboarding
- [ ] Usuário existente NÃO vê onboarding (se já completou)
- [ ] Validação de mínimo 5 transações funciona
- [ ] Transações são criadas no backend
- [ ] Dashboard atualiza após onboarding
- [ ] Botão "Pular" funciona
- [ ] Botão "Voltar" funciona na página 2
- [ ] "Refazer Configuração" nas settings funciona
- [ ] Logout reseta o onboarding
- [ ] Tratamento de erros funciona
- [ ] UI é bonita e intuitiva

---

## 📊 Métricas para Avaliar

Se quiser avaliar o sucesso da feature:

1. **Taxa de Conclusão**: Quantos usuários completam vs pulam
2. **Número Médio de Transações**: Quantas transações usuários adicionam
3. **Tempo de Conclusão**: Quanto tempo leva para completar
4. **Taxa de Refazer**: Quantos usam "Refazer Configuração"
5. **Engajamento Posterior**: Usuários que completam onboarding usam mais o app?

---

## 🆘 Problemas Comuns

### Onboarding não aparece
- Verifique se `OnboardingStorage` está funcionando
- Faça logout e login novamente
- Limpe cache do app se necessário

### Transações não são criadas
- Verifique se backend está rodando
- Veja logs do backend para erros
- Verifique se categorias existem no backend

### Erro ao concluir
- Verifique conexão com backend
- Veja console do Flutter para erros
- Confirme que endpoint de criação de transação funciona

---

## 📝 Notas para Desenvolvimento

- Backend deve ter categorias padrão com os grupos corretos
- Certifique-se de que `Category.group` está populado
- Endpoint de criar transação deve aceitar `category_id` opcional

---

**Status de Teste**: ⏳ Aguardando validação

Após testar, marque os itens e reporte qualquer problema encontrado!
