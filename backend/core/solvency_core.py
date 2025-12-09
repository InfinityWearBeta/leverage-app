from datetime import date, datetime
from dateutil.relativedelta import relativedelta
from typing import List, Optional, Dict, Any
from pydantic import BaseModel

# Importiamo il calcolatore di salute per stimare le calorie dei vizi
from core.health import HealthCalculator 

# --- MODELLI DATI (DTO) ---

class ProfilePreferences(BaseModel):
    enable_windfall: bool = True
    weekend_multiplier: float = 1.0
    sugar_tax_rate: float = 1.0
    vice_strategy: str = "SOFT"
    min_viable_sds: float = 5.0

class UserProfile(BaseModel):
    id: str
    tdee_kcal: int
    current_liquid_balance: float
    payday_day: int
    preferences: ProfilePreferences

class Expense(BaseModel):
    id: str
    name: str = "Spesa"
    amount: float
    is_variable: bool = False
    min_amount: float = 0.0
    max_amount: float = 0.0
    payment_months: List[int] = []
    due_day: int = 1

class DailyLog(BaseModel):
    date: str 
    log_type: str 
    amount: float = 0.0
    calories: int = 0
    category: Optional[str] = None 
    sub_type: Optional[str] = None # Fondamentale per identificare il vizio (es. "Birra")
    related_fixed_expense_id: Optional[str] = None 

# --- MOTORE LOGICO ---

class SolvencyManager:
    def __init__(self, profile: UserProfile, expenses: List[Expense], logs: List[DailyLog]):
        self.profile = profile
        self.expenses = expenses
        self.logs = logs
        self.today = date.today()
        self.health_calc = HealthCalculator() # Istanziamo il calcolatore

    def _get_payday_cycle(self) -> tuple[date, date]:
        """Trova inizio e fine del mese fiscale dell'utente."""
        try:
            candidate_next = self.today.replace(day=self.profile.payday_day)
        except ValueError:
            # Gestione mesi corti (es. Febbraio non ha il 30)
            candidate_next = self.today + relativedelta(day=31)

        if candidate_next > self.today:
            next_pay = candidate_next
        else:
            next_pay = candidate_next + relativedelta(months=1)
            try:
                next_pay = next_pay.replace(day=self.profile.payday_day)
            except ValueError:
                next_pay = next_pay + relativedelta(day=31)

        start_cycle = next_pay - relativedelta(months=1)
        return start_cycle, next_pay

    def _is_bill_paid_in_current_cycle(self, expense_id: str, start_date: date) -> bool:
        """Controlla se la bolletta è già stata pagata in questo ciclo."""
        start_iso = start_date.isoformat()
        for log in self.logs:
            if log.related_fixed_expense_id == expense_id:
                # Confronto robusto sulle stringhe (solo YYYY-MM-DD)
                if log.date[:10] >= start_iso[:10]:
                    return True
        return False

    def _calculate_weighted_days(self, target_date: date) -> float:
        remaining_days = (target_date - self.today).days
        if remaining_days <= 0: return 1.0
        multiplier = self.profile.preferences.weekend_multiplier
        if multiplier == 1.0: return float(remaining_days)

        weighted_count = 0.0
        current = self.today
        while current < target_date:
            if current.weekday() >= 5: weighted_count += multiplier
            else: weighted_count += 1.0
            current += relativedelta(days=1)
        return weighted_count

    def calculate_bio_financial_state(self) -> Dict[str, Any]:
        start_cycle, next_payday = self._get_payday_cycle()
        weighted_days = self._calculate_weighted_days(next_payday)
        
        pending_liabilities_max = 0.0
        projected_windfall = 0.0

        # 1. CALCOLO FINANZIARIO (SDS)
        for exp in self.expenses:
            # Se la spesa non è prevista in questo mese, saltala
            if exp.payment_months and next_payday.month not in exp.payment_months:
                continue
            
            # SE È GIÀ PAGATA (check sui Log), NON SOTTRARLA DAL BUDGET FUTURO
            if self._is_bill_paid_in_current_cycle(exp.id, start_cycle):
                continue

            if exp.is_variable:
                pending_liabilities_max += exp.max_amount
                projected_windfall += (exp.max_amount - exp.min_amount)
            else:
                pending_liabilities_max += exp.amount

        liquid = self.profile.current_liquid_balance
        # Il Budget Giornaliero Sicuro (SDS)
        sds = (liquid - pending_liabilities_max) / weighted_days
        
        status = "SAFE"
        if sds < self.profile.preferences.min_viable_sds:
            status = "CRISIS_MANAGEMENT" 
            if sds < 0: sds = 0.0 # Mai mostrare budget negativo, deprime l'utente.

        # 2. CALCOLO BIOLOGICO (SDC) - FIX LOGICA
        consumed_today = 0
        today_iso = self.today.isoformat() # es: 2023-10-27

        for log in self.logs:
            # Confrontiamo solo la parte data YYYY-MM-DD
            if log.date[:10] == today_iso:
                
                # A. Calorie esplicite nel log
                if log.calories > 0:
                    consumed_today += log.calories
                
                # B. Fallback: Calcolo basato sul vizio (se log.calories è 0)
                elif log.log_type == 'vice_consumed' and log.sub_type:
                    # Usiamo health.py per stimare
                    impact = self.health_calc.calculate_health_impact(log.sub_type, 1) # Assumiamo qtà 1 se non spec.
                    consumed_today += impact.get("daily_kcal_saved", 0) # Qui 'saved' è in realtà 'consumed' nel contesto negativo

        sdc = self.profile.tdee_kcal - consumed_today

        return {
            "financial": {
                "sds_today": round(sds, 2),
                "status": status,
                "projected_windfall": round(projected_windfall, 2),
                "days_until_payday": int(weighted_days),
                "pending_bills_total": round(pending_liabilities_max, 2)
            },
            "biological": {
                "sdc_remaining": int(sdc),
                "consumed_today": int(consumed_today),
                "sugar_tax_paid_today": 0,
                "workout_credits": 0,
                "tdee_base": self.profile.tdee_kcal
            },
            "psychology": {
                "vice_status": "UNLOCKED",
                "unlock_cost_kcal": 0,
                "message": "System v8.2 Bio-Active"
            }
        }