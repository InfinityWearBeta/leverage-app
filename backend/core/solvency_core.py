from datetime import date, datetime
from dateutil.relativedelta import relativedelta
from typing import List, Optional, Dict, Any
from pydantic import BaseModel
import math

# Assicurati che health.py sia nella cartella backend/core/
from core.health import HealthCalculator 

# --- MODELLI DATI (DTO) ---

class ProfilePreferences(BaseModel):
    enable_windfall: bool = True
    weekend_multiplier: float = 1.0
    sugar_tax_rate: float = 1.0
    vice_strategy: str = "SOFT"
    min_viable_sds: float = 10.0
    # La modalità scelta dall'utente ("HARDCORE", "BALANCED", "SUSTAINABLE")
    difficulty_mode: str = "BALANCED" 

class UserProfile(BaseModel):
    id: str
    tdee_kcal: int
    current_liquid_balance: float
    monthly_income: float = 0.0 
    emergency_target: float = 1000.0 # IL SALVAGENTE
    savings_goal: float = 0.0
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
    sub_type: Optional[str] = None 
    related_fixed_expense_id: Optional[str] = None 

# --- MOTORE LOGICO ---

class SolvencyManager:
    def __init__(self, profile: UserProfile, expenses: List[Expense], logs: List[DailyLog]):
        self.profile = profile
        self.expenses = expenses
        self.logs = logs
        self.today = date.today()
        self.health_calc = HealthCalculator()

    def _get_payday_cycle(self) -> tuple[date, date]:
        """Calcola inizio e fine del ciclo di stipendio corrente."""
        try:
            if self.today.day < self.profile.payday_day:
                next_pay = self.today.replace(day=self.profile.payday_day)
            else:
                next_pay = self.today + relativedelta(months=1)
                next_pay = next_pay.replace(day=self.profile.payday_day)
        except ValueError:
            next_pay = self.today + relativedelta(months=1, day=1) - relativedelta(days=1)

        start_cycle = next_pay - relativedelta(months=1)
        return start_cycle, next_pay

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
        
        # 1. ANALISI SPESE FISSE (Burn Rate)
        monthly_fixed_burn = 0.0
        for exp in self.expenses:
            if exp.payment_months and next_payday.month not in exp.payment_months:
                continue
            val = exp.max_amount if exp.is_variable else exp.amount
            monthly_fixed_burn += val

        # 2. LOGICA SALVAGENTE (Strategy Engine)
        current_cash = self.profile.current_liquid_balance
        target_cash = self.profile.emergency_target
        
        # Il Gap è positivo se mancano soldi al salvagente
        emergency_gap = target_cash - current_cash
        
        income = self.profile.monthly_income
        disposable_income = income - monthly_fixed_burn
        
        # Calcoliamo le proiezioni per tutte e 3 le modalità
        strategies = {
            "HARDCORE": self._simulate_strategy(disposable_income, emergency_gap, "HARDCORE"),
            "BALANCED": self._simulate_strategy(disposable_income, emergency_gap, "BALANCED"),
            "SUSTAINABLE": self._simulate_strategy(disposable_income, emergency_gap, "SUSTAINABLE"),
        }

        # Selezioniamo la strategia attiva scelta dall'utente (Default: BALANCED)
        user_mode = self.profile.preferences.difficulty_mode.upper()
        if user_mode not in strategies: user_mode = "BALANCED"
        
        active_strategy = strategies[user_mode]
        base_budget = active_strategy["allocated_sds_total"]
        monthly_saving_rate = active_strategy["monthly_saving_rate"]
        
        status = "STABLE"
        status_message = ""

        # --- DETERMINAZIONE STATO ---
        if emergency_gap > 0:
            status = "RECOVERY_MODE" # Manca il salvagente!
            status_message = f"Filling Lifebuoy: -€{emergency_gap:.0f}"
        elif current_cash >= target_cash:
            status = "GROWTH_MODE" # Salvagente pieno!
            status_message = f"Investable: €{monthly_saving_rate:.0f}/mo"
            # In growth mode, sblocchiamo tutto il disposable (meno una quota investimenti manuale)
            base_budget = disposable_income 

        # 3. SOTTRAZIONE SPESE GIÀ FATTE
        spent_in_cycle = 0.0
        start_iso = start_cycle.isoformat()[:10]
        
        for log in self.logs:
            log_date_str = log.date[:10]
            if log_date_str >= start_iso:
                if log.log_type == 'expense' or log.log_type == 'vice_consumed':
                    if log.related_fixed_expense_id: continue 
                    spent_in_cycle += log.amount

        # 4. CALCOLO SDS FINALE
        remaining_budget = base_budget - spent_in_cycle
        if weighted_days < 1: weighted_days = 1
        sds = remaining_budget / weighted_days
        
        if sds < 0: sds = 0.0

        # --- CALCOLO BIOLOGICO ---
        consumed_today = 0
        today_date = self.today 
        for log in self.logs:
            try:
                log_date_obj = datetime.strptime(log.date[:10], "%Y-%m-%d").date()
                if log_date_obj == today_date:
                    if log.calories > 0: consumed_today += log.calories
                    elif (log.log_type == 'vice_consumed' or log.category == 'Vizio') and log.sub_type:
                        impact = self.health_calc.calculate_health_impact(log.sub_type, 1)
                        consumed_today += impact.get("daily_kcal_saved", 0)
            except: continue

        sdc = self.profile.tdee_kcal - consumed_today

        return {
            "financial": {
                "sds_today": round(sds, 2),
                "current_liquid_balance": round(current_cash, 2),
                "status": status, # <--- QUI DOBBIAMO VEDERE "RECOVERY_MODE"
                "active_mode": user_mode,
                "projected_windfall": round(monthly_saving_rate, 2),
                "days_until_payday": int(weighted_days),
                "pending_bills_total": round(monthly_fixed_burn, 2),
                "strategy_projections": strategies 
            },
            "biological": {
                "sdc_remaining": int(sdc),
                "consumed_today": int(consumed_today),
                "tdee_base": self.profile.tdee_kcal
            },
            "psychology": {
                "vice_status": "LOCKED" if status == "RECOVERY_MODE" and user_mode == "HARDCORE" else "UNLOCKED",
                "message": f"{status_message} | Logs Today: {consumed_today}kcal"
            }
        }

    def _simulate_strategy(self, disposable_income: float, gap: float, mode: str) -> dict:
        """Simula quanto budget e quanto risparmio genera una strategia."""
        
        min_sds = self.profile.preferences.min_viable_sds
        # Stima mensile basata su 30 giorni
        min_monthly_budget = min_sds * 30 
        
        allocated_sds_total = 0.0
        monthly_saving_rate = 0.0
        
        if disposable_income <= 0:
            return {"allocated_sds_total": 0, "monthly_saving_rate": 0, "months_to_goal": 999}

        if mode == "HARDCORE":
            # Ti lascio solo il minimo. Il resto tutto al salvagente.
            allocated_sds_total = min_monthly_budget
            if allocated_sds_total > disposable_income: allocated_sds_total = disposable_income
            monthly_saving_rate = disposable_income - allocated_sds_total

        elif mode == "BALANCED":
            # 50% Risparmio, 50% Vita
            target_saving = disposable_income * 0.5
            remaining_for_life = disposable_income - target_saving
            # Se il 50% è troppo poco per vivere, alziamo al minimo vitale
            if remaining_for_life < min_monthly_budget: remaining_for_life = min_monthly_budget
            
            allocated_sds_total = remaining_for_life
            monthly_saving_rate = disposable_income - allocated_sds_total

        elif mode == "SUSTAINABLE":
            # 20% Risparmio, 80% Vita
            target_saving = disposable_income * 0.2
            remaining_for_life = disposable_income - target_saving
            allocated_sds_total = remaining_for_life
            monthly_saving_rate = disposable_income - allocated_sds_total

        # Calcolo mesi all'obiettivo
        months_to_goal = 0
        if gap > 0:
            if monthly_saving_rate > 0:
                months_to_goal = math.ceil(gap / monthly_saving_rate)
            else:
                months_to_goal = 999 
        
        return {
            "allocated_sds_total": round(allocated_sds_total, 2),
            "monthly_saving_rate": round(monthly_saving_rate, 2),
            "months_to_goal": months_to_goal
        }