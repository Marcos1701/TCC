from decimal import Decimal
from typing import Dict, Tuple

from django.db import transaction as db_transaction
from django.core.exceptions import ValidationError

from .models import Transaction, TransactionLink


class PaymentValidator:
    
    def __init__(self, user):
        self.user = user
        self.errors = {}
    
    def validate_payment(
        self,
        source_transaction: Transaction,
        target_transaction: Transaction,
        amount: Decimal,
        link_type: str = TransactionLink.LinkType.EXPENSE_PAYMENT
    ) -> Tuple[bool, Dict[str, str]]:
        
        self.errors = {}
        
        self._validate_ownership(source_transaction, target_transaction)
        self._validate_transaction_types(source_transaction, target_transaction, link_type)
        self._validate_amount(amount)
        self._validate_available_balance(source_transaction, target_transaction, amount)
        self._validate_same_transaction(source_transaction, target_transaction)
        
        return len(self.errors) == 0, self.errors
    
    def validate_bulk_payment(
        self,
        payments: list
    ) -> Tuple[bool, Dict[str, str]]:
        
        self.errors = {}
        
        if not payments:
            self.errors['payments'] = 'Nenhum pagamento fornecido'
            return False, self.errors
        
        if len(payments) > 100:
            self.errors['payments'] = 'Máximo de 100 pagamentos permitidos por lote'
            return False, self.errors
        
        for idx, payment in enumerate(payments):
            if not isinstance(payment, dict):
                self.errors[f'payment_{idx}'] = 'Formato inválido'
                continue
            
            required_fields = ['source_id', 'target_id', 'amount']
            missing = [f for f in required_fields if f not in payment]
            if missing:
                self.errors[f'payment_{idx}'] = f'Campos obrigatórios ausentes: {", ".join(missing)}'
        
        return len(self.errors) == 0, self.errors
    
    def _validate_ownership(
        self,
        source: Transaction,
        target: Transaction
    ) -> None:
        
        if source.user != self.user:
            self.errors['source'] = 'Transação de origem não pertence ao usuário'
        
        if target.user != self.user:
            self.errors['target'] = 'Transação de destino não pertence ao usuário'
        
        if source.user != target.user:
            self.errors['ownership'] = 'Transações devem pertencer ao mesmo usuário'
    
    def _validate_transaction_types(
        self,
        source: Transaction,
        target: Transaction,
        link_type: str
    ) -> None:
        
        if link_type == TransactionLink.LinkType.EXPENSE_PAYMENT:
            if source.type != Transaction.TransactionType.INCOME:
                self.errors['source_type'] = (
                    f'Para pagamento de despesa, origem deve ser RECEITA. '
                    f'Recebido: {source.get_type_display()}'
                )
            
            if target.type != Transaction.TransactionType.EXPENSE:
                self.errors['target_type'] = (
                    f'Para pagamento de despesa, destino deve ser DESPESA. '
                    f'Recebido: {target.get_type_display()}'
                )
    
    def _validate_amount(self, amount: Decimal) -> None:
        
        if amount <= 0:
            self.errors['amount'] = f'Valor deve ser positivo. Recebido: R$ {amount}'
        
        max_amount = Decimal('999999999.99')
        if amount > max_amount:
            self.errors['amount'] = (
                f'Valor excede o limite máximo permitido '
                f'(R$ {max_amount:,.2f})'
            )
    
    def _validate_available_balance(
        self,
        source: Transaction,
        target: Transaction,
        amount: Decimal
    ) -> None:
        
        source_available = source.available_amount
        if amount > source_available:
            self.errors['insufficient_balance'] = (
                f'Saldo insuficiente na origem. '
                f'Disponível: R$ {source_available:.2f}, '
                f'Solicitado: R$ {amount:.2f}'
            )
        
        if target.type == Transaction.TransactionType.EXPENSE:
            target_available = target.available_amount
            if amount > target_available:
                self.errors['excess_payment'] = (
                    f'Valor excede saldo pendente da despesa. '
                    f'Pendente: R$ {target_available:.2f}, '
                    f'Solicitado: R$ {amount:.2f}'
                )
    
    def _validate_same_transaction(
        self,
        source: Transaction,
        target: Transaction
    ) -> None:
        
        if source.id == target.id:
            self.errors['same_transaction'] = (
                'Não é possível vincular uma transação consigo mesma'
            )
