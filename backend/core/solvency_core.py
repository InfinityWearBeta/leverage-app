from datetime import date, datetime
from dateutil.relativedelta import relativedelta
from typing import List, Optional, Dict, Any
from pydantic import BaseModel
import math

# Assicurati di avere questo file
from core.health import HealthCalculator 

# --- MODELLI DATI (Generalisti) ---

class ProfilePreferences(BaseModel):
    enable_windfall: bool = True
    weekend_multiplier: float = 1.0 # Default 1.0 = Giorni uguali
    sugar_tax_rate: float = 1.0
    vice_strategy: str = "SOFT"
    min_viable_sds: float = 5.0 # Minimo sindacale per non morire di fame (es. 5€)
    difficulty_mode: str = "BALANCED" 

class UserProfile(BaseModel):
    id: str
    # Dati Biometrici
    weight_kg: float = 0.0
    height_cm: float = 0.0
    age: int = 30
    gender: str = 'M'
    activity_level: str = 'Sedentary'
    tdee_kcal: int = 2000 # Fallback se il calcolo fallisce
    
    # Dati Finanziari
    current_liquid_balance: float # Saldo C/C
    monthly_income: float = 0.0   # Stipendio Netto
    emergency_target: float = 0.0 # Se 0, lo calcoliamo noi
    savings_goal: float = 0.0
    payday_day: int = 27          # Giorno stipendio (Default 27)
    
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

# --- MOTORE LOGICO UNIVERSALE ---

class SolvencyManager:
    def __init__(self, profile: UserProfile, expenses: List[Expense], logs: List[DailyLog]):
        self.profile = profile
        self.expenses = expenses
        self.logs = logs
        self.today = date.today()
        self.health_calc = HealthCalculator()

    def _get_payday_cycle(self) -> tuple[date, date]:
        """Trova il mese fiscale dell'utente in base al SUO giorno di paga."""
        p_day = self.profile.payday_day
        # Protezione contro giorni non validi (es. 31 in mesi da 30)
        if p_day > 28: p_day = 28 
        
        try:
            if self.today.day < p_day:
                next_pay = self.today.replace(day=p_day)
            else:
                next_pay = self.today + relativedelta(months=1)
                next_pay = next_pay.replace(day=p_day)
        except ValueError:
            next_pay = self.today + relativedelta(months=1, day=1) - relativedelta(days=1)

        start_cycle = next_pay - relativedelta(months=1)
        return start_cycle, next_pay

    def _calculate_weighted_days(self, target_date: date) -> float:
        remaining_days = (target_date - self.today).days
        if remaining_days <= 0: return 1.0
        multiplier = self.profile.preferences.weekend_multiplier
        
        weighted_count = 0.0
        current = self.today
        while current < target_date:
            # Se è Sabato(5) o Domenica(6) applica il moltiplicatore
            if current.weekday() >= 5: weighted_count += multiplier
            else: weighted_count += 1.0
            current += relativedelta(days=1)
        return weighted_count

    def calculate_bio_financial_state(self) -> Dict[str, Any]:
        start_cycle, next_payday = self._get_payday_cycle()
        weighted_days = self._calculate_weighted_days(next_payday)
        
        # 1. CALCOLO BURN RATE (Spese Fisse personali)
        monthly_fixed_burn = 0.0
        for exp in self.expenses:
            # Conta solo le spese previste nel mese corrente dell'utente
            if exp.payment_months and next_payday.month not in exp.payment_months:
                continue
            val = exp.max_amount if exp.is_variable else exp.amount
            monthly_fixed_burn += val

        # 2. STRATEGY ENGINE (Adattivo)
        current_cash = self.profile.current_liquid_balance
        
        # Se l'utente non ha settato un target, usiamo la regola aurea: 3 mesi di spese
        target_cash = self.profile.emergency_target
        if target_cash <= 0:
            # Stima spese totali (Fisse + Variabili stimate al 50% reddito)
            estimated_needs = monthly_fixed_burn + (self.profile.monthly_income * 0.3)
            target_cash = estimated_needs * 3
        
        emergency_gap = target_cash - current_cash
        
        income = self.profile.monthly_income
        disposable_income = income - monthly_fixed_burn
        
        # Generiamo proiezioni dinamiche per qualsiasi reddito
        strategies = {
            "HARDCORE": self._simulate_strategy(disposable_income, emergency_gap, "HARDCORE"),
            "BALANCED": self._simulate_strategy(disposable_income, emergency_gap, "BALANCED"),
            "SUSTAINABLE": self._simulate_strategy(disposable_income, emergency_gap, "SUSTAINABLE"),
        }

        user_mode = self.profile.preferences.difficulty_mode.upper()
        if user_mode not in strategies: user_mode = "BALANCED"
        
        active_strategy = strategies[user_mode]
        base_budget = active_strategy["allocated_sds_total"]
        monthly_saving_rate = active_strategy["monthly_saving_rate"]
        
        status = "STABLE"
        status_message = ""

        # --- DETERMINAZIONE FASE ---
        if emergency_gap > 0:
            status = "RECOVERY_MODE"
            status_message = f"Goal: -€{emergency_gap:.0f}"
        
        elif current_cash >= target_cash:
            status = "GROWTH_MODE"
            # Wealth Tax Dinamica: 20% del budget va in investimenti
            wealth_tax = base_budget * 0.20 
            base_budget -= wealth_tax
            monthly_saving_rate += wealth_tax 
            status_message = f"Invest: €{monthly_saving_rate:.0f}/mo"

        # 3. SPESE VARIABILI EFFETTUATE
        spent_in_cycle = 0.0
        start_iso = start_cycle.isoformat()[:10]
        
        for log in self.logs:
            log_date_str = log.date[:10]
            if log_date_str >= start_iso:
                if log.log_type == 'expense' or log.log_type == 'vice_consumed':
                    if log.related_fixed_expense_id: continue 
                    spent_in_cycle += log.amount

        # 4. SDS FINALE
        remaining_budget = base_budget - spent_in_cycle
        if weighted_days < 1: weighted_days = 1
        sds = remaining_budget / weighted_days
        if sds < 0: sds = 0.0

        # --- CALCOLO BIOLOGICO (Generalista) ---
        consumed_today = 0
        today_date = self.today 
        
        # Calcolo TDEE in tempo reale se mancano i dati nel profilo
        base_tdee = self.profile.tdee_kcal
        if base_tdee == 0 and self.profile.weight_kg > 0:
             # Formula Mifflin-St Jeor al volo
             res = self.health_calc.calculate_tdee(
                 self.profile.weight_kg, self.profile.height_cm, 
                 self.profile.age, self.profile.gender, self.profile.activity_level
             )
             base_tdee = res['tdee']

        # Logica Deficit Dinamica (BMI Based)
        target_calories = base_tdee
        bmi = 0
        if self.profile.height_cm > 0:
            h_m = self.profile.height_cm / 100
            bmi = self.profile.weight_kg / (h_m * h_m)
        
        # Se BMI > 25 (Sovrappeso) applichiamo deficit del 15% (più sicuro di 500kcal fisse)
        if bmi > 25:
             cut = int(base_tdee * 0.15)
             target_calories -= cut
             # status_message += f" | Cut -{cut}kcal"

        for log in self.logs:
            try:
                log_date_obj = datetime.strptime(log.date[:10], "%Y-%m-%d").date()
                if log_date_obj == today_date:
                    if log.calories > 0: consumed_today += log.calories
                    elif (log.log_type == 'vice_consumed' or log.category == 'Vizio') and log.sub_type:
                        impact = self.health_calc.calculate_health_impact(log.sub_type, 1)
                        consumed_today += impact.get("daily_kcal_saved", 0)
            except: continue

        sdc = target_calories - consumed_today

        return {
            "financial": {
                "sds_today": round(sds, 2),
                "current_liquid_balance": round(current_cash, 2),
                "status": status,
                "active_mode": user_mode,
                "projected_windfall": round(monthly_saving_rate, 2),
                "days_until_payday": int(weighted_days),
                "pending_bills_total": round(monthly_fixed_burn, 2),
                "strategy_projections": strategies 
            },
            "biological": {
                "sdc_remaining": int(sdc),
                "consumed_today": int(consumed_today),
                "tdee_base": int(target_calories)
            },
            "psychology": {
                "vice_status": "LOCKED" if status == "RECOVERY_MODE" and user_mode == "HARDCORE" else "UNLOCKED",
                "message": f"{status_message}"
            }
        }

    def _simulate_strategy(self, disposable_income: float, gap: float, mode: str) -> dict:
        min_sds = self.profile.preferences.min_viable_sds
        min_monthly_budget = min_sds * 30 
        
        allocated_sds_total = 0.0
        monthly_saving_rate = 0.0
        
        if disposable_income <= 0:
            return {"allocated_sds_total": 0, "monthly_saving_rate": 0, "months_to_goal": 999}

        if mode == "HARDCORE":
            allocated_sds_total = min_monthly_budget
            if allocated_sds_total > disposable_income: allocated_sds_total = disposable_income
            monthly_saving_rate = disposable_income - allocated_sds_total

        elif mode == "BALANCED":
            # 50% Risparmio, 50% Vita
            target_saving = disposable_income * 0.5
            remaining_for_life = disposable_income - target_saving
            if remaining_for_life < min_monthly_budget: remaining_for_life = min_monthly_budget
            allocated_sds_total = remaining_for_life
            monthly_saving_rate = disposable_income - allocated_sds_total

        elif mode == "SUSTAINABLE":
            # 20% Risparmio, 80% Vita
            target_saving = disposable_income * 0.2
            remaining_for_life = disposable_income - target_saving
            allocated_sds_total = remaining_for_life
            monthly_saving_rate = disposable_income - allocated_sds_total

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