class UxStrings {
  UxStrings._();

  static const challenge = 'Desafio';
  static const challenges = 'Desafios';
  static const activeChallenges = 'Desafios Ativos';
  static const completedChallenges = 'Desafios Concluídos';
  static const weeklyChallenge = 'Desafio da Semana';
  static const noActiveChallenges = 'Nenhum desafio ativo';
  static const challengeRequirements = 'Requisitos do Desafio';
  static const errorLoadingChallenges = 'Erro ao carregar desafios';
  static const unlockNewChallenges = 'desbloqueie novos desafios';
  
  static const points = 'Pontos';
  static const point = 'Ponto';
  static const earnPoints = 'Ganhe pontos';
  static const pointsEarned = 'Pontos ganhos';
  static const adjustPoints = 'Ajustar Pontos';
  static const pointsAdjusted = 'Pontos ajustados com sucesso.';
  
  static const level = 'Nível';
  static const nextLevel = 'Próximo nível';
  
  static const transactions = 'Transações';
  static const newTransaction = 'Nova transação';
  static const recentTransactions = 'Últimas transações';
  
  static const income = 'Receita';
  static const expense = 'Despesa';
  static const balance = 'Saldo';
  
  static const transfer = 'Transferência';
  static const transfers = 'Transferências';
  
  static const savings = 'Poupança Mensal';
  static const savingsAmount = 'Valor Poupado';
  static const fixedExpenses = 'Gastos Fixos';
  static const fixedExpensesMonthly = 'Total Gastos Fixos';
  static const emergencyFund = 'Reserva de Emergência';
  static const emergencyFundMonths = 'Meses de Reserva';
  
  static const excellent = 'Excelente';
  static const good = 'Bom';
  static const warning = 'Atenção';
  static const critical = 'Crítico';
  static const healthy = 'Saudável';
  static const protected = 'Protegido';
  static const vulnerable = 'Vulnerável';
  
  
  static const ranking = 'Ranking';
  static const friendsRanking = 'Ranking de Amigos';
  static const friends = 'Amigos';
  static const addFriends = 'Adicionar Amigos';
  static const inviteFriends = 'Convidar Amigos';
  
  static const home = 'Início';
  static const finances = 'Finanças';
  static const profile = 'Perfil';
  static const settings = 'Configurações';
  static const analysis = 'Análise';
  static const myProgress = 'Meu Progresso';
  
  static const add = 'Adicionar';
  static const edit = 'Editar';
  static const delete = 'Excluir';
  static const save = 'Salvar';
  static const cancel = 'Cancelar';
  static const confirm = 'Confirmar';
  static const continue_ = 'Continuar';
  static const skip = 'Pular';
  static const seeAll = 'Ver tudo';
  static const viewMore = 'Ver Mais';
  static const refresh = 'Atualizar';
  
  
  static String savingsProgress(double percentage) => 
      'Você está guardando ${percentage.toStringAsFixed(0)}% da sua renda';
  
  
  static String pointsEarnedMessage(int points) =>
      points == 1 ? '1 ponto ganho!' : '$points pontos ganhos!';
  
  static String pointsLabel(int count) => 
      count == 1 ? '$count ponto' : '$count pontos';
  
  static String challengesLabel(int count) => 
      count == 1 ? '$count desafio' : '$count desafios';
  
  static String levelReached(int level) => 'Você alcançou o nível $level!';
  
  static String pointsToNextLevel(int points) =>
      'Faltam $points pontos para o próximo nível';
  
  
  static const welcome = 'Bem-vindo!';
  static const letsStart = "Vamos começar";
  static const basicInfo = 'Informações básicas';
  static const allSet = 'Tudo pronto!';
  
  
  static const today = 'Hoje';
  static const thisWeek = 'Esta semana';
  static const thisMonth = 'Este mês';
  static const thisYear = 'Este ano';
  static const total = 'Total';
  
  
  static const success = 'Sucesso!';
  static const error = 'Erro';
  static const loading = 'Carregando...';
  static const noData = 'Nenhum dado disponível';
  static const tryAgain = 'Tentar novamente';
  
  
  static const adminPanel = 'Painel Admin';
  static const userManagement = 'Gestão de Usuários';
  static const systemStats = 'Estatísticas do Sistema';
  static const generateMissions = 'Gerar Missões';
  
  static const adminAccessDenied = 'Acesso restrito à área administrativa';
  static const dataUpdated = 'Dados atualizados';
  static const operationSuccess = 'Operação concluída';
  static const operationFailed = 'Falha na operação';
}
