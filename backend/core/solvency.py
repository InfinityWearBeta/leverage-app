from datetime import date, datetime, timedelta
import calendar
from typing import List, Optional
from pydantic import BaseModel
from uuid import UUID

# --- MODELLI DATI (Input) ---

class ExpenseItem(BaseModel):
    id: str  # UUID come stringa
    name: str
    amount: float # Se variabile, questo è ignorato
    is_variable: bool = False
    min_amount: float = 0.0
    max_amount: float = 0.0
    payment_months: List[int] = [] # Es. [1, 6]
    due_day: int = 1 # Giorno del mese in cui scade

class LogItem(BaseModel):
    date: str # ISO string
    log_type: str
    amount: float
    related_fixed_expense_id: Optional[str] = None # UUID della spesa pagata

class SolvencyInput(BaseModel):
    # Profilo
    current_liquid_cash: float
    payday_day: int
    savings_goal_monthly: float
    
    # Dati DB
    fixed_expenses: List[ExpenseItem]
    recent_logs: List[LogItem] # Log del mese corrente per verificare pagamenti
    
    # Biometria
    tdee: int
    calories_consumed_today: int

# --- IL MOTORE ---

class SolvencyEngine:
    
    def _get_next_payday(self, payday_day: int) -> date:
        """Calcola la data del prossimo stipendio."""
        today = date.today()
        
        # Tentiamo di creare la data per questo mese
        try:
            this_month_payday = date(today.year, today.month, payday_day)
        except ValueError:
            last_day = calendar.monthrange(today.year, today.month)[1]
            this_month_payday = date(today.year, today.month, last_day)

        if today < this_month_payday:
            return this_month_payday
        else:
            # Se è passato, andiamo al mese prossimo
            next_month = today.month + 1 if today.month < 12 else 1
            next_year = today.year if today.month < 12 else today.year + 1
            try:
                return date(next_year, next_month, payday_day)
            except ValueError:
                last_day = calendar.monthrange(next_year, next_month)[1]
                return date(next_year, next_month, last_day)

    def calculate_metrics(self, data: SolvencyInput) -> dict:
        today = date.today()
        next_payday = self._get_next_payday(data.payday_day)
        
        days_remaining = (next_payday - today).days
        if days_remaining <= 0: days_remaining = 1

        # --- LOGICA 1: FILTRO SPESE PENDENTI ---
        pending_bills_total = 0.0
        pending_bills_details = []

        for expense in data.fixed_expenses:
            # 1. È dovuta in questo periodo?
            # Controlliamo se il mese corrente è nei payment_months
            if expense.payment_months and today.month not in expense.payment_months:
                continue # Non scade questo mese, salta.

            # Scade tra oggi e lo stipendio?
            # (Semplificazione: Consideriamo tutte le spese del mese corrente non ancora pagate)
            
            # 2. È stata già pagata? (Human-in-the-loop check)
            is_paid = False
            for log in data.recent_logs:
                # Controlliamo se c'è un log di pagamento per questa spesa fatto RECENTEMENTE (ultimi 30gg)
                if log.related_fixed_expense_id == expense.id and log.log_type == 'expense':
                    log_date = datetime.fromisoformat(log.date).date()
                    # Se è stata pagata nello stesso mese e anno della scadenza prevista
                    if log_date.month == today.month and log_date.year == today.year:
                        is_paid = True
                        break
            
            if is_paid:
                continue # Già pagata, non sottrarre dal budget!

            # 3. Calcolo Liability (Pessimistic Forecast)
            liability = expense.amount
            if expense.is_variable:
                liability = expense.max_amount # Prendiamo il caso peggiore
            
            pending_bills_total += liability
            pending_bills_details.append({
                "name": expense.name,
                "amount_reserved": liability,
                "is_estimate": expense.is_variable
            })

        # --- LOGICA 2: CALCOLO SDS FINANZIARIO ---
        
        # Liquidità - Bollette Pendenti - Risparmio Intoccabile
        available_cash = data.current_liquid_cash - pending_bills_total - data.savings_goal_monthly
        
        financial_sds = available_cash / days_remaining
        
        # Safety guards
        status_money = "SICURO"
        if financial_sds < 0:
            status_money = "INSOLVENTE"
            financial_sds = 0.0
        elif financial_sds < 15:
            status_money = "CRITICO"

        # --- LOGICA 3: CALCOLO SDC BIOLOGICO ---
        caloric_budget_remaining = data.tdee - data.calories_consumed_today
        
        status_health = "SICURO"
        if caloric_budget_remaining < 0: status_health = "OVERBUDGET"
        elif caloric_budget_remaining < 300: status_health = "LIMITE"

        return {
            "financial": {
                "sds_daily": round(financial_sds, 2),
                "days_until_payday": days_remaining,
                "pending_bills_total": round(pending_bills_total, 2),
                "pending_bills_breakdown": pending_bills_details,
                "status": status_money
            },
            "biological": {
                "sdc_daily_kcal": caloric_budget_remaining,
                "tdee": data.tdee,
                "status": status_health
            }
        }